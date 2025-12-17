//
//  Navigation.swift
//  iOSExample
//
//  Created by Om More on 29/09/25.
//

import SwiftUI

class AppNavigationPath: Observable, ObservableObject {
    var path = NavigationPath()
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
            HomeView<XXDK>(width: UIScreen.w(100))

        case .codenameGenerator:
            CodenameGeneratorView()

        case .password:
            PasswordCreationView()

        case let .chat(chatId, chatTitle):
            ChatView<XXDK>(width: UIScreen.w(100), chatId: chatId, chatTitle: chatTitle)

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
