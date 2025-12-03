import SwiftData
import SwiftUI

struct HomeView<T: XXDKP>: View {
    @State private var showingSheet = false
    @State private var showingCreateSpace = false
    @Query private var chats: [Chat]

    @EnvironmentObject var xxdk: T
    @State private var didStartLoad = false
    @EnvironmentObject private var swiftDataActor: SwiftDataActor

    var width: CGFloat
    @State private var showTooltip = false
    var body: some View {
        List {
            ForEach(chats) { chat in

                ChatRowView(chat: chat)
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
                if xxdk.statusPercentage != 100 {
                    Button(action: {
                        showTooltip.toggle()
                    }) {
                        ProgressView().tint(.haven)
                    }
                }

            }.hiddenSharedBackground()

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingSheet = true
                    } label: {
                        Label("Join Channel", systemImage: "link")
                    }
                    Button {
                        showingCreateSpace = true
                    } label: {
                        Label("Create Space", systemImage: "plus.square")
                    }
                } label: {
                    Image(systemName: "plus")
                }.tint(.haven)
            }.hiddenSharedBackground()

        }
        .sheet(isPresented: $showingSheet) {
            NewChatView<T>()
        }
        .sheet(isPresented: $showingCreateSpace) {
            CreateSpaceView()
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
