import SQLiteData
import SwiftUI

struct CreateSpaceView<T: XXDKP>: View {
  @Environment(\.dismiss) var dismiss
  @EnvironmentObject var xxdk: T
  @Dependency(\.defaultDatabase) var database

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
          TextField("Name", text: self.$name)
            .textInputAutocapitalization(.words)

          TextField("Description", text: self.$description, axis: .vertical)
            .lineLimit(3 ... 6)
        }

        Section(
          header: Text("Privacy"),
          footer: Text(
            self.isSecret
              ? "Secret Chats hide everything: The name, description, members, messages, and more. No one knows anything about the Haven Chat unless they are invited."
              : "Public Chats are accessible by anyone with just the link. No passphrase is needed to join. You can assume everyone knows when your codename is in a public chat."
          )
        ) {
          Toggle("Secret", isOn: self.$isSecret)
            .tint(.haven)
        }

        Section(footer: Text("Allow others to send you direct messages from this space")) {
          Toggle("Enable Direct Messages", isOn: self.$enableDirectMessages)
            .tint(.haven)
        }

        if let errorMessage {
          Section {
            Text(errorMessage)
              .foregroundColor(.red)
          }
        }

        if self.isCreating {
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
            self.dismiss()
          }.tint(.haven)
            .disabled(self.isCreating)
        }.hiddenSharedBackground()

        ToolbarItem(placement: .confirmationAction) {
          Button("Create") {
            self.createChannel()
          }
          .tint(.haven)
          .disabled(self.name.isEmpty || self.isCreating)
        }.hiddenSharedBackground()
      }
    }
  }

  private func createChannel() {
    self.isCreating = true
    self.errorMessage = nil

    let privacyLevel: PrivacyLevel = self.isSecret ? .secret : .publicChannel

    Task {
      do {
        let channel = try await xxdk.channel.createChannel(
          name: self.name,
          description: self.description,
          privacyLevel: privacyLevel,
          enableDms: self.enableDirectMessages
        )

        guard let channelId = channel.ChannelID
        else {
          throw XXDKError.channelIdMissing
        }

        let newChat = ChatModel(
          channelId: channelId, name: channel.Name, isAdmin: true,
          isSecret: privacyLevel == .secret
        )
        try await self.database.write { db in
          try ChatModel.insert { newChat }.execute(db)
        }

        await MainActor.run {
          self.dismiss()
        }
      } catch {
        await MainActor.run {
          self.errorMessage = error.localizedDescription
          self.isCreating = false
        }
      }
    }
  }
}

#Preview {
  CreateSpaceView<XXDKMock>()
    .mock()
}
