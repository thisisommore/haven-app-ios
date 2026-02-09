//
//  Navigation.swift
//  iOSExample
//
//  Created by Om More on 29/09/25.
//

import SwiftUI

class AppNavigationPath: Observable, ObservableObject {
    @Published var path = NavigationPath()
}

/// Holds selected chat info for split view detail column
class SelectedChat: ObservableObject {
    @Published var chatId: String?
    @Published var chatTitle: String = ""

    func select(id: String, title: String) {
        chatId = id
        chatTitle = title
    }

    func clear() {
        chatId = nil
        chatTitle = ""
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

    @MainActor @ViewBuilder
    func destinationView() -> some View {
        _destinationView()
            .navigationBarBackButtonHidden()
            .toolbarBackground(.ultraThinMaterial)
    }
}
