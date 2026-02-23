//
//  Provider.swift
//  iOSExample
//
//  Created by Om More on 16/12/25.
//

import SwiftData
import SwiftUI

struct Provider<Content: View>: View {
    @StateObject private var logOutput = LogViewer()
    @StateObject private var xxdk = XXDK()
    @StateObject private var secretManager = AppStorage()
    @StateObject private var navigation = AppNavigationPath()
    @StateObject private var selectedChat = SelectedChat()

    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    private var modelContainer: ModelContainer = {
        let schema = Schema([
            ChatModel.self,
            ChatMessageModel.self,
            MessageReactionModel.self,
            MessageSenderModel.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema)

        do {
            let modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            return modelContainer
        } catch {
            fatalError(
                "Could not create ModelContainer: \(error.localizedDescription)"
            )
        }
    }()

    private var modelDataActor: SwiftDataActor {
        SwiftDataActor(modelContainer: modelContainer)
    }

    var body: some View {
        content
            .modelContainer(modelContainer)
            .environmentObject(logOutput)
            .environmentObject(secretManager)
            .environmentObject(xxdk)
            .environmentObject(selectedChat)
            .environmentObject(navigation)
            .environmentObject(modelDataActor)
    }
}
