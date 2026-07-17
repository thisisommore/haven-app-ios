//
//  MacRoot.swift
//  haven
//
//  Routes between the onboarding flow (new user) and the main split-view
//  interface (returning user), mirroring the iOS `Root`.
//

import Dependencies
import SQLiteData
import SwiftUI

struct MacRoot: View {
  @EnvironmentObject private var xxdk: XXDK
  @EnvironmentObject private var selectedChat: SelectedChat
  @EnvironmentObject private var navigation: AppNavigationPath
  @EnvironmentObject private var appStorage: AppStorage

  @Dependency(\.defaultDatabase) private var database

  @State private var didRunOnboardingReset = false

  var body: some View {
    Group {
      if self.appStorage.isSetupComplete {
        self.mainView
      } else {
        self.onboardingView
      }
    }
    .onChange(of: self.appStorage.isSetupComplete) { _, newValue in
      if newValue {
        self.navigation.path = NavigationPath()
        self.selectedChat.clear()
      }
    }
    .handleDeepLinks()
  }
}

extension MacRoot {
  private var mainView: some View {
    NavigationSplitView {
      MacSidebar()
        .navigationSplitViewColumnWidth(min: 240, ideal: 300, max: 420)
    } detail: {
      if let chatId = selectedChat.chatId {
        MacChatView(chatId: chatId)
          .id(chatId)
      } else {
        NoChatSelectedView()
      }
    }
  }

  private var onboardingView: some View {
    NavigationStack(path: self.$navigation.path) {
      Color.clear
        .navigationDestination(for: Destination.self) { destination in
          destination.macDestinationView()
        }
        .onAppear {
          guard !self.didRunOnboardingReset else { return }
          self.didRunOnboardingReset = true

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
}

extension Destination {
  /// macOS mapping for destinations pushed inside the onboarding navigation
  /// stack. `.home` and `.chat` are handled by the split view, never pushed.
  @MainActor @ViewBuilder
  func macDestinationView() -> some View {
    switch self {
    case .landing:
      MacLandingPage<XXDK>()

    case .codenameGenerator:
      MacCodenamePage<XXDK>()

    case .password:
      MacPasswordPage<XXDK>()

    case .logViewer:
      LogViewerUI()

    case .home, .chat:
      EmptyView()
    }
  }
}
