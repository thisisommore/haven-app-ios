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
    @Query private var chats: [Chat]

    @EnvironmentObject var xxdk: T
    @State private var didStartLoad = false
    @EnvironmentObject private var swiftDataActor: SwiftDataActor

    var width: CGFloat
    @State private var showTooltip = false
    var body: some View {
        List {
            ForEach(chats) { chat in

                ChatRowView<T>(chat: chat)
                    .background(
                        NavigationLink(
                            value: Destination.chat(
                                chatId: chat.id,
                                chatTitle: chat.name
                            )
                        ) {

                        }.opacity(0)
                    )

            }

        }
        .tint(.gray.opacity(0.3))
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                HStack(spacing: 12) {
                    UserMenuButton(
                        codename: xxdk.codename,
                        onExport: {
                            showExportIdentitySheet = true
                        },
                        onShareQR: {
                            showQRCodeSheet = true
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
        .sheet(isPresented: $showingSheet) {
            NewChatView<T>()
        }
        .sheet(isPresented: $showingCreateSpace) {
            CreateSpaceView<T>()
        }
        .sheet(isPresented: $showQRCodeSheet) {
            QRCodeView()
        }
        .fullScreenCover(isPresented: $showQRScanner) {
            QRScannerView { code in
                withAnimation(.spring(response: 0.3)) {
                    toastMessage = "User added successfully"
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        toastMessage = nil
                    }
                }
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
        }
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct NewChatView<T: XXDKP>: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var swiftDataActor: SwiftDataActor
    @State private var showConfirmationSheet: Bool = false
    @EnvironmentObject var xxdk: T
    @State private var inviteLink: String = ""
    @State private var channelData: ChannelJSON?
    @State private var errorMessage: String?
    @State private var isJoining: Bool = false
    @State private var showPasswordSheet: Bool = false
    @State private var isPrivateChannel: Bool = false
    @State private var prettyPrint: String?

    var body: some View {
        NavigationView {
            VStack {
                Form {
                    Section(header: Text("Enter invite link")) {
                        TextEditor(text: $inviteLink)
                            .frame(minHeight: 100, maxHeight: UIScreen.h(60))
                            .font(.body)
                    }

                    if let error = errorMessage {
                        Section {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }
                .toolbar{
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close")
                        { dismiss() }.tint(.haven)
                    }.hiddenSharedBackground()
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(
                            action: {
                                let trimmed = inviteLink.trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                )
                                guard !trimmed.isEmpty else { return }

                                do {
                                    // Check privacy level first
                                    let privacyLevel =
                                        try xxdk.getChannelPrivacyLevel(
                                            url: trimmed
                                        )

                                    if privacyLevel == .secret {
                                        // Private channel - show password input
                                        isPrivateChannel = true
                                        showPasswordSheet = true
                                        errorMessage = nil
                                    } else {
                                        // Public channel - proceed directly
                                        print("getting channel from url")
                                        let channel = try xxdk.getChannelFromURL(
                                            url: trimmed
                                        )
                                        print("channel data \(channel)")
                                        channelData = channel
                                        showConfirmationSheet = true
                                        errorMessage = nil
                                    }
                                } catch {
                                    errorMessage =
                                        "Failed to get channel: \(error.localizedDescription)"
                                }
                            },
                            label: { Text("Join").foregroundStyle(.haven) }
                        )
                    }.hiddenSharedBackground()
                }
            }
            .sheet(isPresented: $showPasswordSheet) {
                PasswordInputView(
                    url: inviteLink,
                    onConfirm: { password in
                        do {
                            let pp = try xxdk.decodePrivateURL(
                                url: inviteLink,
                                password: password
                            )
                            prettyPrint = pp
                            let channel = try xxdk.getPrivateChannelFromURL(
                                url: inviteLink,
                                password: password
                            )
                            channelData = channel
                            showConfirmationSheet = true
                            showPasswordSheet = false
                            errorMessage = nil
                        } catch {
                            errorMessage =
                                "Failed to decrypt channel: \(error.localizedDescription)"
                            showPasswordSheet = false
                        }
                    },
                    onCancel: {
                        showPasswordSheet = false
                    }
                )
            }
            .sheet(isPresented: $showConfirmationSheet) {
                [inviteLink, channelData] in
                ChannelConfirmationView(
                    channelName: channelData?.name ?? "",
                    channelURL: inviteLink,
                    isJoining: $isJoining,
                    onConfirm: { enableDM in
                        Task {
                            await joinChannel(
                                url: inviteLink,
                                channelData: channelData!,
                                enableDM: enableDM
                            )
                        }
                    }
                )
            }
            .navigationTitle("Join Channel")
            .navigationBarTitleDisplayMode(.inline)
        }
       

    }

    private func joinChannel(
        url: String,
        channelData: ChannelJSON,
        enableDM: Bool
    ) async {
        isJoining = true
        errorMessage = nil

        do {
            print("Joining channel: \(channelData.name)")

            let joinedChannel: ChannelJSON
            // Use prettyPrint if available (private channel), otherwise decode from URL (public channel)
            if let pp = prettyPrint {
                joinedChannel = try await xxdk.joinChannel(pp)
            } else {
                joinedChannel = try await xxdk.joinChannelFromURL(url)
            }

            print("Successfully joined channel: \(joinedChannel)")

            // Create and save the chat to the database
            guard let channelId = joinedChannel.channelId else {
                throw MyError.runtimeError("Channel ID is missing")
            }

            // Enable or disable direct messages based on toggle
            if enableDM {
                print("Enabling direct messages for channel: \(channelId)")
                try xxdk.enableDirectMessages(channelId: channelId)
            } else {
                print("Disabling direct messages for channel: \(channelId)")
                try xxdk.disableDirectMessages(channelId: channelId)
            }

            let newChat = Chat(channelId: channelId, name: joinedChannel.name)
            swiftDataActor.insert(newChat)
            try swiftDataActor.save()

            print("Chat saved to database: \(newChat.name)")

            // Dismiss both sheets and reset state
            self.channelData = nil
            self.prettyPrint = nil
            dismiss()
        } catch {
            print("Failed to join channel: \(error)")
            errorMessage =
                "Failed to join channel: \(error.localizedDescription)"
            self.channelData = nil
            self.prettyPrint = nil
        }

        isJoining = false
    }
}

struct PasswordInputView: View {
    let url: String
    let onConfirm: (String) -> Void
    let onCancel: () -> Void

    @State private var password: String = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Private Channel")) {
                    Text(
                        "This channel is password protected. Enter the password to continue."
                    )
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }

                Section(header: Text("Password")) {
                    SecureField("Enter password", text: $password)
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                }
            }
            .navigationTitle("Enter Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") {
                        onConfirm(password)
                        dismiss()
                    }
                    .disabled(password.isEmpty)
                }
            }
        }
    }
}

struct ExportIdentitySheet<T: XXDKP>: View {
    let xxdk: T
    let onSuccess: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var encryptionPassword = ""
    @State private var showFileExporter = false
    @State private var exportedText = ""
    @State private var errorMessage: String?
    
    private var isPasswordValid: Bool {
        !encryptionPassword.isEmpty
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 48))
                    .foregroundColor(.haven)
                    .padding(.top, 32)
                
                Text("Export Codename")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Export your codename to use on another device or back it up securely.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Encryption Password")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.haven)
                            .frame(width: 20)
                        SecureField("Enter password", text: $encryptionPassword)
                    }
                    .padding()
                    .background(Color.haven.opacity(0.08))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(encryptionPassword.isEmpty ? Color.clear : Color.haven, lineWidth: 1.5)
                    )
                }
                .padding(.horizontal, 24)
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 24)
                }
                
                VStack(spacing: 12) {
                    Button {
                        exportToFile()
                    } label: {
                        HStack {
                            Image(systemName: "doc.fill")
                            Text("Export to File")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isPasswordValid ? Color.haven : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(!isPasswordValid)
                    
                    Button {
                        copyToClipboard()
                    } label: {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("Copy to Clipboard")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isPasswordValid ? Color.haven.opacity(0.15) : Color.gray.opacity(0.15))
                        .foregroundColor(isPasswordValid ? .haven : .gray)
                        .cornerRadius(10)
                    }
                    .disabled(!isPasswordValid)
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                Text("Keep this file secure. Anyone with this file and password can access your identity.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
            .navigationTitle("Export Codename")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .tint(.haven)
                }.hiddenSharedBackground()
            }
            .fileExporter(
                isPresented: $showFileExporter,
                document: TextFileDocument(text: exportedText),
                contentType: .plainText,
                defaultFilename: "codename_backup.json"
            ) { result in
                switch result {
                case .success:
                    onSuccess("Exported to File")
                    dismiss()
                case .failure(let error):
                    errorMessage = "Failed to save: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func exportToFile() {
        do {
            let data = try xxdk.exportIdentity(password: encryptionPassword)
            exportedText = String(data: data, encoding: .utf8) ?? ""
            errorMessage = nil
            showFileExporter = true
        } catch {
            errorMessage = "Failed to export: \(error.localizedDescription)"
        }
    }
    
    private func copyToClipboard() {
        do {
            let data = try xxdk.exportIdentity(password: encryptionPassword)
            UIPasteboard.general.string = String(data: data, encoding: .utf8) ?? ""
            errorMessage = nil
            onSuccess("Copied to Clipboard")
            dismiss()
        } catch {
            errorMessage = "Failed to export: \(error.localizedDescription)"
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Chat.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    ["<self>", "Tom", "Mayur", "Shashank"].forEach { name in
        let chat = Chat(
            pubKey: name.data,
            name: name,
            dmToken: 0,
            color: greenColorInt
        )
        container.mainContext.insert(
            chat
        )
        container.mainContext.insert(
            ChatMessage(
                message:
                    "<p>Hello alllllllllHello alllllllllHello alllllllllHello alllllllllHello alllllllllHello alllllllllHello alllllllllHello alllllllllHello alllllllllHello alllllllll</p>",
                isIncoming: true,
                chat: chat,
                sender: nil,
                id: name,
                replyTo: nil,
                timestamp: 1
            )
        )

    }
    try! container.mainContext.save()
    return NavigationStack {
        HomeView<XXDKMock>(width: UIScreen.w(100))
            .modelContainer(container)
            .environmentObject(XXDKMock())
            .navigationTitle("Chat")
            .navigationBarBackButtonHidden()
    }

}
