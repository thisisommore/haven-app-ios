import SwiftUI

struct CreateSpaceView<T: XXDKP>: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var xxdk: T
    @EnvironmentObject var swiftDataActor: SwiftDataActor
    
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var isSecret: Bool = true
    @State private var enableDirectMessages: Bool = false
    @State private var isCreating: Bool = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Space Details")) {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section(header: Text("Privacy"), footer: Text(isSecret
                    ? "Secret Chats hide everything: The name, description, members, messages, and more. No one knows anything about the Haven Chat unless they are invited."
                    : "Public Chats are accessible by anyone with just the link. No passphrase is needed to join. You can assume everyone knows when your codename is in a public chat."
                )) {
                    Toggle("Secret", isOn: $isSecret)
                }
                
                Section(footer: Text("Allow others to send you direct messages from this space")) {
                    Toggle("Enable Direct Messages", isOn: $enableDirectMessages)
                }
                
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
                
                if isCreating {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(.circular)
                            Text("Creating space...")
                                .foregroundColor(.secondary)
                                .padding(.leading, 8)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Create Space")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }.tint(.haven)
                    .disabled(isCreating)
                }.hiddenSharedBackground()
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createChannel()
                    }
                    .tint(.haven)
                    .disabled(name.isEmpty || isCreating)
                }.hiddenSharedBackground()
            }
        }
    }
    
    private func createChannel() {
        isCreating = true
        errorMessage = nil
        
        let privacyLevel: PrivacyLevel = isSecret ? .secret : .publicChannel
        
        Task {
            do {
                let channel = try await xxdk.createChannel(
                    name: name,
                    description: description,
                    privacyLevel: privacyLevel,
                    enableDms: enableDirectMessages
                )
                
                guard let channelId = channel.channelId else {
                    throw MyError.runtimeError("Channel ID is missing")
                }
                
                let newChat = Chat(channelId: channelId, name: channel.name, isAdmin: true)
                swiftDataActor.insert(newChat)
                try swiftDataActor.save()
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isCreating = false
                }
            }
        }
    }
}

#Preview {
    CreateSpaceView<XXDKMock>()
        .environmentObject(XXDKMock())
}

