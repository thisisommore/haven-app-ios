//
//  Navigation.swift
//  iOSExample
//
//  Created by Om More on 29/09/25.
//

import SwiftUI

final class AppNavigationPath: Observable, ObservableObject {
  @Published var path = NavigationPath()
}

/// Holds selected chat info for split view detail column
final class SelectedChat: ObservableObject {
  @Published var chatId: String?
  @Published var chatTitle: String = ""

  func select(id: String, title: String) {
    self.chatId = id
    self.chatTitle = title
  }

  func clear() {
    self.chatId = nil
    self.chatTitle = ""
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
  case chat(chatId: String, chatTitle: String) // add whatever "props" you need
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

    case let .chat(chatId, chatTitle):
      ChatView<XXDK>(chatId: chatId, chatTitle: chatTitle)

    case .logViewer:
      LogViewerUI()
    }
  }

  @MainActor
  func destinationView() -> some View {
    self._destinationView()
      .navigationBarBackButtonHidden()
      .toolbarBackground(.ultraThinMaterial)
  }
}
