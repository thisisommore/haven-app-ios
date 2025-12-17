import Bindings
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct HomeView<T: XXDKP>: View {
    @State private var showingSheet = false
    @State private var showingCreateSpace = false
    @State private var showExportIdentitySheet = false
    @State private var showQRCodeSheet = false
    @State private var showQRScanner = false
    @State private var toastMessage: String?
    @State private var qrData: QRData?
    @State private var showLogoutAlert = false
    @State private var showNicknamePicker = false
    @State private var currentNickname: String?
    @State private var searchText: String = ""
    @Query private var chats: [ChatModel]

    @EnvironmentObject var xxdk: T
    @State private var didStartLoad = false
    @EnvironmentObject private var swiftDataActor: SwiftDataActor
    @EnvironmentObject private var secretManager: SecretManager
    @EnvironmentObject private var navigation: AppNavigationPath
    @Environment(\.isSplitView) private var isSplitView
    @EnvironmentObject private var selectedChat: SelectedChat

    var width: CGFloat
    @State private var showTooltip = false

    private var filteredChats: [ChatModel] {
        if searchText.isEmpty {
            return chats
        }
        return chats.filter { chat in
            // Search by chat name (use "Notes" for self chat)
            let displayName = chat.name == "<self>" ? "Notes" : chat.name
            if displayName.localizedCaseInsensitiveContains(searchText) {
                return true
            }
            // Search by DM partner nickname
            if let nickname = chat.messages
                .first(where: { $0.isIncoming && $0.sender != nil })?
                .sender?.nickname,
                !nickname.isEmpty,
                nickname.localizedCaseInsensitiveContains(searchText)
            {
                return true
            }
            return false
        }
    }

    var body: some View {
        let chatList = List(selection: $selectedChat.chatId) {
            ForEach(filteredChats) { chat in
                ChatRowView<T>(chat: chat)
                    .tag(chat.id)
            }
        }
        .onChange(of: selectedChat.chatId) { _, newValue in
            if let chatId = newValue,
               let chat = chats.first(where: { $0.id == chatId })
            {
                selectedChat.chatTitle = chat.name
            }
        }

        let listHeader = chatList
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: "Search chats"
            )
            .tint(.gray.opacity(0.3))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 12) {
                        UserMenuButton(
                            codename: xxdk.codename,
                            nickname: currentNickname,
                            onNicknameTap: {
                                showNicknamePicker = true
                            },
                            onExport: {
                                showExportIdentitySheet = true
                            },
                            onShareQR: {
                                guard let dm = xxdk.DM,
                                      let pubKey = dm.getPublicKey(),
                                      !pubKey.isEmpty
                                else {
                                    print("DM not ready: DM=\(xxdk.DM != nil), token=\(xxdk.DM?.getToken() ?? -1), pubKey=\(xxdk.DM?.getPublicKey()?.count ?? 0) bytes")
                                    return
                                }
                                qrData = QRData(token: dm.getToken(), pubKey: pubKey, codeset: xxdk.codeset)
                            },
                            onLogout: {
                                showLogoutAlert = true
                            }
                        )
                        .frame(width: 28, height: 28)

                        if xxdk.statusPercentage != 100 {
                            Button(action: {
                                showTooltip.toggle()
                            }) {
                                ProgressView().tint(.haven)
                            }
                        }
                    }
                }.hiddenSharedBackground()

                ToolbarItem(placement: .topBarTrailing) {
                    PlusMenuButton(
                        onJoinChannel: { showingSheet = true },
                        onCreateSpace: { showingCreateSpace = true },
                        onScanQR: { showQRScanner = true }
                    )
                    .frame(width: 28, height: 28)
                }.hiddenSharedBackground()
            }

        return listHeader
            .sheet(isPresented: $showingSheet) {
                NewChatView<T>()
            }
            .sheet(isPresented: $showingCreateSpace) {
                CreateSpaceView<T>()
            }
            .sheet(item: $qrData) { data in
                QRCodeView(dmToken: data.token, pubKey: data.pubKey, codeset: data.codeset)
            }
            .fullScreenCover(isPresented: $showQRScanner) {
                QRScannerView(
                    onCodeScanned: { code in
                        handleAddUser(code: code)
                    },
                    onShowMyQR: {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            guard let dm = xxdk.DM, let pubKey = dm.getPublicKey() else { return }
                            qrData = QRData(token: dm.getToken(), pubKey: pubKey, codeset: xxdk.codeset)
                        }
                    }
                )
            }
            .sheet(isPresented: $showNicknamePicker) {
                NicknamePickerView<T>(codename: xxdk.codename ?? "")
                    .onDisappear {
                        loadCurrentNickname()
                    }
            }
            .sheet(isPresented: $showExportIdentitySheet) {
                ExportIdentitySheet(
                    xxdk: xxdk,
                    onSuccess: { message in
                        withAnimation(.spring(response: 0.3)) {
                            toastMessage = message
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                toastMessage = nil
                            }
                        }
                    }
                )
            }
            .alert("Logout", isPresented: $showLogoutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Logout", role: .destructive) {
                    Task {
                        await xxdk.logout()

                        // Clear SwiftData
                        try? swiftDataActor.deleteAll(ChatMessageModel.self)
                        try? swiftDataActor.deleteAll(MessageReactionModel.self)
                        try? swiftDataActor.deleteAll(MessageSenderModel.self)
                        try? swiftDataActor.deleteAll(ChatModel.self)
                        try? swiftDataActor.save()

                        secretManager.clearAll()
                        await MainActor.run {
                            navigation.path = NavigationPath()
                            navigation.path.append(Destination.password)
                        }
                    }
                }
            } message: {
                Text("If you haven't backed up your identity, you will lose access to it permanently. Are you sure you want to logout?")
            }
            .overlay {
                if let message = toastMessage {
                    VStack {
                        Spacer()
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.white)
                            Text(message)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(Color.haven)
                        .cornerRadius(25)
                        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
                        .padding(.bottom, 50)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .background(Color.appBackground)
            .onAppear {
                if xxdk.statusPercentage == 0 {
                    Task.detached {
                        await xxdk.setUpCmix()
                        await xxdk.load(privateIdentity: nil)
                        await xxdk.startNetworkFollower()
                    }
                }
                loadCurrentNickname()
            }
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(NavigationBarItem.TitleDisplayMode.large)
    }

    private func handleAddUser(code: String) {
        print("[HomeView] handleAddUser called with code: \(code)")
        guard let url = URL(string: code),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            print("[HomeView] Invalid URL")
            return
        }

        print("[HomeView] URL Scheme: \(components.scheme ?? "nil"), Host: \(components.host ?? "nil")")

        guard components.scheme == "haven",
              components.host == "dm",
              let queryItems = components.queryItems
        else {
            print("[HomeView] Invalid QR code structure")
            return
        }

        guard let tokenStr = queryItems.first(where: { $0.name == "token" })?.value,
              let token64 = Int64(tokenStr),
              let pubKeyStr = queryItems.first(where: { $0.name == "pubKey" })?.value,
              let pubKey = Data(base64Encoded: pubKeyStr)
        else {
            print("[HomeView] Missing or invalid data. Token: \(queryItems.first(where: { $0.name == "token" })?.value ?? "nil"), PubKey: \(queryItems.first(where: { $0.name == "pubKey" })?.value ?? "nil")")
            return
        }

        // Convert Int64 token to Int32 (handling unsigned 32-bit values that overflow signed Int32)
        let token = Int32(bitPattern: UInt32(truncatingIfNeeded: token64))

        // Get codeset from URL
        guard let codesetStr = queryItems.first(where: { $0.name == "codeset" })?.value,
              let codeset = Int(codesetStr)
        else {
            print("[HomeView] Missing codeset in QR code")
            withAnimation(.spring(response: 0.3)) {
                toastMessage = "Invalid QR code: missing codeset"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation { toastMessage = nil }
            }
            return
        }

        // Derive codename and color using BindingsConstructIdentity
        var err: NSError?
        guard let identityData = Bindings.BindingsConstructIdentity(pubKey, codeset, &err),
              err == nil
        else {
            print("[HomeView] BindingsConstructIdentity failed: \(err?.localizedDescription ?? "unknown")")
            withAnimation(.spring(response: 0.3)) {
                toastMessage = "Failed to derive identity"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation { toastMessage = nil }
            }
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
            print("[HomeView] Derived identity - codename: \(name), color: \(color)")
        } catch {
            print("[HomeView] Failed to decode identity: \(error)")
            withAnimation(.spring(response: 0.3)) {
                toastMessage = "Failed to decode identity"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation { toastMessage = nil }
            }
            return
        }

        let newChat = ChatModel(pubKey: pubKey, name: name, dmToken: token, color: color)

        print("[HomeView] Creating new chat for user: \(name), token: \(token) (original: \(token64))")

        Task.detached {
            print("[HomeView] Inserting chat into database...")
            swiftDataActor.insert(newChat)
            try? swiftDataActor.save()
            print("[HomeView] Chat saved successfully")
        }

        withAnimation(.spring(response: 0.3)) {
            toastMessage = "User added successfully"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                toastMessage = nil
            }
        }
    }

    private func loadCurrentNickname() {
        do {
            let nickname = try xxdk.getDMNickname()
            currentNickname = nickname.isEmpty ? nil : nickname
        } catch {
            currentNickname = nil
        }
    }
}






#Preview {
    @Previewable @StateObject var selectedChat = SelectedChat()
    @Previewable @State var container: ModelContainer = {
        let c = try! ModelContainer(
            for: ChatModel.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        for name in ["<self>", "Tom", "Mayur", "Shashank"] {
            let chat = ChatModel(pubKey: name.data, name: name, dmToken: 0, color: greenColorInt)
            c.mainContext.insert(chat)
            c.mainContext.insert(
                ChatMessageModel(
                    message: "<p>Hello world</p>",
                    isIncoming: true,
                    chat: chat,
                    sender: nil,
                    id: name,
                    internalId: InternalIdGenerator.shared.next(),
                    replyTo: nil,
                    timestamp: 1
                )
            )
        }
        try! c.mainContext.save()
        return c
    }()

    NavigationStack {
        HomeView<XXDKMock>(width: UIScreen.w(100))
            .modelContainer(container)
            .environmentObject(XXDKMock())
            .environmentObject(selectedChat)
            .navigationTitle("Chat")
            .navigationBarBackButtonHidden()
    }
}
