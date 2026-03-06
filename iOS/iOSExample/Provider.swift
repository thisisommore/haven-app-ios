//
//  Provider.swift
//  iOSExample
//
//  Created by Om More on 16/12/25.
//

import SwiftUI

struct Provider<Content: View>: View {
    @StateObject private var logOutput = LogViewer()
    @StateObject private var xxdk = XXDK()
    @StateObject private var appStorage = AppStorage()
    @StateObject private var navigation = AppNavigationPath()
    @StateObject private var selectedChat = SelectedChat()
    @StateObject private var chatStore: ChatStore = {
        do {
            let appDb = try AppDatabase.makeDefault()
            return ChatStore(database: appDb)
        } catch {
            fatalError("Could not create GRDB database: \(error.localizedDescription)")
        }
    }()

    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .environmentObject(logOutput)
            .environmentObject(appStorage)
            .environmentObject(xxdk)
            .environmentObject(selectedChat)
            .environmentObject(navigation)
            .environmentObject(chatStore)
    }
}
