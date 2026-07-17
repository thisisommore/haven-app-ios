//
//  MacCreateSpaceView.swift
//  haven
//
//  Create Space dialog redesigned for macOS: settings-style grouped form and
//  a standard button bar. Logic mirrors the shared iOS `CreateSpaceSheet`.
//

import SQLiteData
import SwiftUI

struct MacCreateSpaceView<T: XXDKP>: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var xxdk: T

  @Dependency(\.defaultDatabase) private var database

  @State private var name = ""
  @State private var description = ""
  @State private var isSecret = true
  @State private var enableDirectMessages = false
  @State private var isCreating = false
  @State private var errorMessage: String?

  @FocusState private var focusedField: Field?

  private enum Field {
    case name
    case description
  }

  private var privacyExplanation: String {
    self.isSecret
      ? "Secret Chats hide everything: the name, description, members, messages, and more. No one knows anything about the Haven Chat unless they are invited."
      : "Public Chats are accessible by anyone with just the link. No passphrase is needed to join. Assume everyone knows when your codename is in a public chat."
  }

  private func createChannel() {
    self.isCreating = true
    self.errorMessage = nil

    let privacyLevel: PrivacyLevel = self.isSecret ? .secret : .publicChannel

    Task {
      do {
        let channel = try await xxdk.channel.create(
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

  var body: some View {
    VStack(spacing: 0) {
      Text("Create Space")
        .font(.title2)
        .fontWeight(.bold)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)

      VStack(spacing: 12) {
        GroupBox {
          LabeledContent("Name") {
            TextField("Space name", text: self.$name)
              .textFieldStyle(.roundedBorder)
              .focused(self.$focusedField, equals: .name)
          }
          Divider()
          VStack(alignment: .leading, spacing: 6) {
            Text("Description")
              .foregroundStyle(.secondary)
            TextEditor(text: self.$description)
              .font(.system(size: 13))
              .scrollContentBackground(.hidden)
              .scrollIndicators(.never)
              .frame(height: 64)
              .padding(4)
              .background(Color(nsColor: .textBackgroundColor))
              .clipShape(RoundedRectangle(cornerRadius: 6))
              .overlay {
                RoundedRectangle(cornerRadius: 6)
                  .stroke(
                    self.focusedField == .description
                      ? Color.haven : Color(nsColor: .separatorColor),
                    lineWidth: 1
                  )
              }
              .focused(self.$focusedField, equals: .description)
          }
        }

        GroupBox("Privacy") {
          LabeledContent("Secret") {
            Toggle("", isOn: self.$isSecret)
              .toggleStyle(.switch)
              .labelsHidden()
          }
          Text(self.privacyExplanation)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)

          Divider()

          LabeledContent("Enable Direct Messages") {
            Toggle("", isOn: self.$enableDirectMessages)
              .toggleStyle(.switch)
              .labelsHidden()
          }
          Text("Allow others to send you direct messages from this space")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
        }

        if let errorMessage {
          Text(errorMessage)
            .font(.callout)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .padding(.horizontal, 20)

      HStack {
        Button("Cancel") {
          self.dismiss()
        }
        .disabled(self.isCreating)
        .keyboardShortcut(.cancelAction)

        Spacer()

        if self.isCreating {
          ProgressView()
            .controlSize(.small)
        }

        Button("Create") {
          self.createChannel()
        }
        .buttonStyle(.borderedProminent)
        .tint(.haven)
        .disabled(self.name.trimmingCharacters(in: .whitespaces).isEmpty || self.isCreating)
        .keyboardShortcut(.defaultAction)
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 14)
    }
    .frame(width: 440)
    .onAppear {
      self.focusedField = .name
    }
  }
}
