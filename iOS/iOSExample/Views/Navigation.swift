//
//  Navigation.swift
//  iOSExample
//
//  Created by Om More on 29/09/25.
//

import SwiftUI

class AppNavigationPath: Observable, ObservableObject {
    public var path = NavigationPath()
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
    @Entry var navigation: AppNavigationPath = AppNavigationPath()
    @Entry var isSplitView: Bool = false
}

enum Destination: Hashable {
    case home
    case landing
    case codenameGenerator
    case password
    case chat(chatId: String, chatTitle: String)   // add whatever "props" you need
    case logViewer
}

// MARK: - Navigation Destination Views
extension Destination {
    @MainActor @ViewBuilder
    func destinationView() -> some View {
        switch self {
        case .landing:
            LandingPage<XXDK>()
                .navigationBarBackButtonHidden()
        case .home:
            HomeView<XXDK>(width: UIScreen.w(100))
                .navigationBarBackButtonHidden()
        case .codenameGenerator:
            CodenameGeneratorView()
                .navigationBarBackButtonHidden()
        case .password:
            PasswordCreationView()
                .navigationBarBackButtonHidden()
        case let .chat(chatId, chatTitle):
            ChatView<XXDK>(width: UIScreen.w(100), chatId: chatId, chatTitle: chatTitle)
                .navigationBarBackButtonHidden()
        case .logViewer:
            LogViewerUI()
                .navigationBarBackButtonHidden()
        }
    }
}
