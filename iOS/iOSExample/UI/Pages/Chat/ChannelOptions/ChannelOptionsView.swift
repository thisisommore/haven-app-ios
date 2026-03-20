//
//  ChannelOptionsView.swift
//  iOSExample
//
//  Created by Om More
//

import SQLiteData
import SwiftUI

struct ChannelOptionsView<T: XXDKP>: View {
  @State private var controller = ChannelOptionsController()

  var chat: ChatModel
  let onLeaveChannel: () -> Void
  var onDeleteChat: (() -> Void)?

  @Dependency(\.defaultDatabase) var database
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject var xxdk: T

  @FocusState private var isNicknameFocused: Bool

  private var isDM: Bool {
    self.chat.dmToken != nil
  }

  private var channelId: String? {
    self.chat.channelId
  }

  var body: some View {
    NavigationView {
      List {
        Section {
          VStack(alignment: .leading, spacing: 8) {
            Text(self.isDM ? "Name" : "Channel Name")
              .font(.caption)
              .foregroundColor(.secondary)
            Text(self.chat.name)
              .font(.body)
          }

          if !self.isDM, let description = chat.channelDescription, !description.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
              Text("Description")
                .font(.caption)
                .foregroundColor(.secondary)
              Text(description)
                .font(.body)
            }
          }

          if !self.isDM {
            VStack(alignment: .leading, spacing: 8) {
              Text("Your Nickname")
                .font(.caption)
                .foregroundColor(.secondary)
              HStack {
                TextField("Enter nickname (max 24 chars)", text: self.$controller.channelNickname)
                  .focused(self.$isNicknameFocused)
                  .onChange(of: self.controller.channelNickname) { _, newValue in
                    self.controller.updateChannelNickname(newValue)
                  }
                if self.isNicknameFocused {
                  Button("Save") {
                    self.controller.saveNickname(channelId: self.channelId, xxdk: self.xxdk)
                    self.isNicknameFocused = false
                  }
                  .font(.caption)
                  .foregroundColor(.haven)
                }
              }
              if self.controller.channelNickname.count > 10 {
                HStack(spacing: 6) {
                  Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                  Text("Nickname will be truncated to 10 chars in display")
                    .font(.caption)
                    .foregroundColor(.orange)
                }
              }
            }
          }

          if !self.isDM {
            Toggle("Direct Messages", isOn: self.$controller.isDMEnabled)
              .tint(.haven)
              .onChange(of: self.controller.isDMEnabled) { oldValue, newValue in
                self.controller.toggleDirectMessages(
                  oldValue: oldValue, newValue: newValue, channelId: self.channelId, xxdk: self.xxdk
                )
              }
          }

          if !self.isDM, let urlString = self.controller.shareURL, let url = URL(string: urlString) {
            ShareLink(item: url) {
              HStack {
                Text(verbatim: urlString)
                  .lineLimit(1)
                  .truncationMode(.middle)
                Spacer()
                Image(systemName: "square.and.arrow.up")
              }
            }
            .tint(.haven)

            if let sharePassword = self.controller.sharePassword, !sharePassword.isEmpty {
              HStack {
                VStack(alignment: .leading, spacing: 4) {
                  HStack(spacing: 6) {
                    Text("Password")
                      .font(.caption)
                      .foregroundColor(.secondary)
                    SecretBadge()
                  }
                  Text(sharePassword)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.middle)
                }
                Spacer()
                Button {
                  UIPasteboard.general.string = sharePassword
                  self.controller.handlePasswordCopied()
                } label: {
                  Image(systemName: "doc.on.doc")
                    .foregroundColor(.haven)
                }
                .buttonStyle(.borderless)
              }
            }
          }
        }
        .onAppear {
          self.controller.onAppear(chat: self.chat, channelId: self.channelId, xxdk: self.xxdk)
        }

        // Admin section - only visible for channel admins (not for DMs)
        if !self.isDM, self.channelId != nil, self.controller.isAdmin {
          Section(header: Text("Admin")) {
            Button {
              self.controller.showExportKeySheet = true
            } label: {
              HStack {
                Image(systemName: "key.fill")
                  .foregroundColor(.haven)
                Text("Export Channel Key")
                Spacer()
                Image(systemName: "square.and.arrow.up")
                  .foregroundColor(.secondary)
              }
            }
            .tint(.primary)
          }
        }

        // Muted Users section - only visible for admins (not for DMs)
        if !self.isDM, self.channelId != nil, self.controller.isAdmin {
          Section(header: Text("Muted Users")) {
            if self.controller.mutedUsers.isEmpty {
              Text("No muted users")
                .foregroundColor(.secondary)
            } else {
              ForEach(self.controller.mutedUsers, id: \.self) { pubKey in
                MutedUserRow(pubKey: pubKey) {
                  self.controller.unmuteUser(
                    pubKey: pubKey, channelId: self.channelId, xxdk: self.xxdk
                  )
                }
              }
            }
          }
        }

        // Import key section - only visible for non-admins and not for DMs
        if !self.isDM, self.channelId != nil, !self.controller.isAdmin {
          Section {
            Button {
              self.controller.showImportKeySheet = true
            } label: {
              HStack {
                Image(systemName: "key.fill")
                  .foregroundColor(.haven)
                Text("Import Channel Key")
                Spacer()
                Image(systemName: "square.and.arrow.down")
                  .foregroundColor(.secondary)
              }
            }
            .tint(.primary)
          }
        }

        Section {
          Button(role: .destructive) {
            if self.isDM {
              self.controller.showDeleteConfirmation = true
            } else {
              self.controller.showLeaveConfirmation = true
            }
          } label: {
            HStack {
              Spacer()
              Text(self.isDM ? "Delete Chat" : "Leave Channel")
              Spacer()
            }
          }
        }
        .alert("Leave Channel", isPresented: self.$controller.showLeaveConfirmation) {
          Button("Cancel", role: .cancel) {}
          Button("Leave", role: .destructive) {
            self.onLeaveChannel()
            self.dismiss()
          }
        } message: {
          Text("Are you sure you want to leave \"\(self.chat.name)\"?")
        }
        .alert("Delete Chat", isPresented: self.$controller.showDeleteConfirmation) {
          Button("Cancel", role: .cancel) {}
          Button("Delete", role: .destructive) {
            self.onDeleteChat?()
            self.dismiss()
          }
        } message: {
          Text(
            "Are you sure you want to delete this chat with \"\(self.chat.name)\"?"
          )
        }
      }
      .navigationTitle(self.isDM ? "DM Options" : "Channel Options")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            self.dismiss()
          }.tint(.haven)
        }.hiddenSharedBackground()
      }
      .sheet(isPresented: self.$controller.showExportKeySheet) {
        ExportChannelKeySheet(
          channelId: self.channelId ?? "",
          channelName: self.chat.name,
          xxdk: self.xxdk,
          onSuccess: { message in
            self.controller.handleExportSuccess(message: message)
          }
        )
      }
      .sheet(isPresented: self.$controller.showImportKeySheet) {
        ImportChannelKeySheet(
          channelId: self.channelId ?? "",
          channelName: self.chat.name,
          xxdk: self.xxdk,
          onSuccess: { message in
            self.controller.handleImportSuccess(
              message: message, chatId: self.chat.id, chat: self.chat, database: self.database
            )
          }
        )
      }
      .overlay {
        if let toastMessage = self.controller.toastMessage {
          VStack {
            Spacer()
            HStack(spacing: 10) {
              Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.white)
              Text(toastMessage)
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
      .onReceive(NotificationCenter.default.publisher(for: .userMuteStatusChanged)) { notification in
        self.controller.handleMuteStatusChanged(
          notification: notification, channelId: self.channelId, xxdk: self.xxdk
        )
      }
    }
  }
}

#Preview {
  ChannelOptionsPreviewWrapper()
    .mock()
}

private struct ChannelOptionsPreviewWrapper: View {
  @FetchOne(ChatModel.where { $0.id.eq(previewChatId) }) private var chat: ChatModel?

  var body: some View {
    if var chat {
      ChannelOptionsView<XXDKMock>(chat: chat) {}
        .task {
          chat.channelDescription =
            "A channel for general team discussions and announcements"
        }
    } else {
      ProgressView()
    }
  }
}
