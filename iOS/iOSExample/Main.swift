//
//  iOSExampleApp.swift
//  iOSExample
//
//  Created by Richard Carback on 3/4/24.
//

import Bindings
import SwiftData
import SwiftUI

@main
struct Main: App {
    @StateObject var logOutput = LogViewer()
    @StateObject var xxdk = XXDK()
    @StateObject private var sM = SecretManager()
    @StateObject private var navigation = AppNavigationPath()
    var modelData  = {
        // Include all SwiftData models used by the app
        let schema = Schema([
            ChatModelModel.self,
            ChatMessageModel.self,
            MessageReactionModel.self,
            SenderModel.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema)
        
        do {
            let mC = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            return (mC: mC, da: SwiftDataActor(modelContainer: mC))
        } catch {
            fatalError("Could not create ModelContainer: \(error.localizedDescription)")
        }
    }()
    
    @State private var deepLinkError: String?
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn
    @StateObject private var selectedChat = SelectedChat()
    
    var body: some Scene {
        WindowGroup {
            RootContentView(
                xxdk: xxdk,
                sM: sM,
                navigation: navigation,
                modelData: modelData,
                logOutput: logOutput,
                columnVisibility: $columnVisibility,
                selectedChat: selectedChat
            )
        }
    }
}

struct RootContentView: View {
    @ObservedObject var xxdk: XXDK
    @ObservedObject var sM: SecretManager
    @ObservedObject var navigation: AppNavigationPath
    var modelData: (mC: ModelContainer, da: SwiftDataActor)
    @ObservedObject var logOutput: LogViewer
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @ObservedObject var selectedChat: SelectedChat
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var deepLinkError: String?

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "haven" else { return }
        guard let host = url.host else { return }
        
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
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
    
    private func handleDMDeepLink(queryItems: [URLQueryItem]) {
        // haven://dm?token={dmToken}&pubKey={base64PubKey}&codeset={codeset}
        guard let tokenStr = queryItems.first(where: { $0.name == "token" })?.value,
              let token64 = Int64(tokenStr),
              let pubKeyBase64 = queryItems.first(where: { $0.name == "pubKey" })?.value,
              let pubKey = Data(base64Encoded: pubKeyBase64) else {
            print("[DeepLink] Missing token or pubKey")
            deepLinkError = "Invalid link: missing token or pubKey"
            return
        }
        
        let token = Int32(bitPattern: UInt32(truncatingIfNeeded: token64))
        
        guard let codesetStr = queryItems.first(where: { $0.name == "codeset" })?.value,
              let codeset = Int(codesetStr) else {
            print("[DeepLink] Missing codeset")
            deepLinkError = "Invalid link: missing codeset"
            return
        }
        
        var err: NSError?
        guard let identityData = Bindings.BindingsConstructIdentity(pubKey, codeset, &err),
              err == nil else {
            print("[DeepLink] BindingsConstructIdentity failed: \(err?.localizedDescription ?? "unknown")")
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
            print("[DeepLink] Derived identity - codename: \(name), color: \(color)")
        } catch {
            print("[DeepLink] Failed to decode identity: \(error)")
            deepLinkError = "Failed to decode identity"
            return
        }
        
        let newChat = ChatModelModel(pubKey: pubKey, name: name, dmToken: token, color: color)
        
        Task {
            modelData.da.insert(newChat)
            try? modelData.da.save()
            print("[DeepLink] Chat saved for user: \(name)")
            
            await MainActor.run {
                selectedChat.select(id: newChat.id, title: name)
            }
        }
    }
    
    var body: some View {
        Group {
            if sM.isSetupComplete {
                // Split view for main app (iPad/Mac optimized)
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    NavigationStack(path: $navigation.path) {
                        HomeView<XXDK>(width: UIScreen.w(100))
                            .navigationDestination(for: Destination.self) { destination in
                                destination.destinationView()
                                    .toolbarBackground(.ultraThinMaterial)
                            }
                    }
                } detail: {
                    if let chatId = selectedChat.chatId {
                        ChatView<XXDK>(width: UIScreen.w(100), chatId: chatId, chatTitle: selectedChat.chatTitle)
                            .id(chatId) // Force view refresh when chat changes
                    } else if horizontalSizeClass == .regular {
                        EmptyChatSelectionView()
                    }
                }
                .navigationSplitViewStyle(.balanced)
            } else {
                // Full screen for onboarding
                NavigationStack(path: $navigation.path) {
                    Color.clear
                        .navigationDestination(for: Destination.self) { destination in
                            destination.destinationView()
                                .toolbarBackground(.ultraThinMaterial)
                        }
                        .onAppear {
                            xxdk.setModelContainer(mActor: modelData.da, sm: sM)
                            Task {
                                await xxdk.logout()
                                try? modelData.da.deleteAll(ChatMessageModel.self)
                                try? modelData.da.deleteAll(MessageReactionModel.self)
                                try? modelData.da.deleteAll(SenderModel.self)
                                try? modelData.da.deleteAll(ChatModelModel.self)
                                try? modelData.da.save()
                                sM.clearAll()
                                navigation.path.append(Destination.password)
                            }
                        }
                }
            }
        }
        .onAppear {
            xxdk.setModelContainer(mActor: modelData.da, sm: sM)
        }
        .logViewerOnShake()
        .modelContainer(modelData.mC)
        .environmentObject(sM)
        .environmentObject(xxdk)
        .environmentObject(logOutput)
        .environmentObject(selectedChat)
        .environment(\.navigation, navigation)
        .environmentObject(modelData.da)
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .alert("Error", isPresented: Binding(
            get: { deepLinkError != nil },
            set: { if !$0 { deepLinkError = nil } }
        )) {
            Button("OK") { deepLinkError = nil }
        } message: {
            Text(deepLinkError ?? "")
        }
    }

}
