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
    @EnvironmentObject var secretManager: SecretManager
    @EnvironmentObject var selectedChat: SelectedChat
    @EnvironmentObject var modelDataActor: SwiftDataActor
    @EnvironmentObject var navigation: AppNavigationPath
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            // we use split view when setup is completed
            if secretManager.isSetupComplete {
                NavigationSplitView(columnVisibility: .constant(.doubleColumn))
                {
                    NavigationStack(path: $navigation.path) {
                        HomeView<XXDK>(width: UIScreen.w(100))
                            .navigationDestination(for: Destination.self) {
                                destination in
                                destination.destinationView()
                            }
                    }
                } detail: {
                    if let chatId = selectedChat.chatId {
                        ChatView<XXDK>(
                            width: UIScreen.w(100),
                            chatId: chatId,
                            chatTitle: selectedChat.chatTitle
                        )
                        .id(chatId)
                    }
                    // only display empty chat selection view for big screen, for small screen there is not enough space for that
                    else if horizontalSizeClass == .regular {
                        EmptyChatSelectionView()
                    }
                }
                .navigationSplitViewStyle(.balanced)
            }
            // for setup we don't use split view
            else {
                NavigationStack(path: $navigation.path) {
                    EmptyView()
                        .navigationDestination(for: Destination.self) {
                            destination in
                            destination.destinationView()
                        }
                        .onAppear {
                            xxdk.setModelContainer(
                                mActor: modelDataActor,
                                sm: secretManager
                            )

                            Task {
                                await xxdk.logout()
                                try? modelDataActor.deleteAll(
                                    ChatMessageModel.self
                                )
                                try? modelDataActor.deleteAll(
                                    MessageReactionModel.self
                                )
                                try? modelDataActor.deleteAll(
                                    MessageSenderModel.self
                                )
                                try? modelDataActor.deleteAll(ChatModel.self)
                                try? modelDataActor.save()
                                secretManager.clearAll()
                                navigation.path.append(Destination.password)
                            }
                        }
                }
            }
        }
        .onAppear {
            xxdk.setModelContainer(mActor: modelDataActor, sm: secretManager)
        }
        .logViewerOnShake()
        .handleDeepLinks()
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
            print("[DeepLink] Missing token or pubKey")
            deepLinkError = "Invalid link: missing token or pubKey"
            return
        }

        let token = Int32(bitPattern: UInt32(truncatingIfNeeded: token64))

        guard
            let codesetStr = queryItems.first(where: { $0.name == "codeset" })?
                .value,
            let codeset = Int(codesetStr)
        else {
            print("[DeepLink] Missing codeset")
            deepLinkError = "Invalid link: missing codeset"
            return
        }

        var err: NSError?
        guard
            let identityData = Bindings.BindingsConstructIdentity(
                pubKey,
                codeset,
                &err
            ),
            err == nil
        else {
            print(
                "[DeepLink] BindingsConstructIdentity failed: \(err?.localizedDescription ?? "unknown")"
            )
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
            print(
                "[DeepLink] Derived identity - codename: \(name), color: \(color)"
            )
        } catch {
            print("[DeepLink] Failed to decode identity: \(error)")
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
            print("[DeepLink] Chat saved for user: \(name)")

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
