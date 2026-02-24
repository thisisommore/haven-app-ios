//
//  Root.swift
//  iOSExample
//
//  Created by Om More on 16/12/25.
//

import Bindings
import SwiftData
import SwiftUI

struct Root: View {
    @EnvironmentObject var logOutput: LogViewer
    @EnvironmentObject var xxdk: XXDK
    @EnvironmentObject var appStorage: AppStorage
    @EnvironmentObject var selectedChat: SelectedChat
    @EnvironmentObject var modelDataActor: SwiftDataActor
    @EnvironmentObject var navigation: AppNavigationPath
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var didRunOnboardingReset = false

    var body: some View {
        Group {
            if appStorage.isSetupComplete {
                setupCompletedView
            } else {
                setupIncompleteView
            }
        }
        .onAppear {
            xxdk.setStates(mActor: modelDataActor, appStorage: appStorage)
        }
        .onChange(of: appStorage.isSetupComplete) { _, newValue in
            if newValue {
                navigation.path = NavigationPath()
            }
        }
        .logViewerOnShake()
        .handleDeepLinks()
    }

    @ViewBuilder
    private var setupCompletedView: some View {
        NavigationSplitView(columnVisibility: .constant(.doubleColumn)) {
            NavigationStack(path: $navigation.path) {
                HomeView<XXDK>()
                    .navigationDestination(for: Destination.self) {
                        destination in
                        destination.destinationView()
                    }
            }
        } detail: {
            detailContent
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private var setupIncompleteView: some View {
        NavigationStack(path: $navigation.path) {
            EmptyView()
                .navigationDestination(for: Destination.self) {
                    destination in
                    destination.destinationView()
                }
                .onAppear {
                    if didRunOnboardingReset {
                        return
                    }
                    didRunOnboardingReset = true
                    xxdk.setStates(
                        mActor: modelDataActor,
                        appStorage: appStorage
                    )

                    Task {
                        do {
                            try await xxdk.logout()
                        } catch XXDKError.appStateDirNotFound {
                            AppLogger.xxdk.warning("logout: appStateDir does not exist, skipping removal")
                        } catch {
                            fatalError("logout failed: \(error.localizedDescription)")
                        }
                        try! modelDataActor.deleteAll(
                            MessageReactionModel.self
                        )
                        try! modelDataActor.deleteAll(
                            MessageSenderModel.self
                        )
                        try! modelDataActor.deleteAll(ChatModel.self)
                        try! modelDataActor.save()
                        appStorage.clearAll()
                        navigation.path.append(Destination.password)
                    }
                }
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if let chatId = selectedChat.chatId {
            ChatView<XXDK>(
                chatId: chatId,
                chatTitle: selectedChat.chatTitle
            )
            .id(chatId)
        } else if horizontalSizeClass == .regular {
            EmptyChatSelectionView()
        }
    }
}

struct DeepLinkHandler: ViewModifier {
    @EnvironmentObject var selectedChat: SelectedChat
    @EnvironmentObject var modelDataActor: SwiftDataActor

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
                    if let chatId = pathComponents.first {
                        selectedChat.select(id: chatId, title: "")
                    }
                case "dm":
                    handleDMDeepLink(queryItems: queryItems)
                default:
                    break
                }
            }
            .alert(
                "Error",
                isPresented: Binding(
                    get: { deepLinkError != nil },
                    set: { if !$0 { deepLinkError = nil } }
                )
            ) {
                Button("OK") { deepLinkError = nil }
            } message: {
                Text(deepLinkError ?? "")
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
            deepLinkError = "Invalid link: missing token or pubKey"
            return
        }

        let token = Int32(bitPattern: UInt32(truncatingIfNeeded: token64))

        guard
            let codesetStr = queryItems.first(where: { $0.name == "codeset" })?
            .value,
            let codeset = Int(codesetStr)
        else {
            deepLinkError = "Invalid link: missing codeset"
            return
        }

        let identityData: Data?
        do {
            identityData = try BindingsStatic.constructIdentity(pubKey: pubKey, codeset: codeset)
        } catch {
            AppLogger.app.error("DeepLink: BindingsConstructIdentity failed: \(error.localizedDescription, privacy: .public)")
            deepLinkError = "Failed to derive identity"
            return
        }
        guard let identityData else {
            AppLogger.app.error("DeepLink: BindingsConstructIdentity returned nil")
            deepLinkError = "Failed to derive identity"
            return
        }

        let name: String
        let color: Int
        do {
            let identity = try Parser.decodeIdentity(from: identityData)
            name = identity.codename
            var colorStr = identity.color
            if colorStr.hasPrefix("0x") || colorStr.hasPrefix("0X") {
                colorStr.removeFirst(2)
            }
            color = Int(colorStr, radix: 16) ?? 0xE97451
        } catch {
            AppLogger.app.error("DeepLink: Failed to decode identity: \(error.localizedDescription, privacy: .public)")
            deepLinkError = "Failed to decode identity"
            return
        }

        let newChat = ChatModel(
            pubKey: pubKey,
            name: name,
            dmToken: token,
            color: color
        )

        Task {
            modelDataActor.insert(newChat)
            try? modelDataActor.save()

            await MainActor.run {
                selectedChat.select(id: newChat.id, title: name)
            }
        }
    }
}

extension View {
    func handleDeepLinks() -> some View {
        modifier(DeepLinkHandler())
    }
}