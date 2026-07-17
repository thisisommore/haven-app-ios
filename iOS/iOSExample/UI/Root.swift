//
//  Root.swift
//  iOSExample
//
//  Created by Om More on 16/12/25.
//

import Bindings
import Dependencies
import SQLiteData
import SwiftUI

struct Root: View {
  @EnvironmentObject var logOutput: LogViewer
  @EnvironmentObject var xxdk: XXDK
  @EnvironmentObject var selectedChat: SelectedChat
  @EnvironmentObject var navigation: AppNavigationPath
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  @Dependency(\.defaultDatabase) var database
  @Dependency(\.appStorage) var appStorage

  @State private var didRunOnboardingReset = false

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
      ChatView<XXDK>(chatId: chatId)
        .id(chatId)
    } else if self.horizontalSizeClass == .regular {
      NoChatSelectedView()
    }
  }

  var body: some View {
    Group {
      if self.appStorage.isSetupComplete {
        self.setupCompletedView
      } else {
        self.setupIncompleteView
      }
    }
    .onChange(of: self.appStorage.isSetupComplete) { _, newValue in
      if newValue {
        self.navigation.path = NavigationPath()
      }
    }
    .logViewerOnShake()
    .handleDeepLinks()
  }
}
