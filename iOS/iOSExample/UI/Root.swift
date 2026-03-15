//
//  Root.swift
//  iOSExample
//
//  Created by Om More on 16/12/25.
//

import Bindings
import SQLiteData
import SwiftUI

struct Root: View {
  @EnvironmentObject var logOutput: LogViewer
  @EnvironmentObject var xxdk: XXDK
  @EnvironmentObject var appStorage: AppStorage
  @EnvironmentObject var selectedChat: SelectedChat
  @EnvironmentObject var navigation: AppNavigationPath
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Dependency(\.defaultDatabase) var database
  @State private var didRunOnboardingReset = false

  var body: some View {
    Group {
      if self.appStorage.isSetupComplete {
        self.setupCompletedView
      } else {
        self.setupIncompleteView
      }
    }
    .onAppear {
      self.xxdk.setStates(appStorage: self.appStorage)
    }
    .onChange(of: self.appStorage.isSetupComplete) { _, newValue in
      if newValue {
        self.navigation.path = NavigationPath()
      }
    }
    .logViewerOnShake()
    .handleDeepLinks()
  }

  private var setupCompletedView: some View {
    NavigationSplitView(columnVisibility: .constant(.doubleColumn)) {
      NavigationStack(path: self.$navigation.path) {
        HomeView<XXDK>()
          .navigationDestination(for: Destination.self) { destination in
            destination.destinationView()
          }
      }
    } detail: {
      self.detailContent
    }
    .navigationSplitViewStyle(.balanced)
  }

  private var setupIncompleteView: some View {
    NavigationStack(path: self.$navigation.path) {
      EmptyView()
        .navigationDestination(for: Destination.self) { destination in
          destination.destinationView()
        }
        .onAppear {
          if self.didRunOnboardingReset {
            return
          }
          self.didRunOnboardingReset = true
          self.xxdk.setStates(appStorage: self.appStorage)

          Task {
            do {
              try await self.xxdk.logout()
            } catch XXDKError.appStateDirNotFound {
              AppLogger.xxdk.warning(
                "logout: appStateDir does not exist, skipping removal"
              )
            } catch {
              fatalError("logout failed: \(error.localizedDescription)")
            }
            try! await self.database.write { db in
              try MessageReactionModel.delete().execute(db)
              try MessageSenderModel.delete().execute(db)
              try ChatModel.delete().execute(db)
            }
            self.appStorage.clearAll()
            self.navigation.path.append(Destination.password)
          }
        }
    }
  }

  @ViewBuilder
  private var detailContent: some View {
    if let chatId = selectedChat.chatId {
      ChatView<XXDK>(
        chatId: chatId,
        chatTitle: self.selectedChat.chatTitle
      )
      .id(chatId)
    } else if self.horizontalSizeClass == .regular {
      EmptyChatSelectionView()
    }
  }
}

struct DeepLinkHandler: ViewModifier {
  @EnvironmentObject var selectedChat: SelectedChat
  @Dependency(\.defaultDatabase) var database

  @State private var deepLinkError: String?

  func body(content: Content) -> some View {
    content
      .onOpenURL { url in
        guard url.scheme == "haven" else { return }
        guard let host = url.host else { return }

        let components = URLComponents(
          url: url,
          resolvingAgainstBaseURL: false
        )
        let queryItems = components?.queryItems ?? []

        switch host {
        case "chat":
          let pathComponents = url.pathComponents.filter { $0 != "/" }
          if let chatIdRaw = pathComponents.first,
             let chatId = UUID(uuidString: chatIdRaw) {
            self.selectedChat.select(id: chatId, title: "")
          }
        case "dm":
          self.handleDMDeepLink(queryItems: queryItems)
        default:
          break
        }
      }
      .alert(
        "Error",
        isPresented: Binding(
          get: { self.deepLinkError != nil },
          set: { if !$0 { self.deepLinkError = nil } }
        )
      ) {
        Button("OK") { self.deepLinkError = nil }
      } message: {
        Text(self.deepLinkError ?? "")
      }
  }

  private func handleDMDeepLink(queryItems: [URLQueryItem]) {
    guard
      let tokenStr = queryItems.first(where: { $0.name == "token" })?
      .value,
      let token64 = Int64(tokenStr),
      let pubKeyBase64 = queryItems.first(where: { $0.name == "pubKey" })?
      .value,
      let pubKey = Data(base64Encoded: pubKeyBase64)
    else {
      self.deepLinkError = "Invalid link: missing token or pubKey"
      return
    }

    let token = Int32(bitPattern: UInt32(truncatingIfNeeded: token64))

    guard
      let codesetStr = queryItems.first(where: { $0.name == "codeset" })?
      .value,
      let codeset = Int(codesetStr)
    else {
      self.deepLinkError = "Invalid link: missing codeset"
      return
    }

    let identity: IdentityJSON?
    do {
      identity = try BindingsStatic.constructIdentity(pubKey: pubKey, codeset: codeset)
    } catch {
      AppLogger.app.error(
        "DeepLink: BindingsConstructIdentity failed: \(error.localizedDescription, privacy: .public)"
      )
      self.deepLinkError = "Failed to derive identity"
      return
    }
    guard let identity
    else {
      AppLogger.app.error("DeepLink: BindingsConstructIdentity returned nil")
      self.deepLinkError = "Failed to derive identity"
      return
    }

    let name: String
    let color: Int
    name = identity.Codename
    var colorStr = identity.Color
    if colorStr.hasPrefix("0x") || colorStr.hasPrefix("0X") {
      colorStr.removeFirst(2)
    }
    color = Int(colorStr, radix: 16) ?? 0xE97451

    Task {
      let existingChat = try? await self.database.read { db in
        try ChatModel.where { $0.pubKey.eq(pubKey) }.fetchOne(db)
      }

      await MainActor.run {
        if let existingChat {
          self.selectedChat.select(id: existingChat.id, title: existingChat.name)
          return
        }
      }

      let newChat = ChatModel(
        pubKey: pubKey,
        name: name,
        dmToken: token,
        color: color
      )

      try! await self.database.write { db in
        try ChatModel.insert { newChat }.execute(db)
      }

      await MainActor.run {
        self.selectedChat.select(id: newChat.id, title: name)
      }
    }
  }
}

extension View {
  func handleDeepLinks() -> some View {
    modifier(DeepLinkHandler())
  }
}
