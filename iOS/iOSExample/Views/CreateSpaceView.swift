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
                
                Section(header: Text("Privacy")) {
                    Toggle("Secret", isOn: $isSecret)
                }
                
                Section(footer: Text("Allow members to send direct messages to each other")) {
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
                
                let newChat = Chat(channelId: channelId, name: channel.name)
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

