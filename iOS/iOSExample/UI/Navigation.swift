//
//  Navigation.swift
//  iOSExample
//
//  Created by Om More on 29/09/25.
//

import Foundation
import SwiftUI

final class AppNavigationPath: Observable, ObservableObject {
  @Published var path = NavigationPath()
}

/// Holds selected chat info for split view detail column
final class SelectedChat: ObservableObject {
  @Published var chatId: UUID?

  func select(id: UUID) {
    self.chatId = id
  }

  func clear() {
    self.chatId = nil
  }
}

extension EnvironmentValues {
  @Entry var isSplitView: Bool = false
}

enum Destination: Hashable {
  case home
  case landing
  case codenameGenerator
  case password
  case chat(chatId: UUID) // add whatever "props" you need
  case logViewer
}

extension Destination {
  @MainActor @ViewBuilder
  func _destinationView() -> some View {
    switch self {
    case .landing:
      LandingPage<XXDK>()

    case .home:
      HomeView<XXDK>()

    case .codenameGenerator:
      CodenameGeneratorView<XXDK>()

    case .password:
      PasswordCreationView<XXDK>()

    case let .chat(chatId):
      ChatView<XXDK>(chatId: chatId)

    case .logViewer:
      LogViewerUI()
    }
  }

  @MainActor
  func destinationView() -> some View {
    self._destinationView()
      // hidden since most components don't use this, for example new user flow
      // and chat page uses its own back button
      .navigationBarBackButtonHidden()
      .toolbarBackground(.ultraThinMaterial)
  }
}
