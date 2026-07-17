//
//  DeepLink.swift
//  iOSExample
//
//  haven:// deep link handling, shared between iOS and macOS.
//

import Bindings
import Dependencies
import SQLiteData
import SwiftUI

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
            self.selectedChat.select(id: chatId)
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
          self.selectedChat.select(id: existingChat.id)
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
        self.selectedChat.select(id: newChat.id)
      }
    }
  }
}

extension View {
  func handleDeepLinks() -> some View {
    modifier(DeepLinkHandler())
  }
}
