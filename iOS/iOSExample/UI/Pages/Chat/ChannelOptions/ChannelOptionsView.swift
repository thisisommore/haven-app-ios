//
//  ChannelOptionsView.swift
//  iOSExample
//
//  Created by Om More
//

import SQLiteData
import SwiftUI

struct ChannelOptionsView<T: XXDKP>: View {
  var chat: ChatModel?
  let onLeaveChannel: () -> Void
  var onDeleteChat: (() -> Void)?
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject var xxdk: T
  @Dependency(\.defaultDatabase) var database
  @State private var isDMEnabled: Bool = false
  @State private var shareURL: String?
  @State private var sharePassword: String?
  @State private var showExportKeySheet: Bool = false
  @State private var showImportKeySheet: Bool = false
  @State private var showBackgroundPicker: Bool = false
  @State private var toastMessage: String?
  @State private var isAdmin: Bool = false
  @State private var mutedUsers: [Data] = []
  @State private var showLeaveConfirmation: Bool = false
  @State private var showDeleteConfirmation: Bool = false
  @State private var channelNickname: String = ""
  @FocusState private var isNicknameFocused: Bool

  private var isDM: Bool {
    self.chat?.dmToken != nil
  }

  var body: some View {
    NavigationView {
      List {
        Section {
          VStack(alignment: .leading, spacing: 8) {
            Text(self.isDM ? "Name" : "Channel Name")
              .font(.caption)
              .foregroundColor(.secondary)
            Text(self.chat?.name ?? "Unknown")
              .font(.body)
          }

          if !self.isDM, let description = chat?.channelDescription, !description.isEmpty {
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
                TextField("Enter nickname (max 24 chars)", text: self.$channelNickname)
                  .focused(self.$isNicknameFocused)
                  .onChange(of: self.channelNickname) { _, newValue in
                    if newValue.count > 24 {
                      self.channelNickname = String(newValue.prefix(24))
                    }
                  }
                if self.isNicknameFocused {
                  Button("Save") {
                    self.saveNickname()
                    self.isNicknameFocused = false
                  }
                  .font(.caption)
                  .foregroundColor(.haven)
                }
              }
              if self.channelNickname.count > 10 {
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
            Toggle("Direct Messages", isOn: self.$isDMEnabled)
              .tint(.haven)
              .onChange(of: self.isDMEnabled) { oldValue, newValue in
                guard let channelId = chat?.id else { return }
                do {
                  if newValue {
                    try self.xxdk.enableDirectMessages(channelId: channelId)
                  } else {
                    try self.xxdk.disableDirectMessages(channelId: channelId)
                  }
                } catch {
                  AppLogger.channels.error(
                    "Failed to toggle DM: \(error.localizedDescription, privacy: .public)"
                  )
                  self.isDMEnabled = oldValue
                }
              }
          }

          if !self.isDM, let urlString = shareURL, let url = URL(string: urlString) {
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

            if let sharePassword, !sharePassword.isEmpty {
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
                  self.toastMessage = "Password copied"
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
          self.refreshAdminStatus()
          guard let channelId = chat?.id else { return }
          do {
            self.isDMEnabled = try self.xxdk.areDMsEnabled(channelId: channelId)
          } catch {
            AppLogger.channels.error(
              "Failed to fetch DM status: \(error.localizedDescription, privacy: .public)"
            )
            self.isDMEnabled = false
          }
          do {
            let shareData = try xxdk.getShareURL(
              channelId: channelId, host: "https://xxnetwork.com/join"
            )
            self.shareURL = shareData.url
            self.sharePassword = shareData.password
          } catch {
            AppLogger.channels.error(
              "Failed to fetch share URL: \(error.localizedDescription, privacy: .public)"
            )
          }
          do {
            self.mutedUsers = try self.xxdk.getMutedUsers(channelId: channelId)
          } catch {
            AppLogger.channels.error(
              "Failed to fetch muted users: \(error.localizedDescription, privacy: .public)"
            )
          }
          do {
            self.channelNickname = try self.xxdk.getChannelNickname(channelId: channelId)
          } catch {
            AppLogger.channels.error(
              "Failed to fetch channel nickname: \(error.localizedDescription, privacy: .public)"
            )
          }
        }

        // Admin section - only visible for channel admins (not for DMs)
        if !self.isDM, self.chat?.id != nil, self.isAdmin {
          Section(header: Text("Admin")) {
            Button {
              self.showExportKeySheet = true
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
        if !self.isDM, self.chat?.id != nil, self.isAdmin {
          Section(header: Text("Muted Users")) {
            if self.mutedUsers.isEmpty {
              Text("No muted users")
                .foregroundColor(.secondary)
            } else {
              ForEach(self.mutedUsers, id: \.self) { pubKey in
                MutedUserRow(pubKey: pubKey) {
                  guard let channelId = chat?.id else { return }
                  do {
                    try self.xxdk.muteUser(
                      channelId: channelId, pubKey: pubKey, mute: false
                    )
                    self.mutedUsers = try self.xxdk.getMutedUsers(channelId: channelId)
                    withAnimation(.spring(response: 0.3)) {
                      self.toastMessage = "User unmuted"
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                      withAnimation {
                        self.toastMessage = nil
                      }
                    }
                  } catch {
                    AppLogger.channels.error(
                      "Failed to unmute user: \(error.localizedDescription, privacy: .public)"
                    )
                  }
                }
              }
            }
          }
        }

        // Import key section - only visible for non-admins and not for DMs
        if !self.isDM, self.chat?.id != nil, !self.isAdmin {
          Section {
            Button {
              self.showImportKeySheet = true
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

        // Chat Background section
        Section(header: Text("Appearance")) {
          Button {
            self.showBackgroundPicker = true
          } label: {
            HStack {
              Image(systemName: "paintbrush.fill")
                .foregroundColor(.haven)
              Text("Chat Background")
              Spacer()
              Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
          .tint(.primary)
        }

        Section {
          Button(role: .destructive) {
            if self.isDM {
              self.showDeleteConfirmation = true
            } else {
              self.showLeaveConfirmation = true
            }
          } label: {
            HStack {
              Spacer()
              Text(self.isDM ? "Delete Chat" : "Leave Channel")
              Spacer()
            }
          }
        }
        .alert("Leave Channel", isPresented: self.$showLeaveConfirmation) {
          Button("Cancel", role: .cancel) {}
          Button("Leave", role: .destructive) {
            self.onLeaveChannel()
            self.dismiss()
          }
        } message: {
          Text("Are you sure you want to leave \"\(self.chat?.name ?? "this channel")\"?")
        }
        .alert("Delete Chat", isPresented: self.$showDeleteConfirmation) {
          Button("Cancel", role: .cancel) {}
          Button("Delete", role: .destructive) {
            self.onDeleteChat?()
            self.dismiss()
          }
        } message: {
          Text(
            "Are you sure you want to delete this chat with \"\(self.chat?.name ?? "this contact")\"?"
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
      .sheet(isPresented: self.$showExportKeySheet) {
        ExportChannelKeySheet(
          channelId: self.chat?.id ?? "",
          channelName: self.chat?.name ?? "Unknown",
          xxdk: self.xxdk,
          onSuccess: { message in
            withAnimation(.spring(response: 0.3)) {
              self.toastMessage = message
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
              withAnimation {
                self.toastMessage = nil
              }
            }
          }
        )
      }
      .sheet(isPresented: self.$showImportKeySheet) {
        ImportChannelKeySheet(
          channelId: self.chat?.id ?? "",
          channelName: self.chat?.name ?? "Unknown",
          xxdk: self.xxdk,
          onSuccess: { message in
            if let chatId = chat?.id {
              try? self.database.write { db in
                try ChatModel.where { $0.id.eq(chatId) }
                  .update { $0.isAdmin = true }
                  .execute(db)
              }
            }
            self.refreshAdminStatus()
            withAnimation(.spring(response: 0.3)) {
              self.toastMessage = message
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
              withAnimation {
                self.toastMessage = nil
              }
            }
          }
        )
      }
      .sheet(isPresented: self.$showBackgroundPicker) {
        ChatBackgroundPickerView<T>()
      }
      .overlay {
        if let toastMessage {
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
        guard let channelId = chat?.id else { return }
        if let notificationChannelID = notification.userInfo?["channelID"] as? String,
           notificationChannelID == channelId {
          do {
            self.mutedUsers = try self.xxdk.getMutedUsers(channelId: channelId)
          } catch {
            AppLogger.channels.error(
              "Failed to refresh muted users: \(error.localizedDescription, privacy: .public)"
            )
          }
        }
      }
    }
  }

  private func refreshAdminStatus() {
    self.isAdmin = self.chat?.isAdmin ?? false
  }

  private func saveNickname() {
    guard let channelId = chat?.id else { return }
    do {
      try self.xxdk.setChannelNickname(channelId: channelId, nickname: self.channelNickname)
      withAnimation(.spring(response: 0.3)) {
        self.toastMessage = "Nickname saved"
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
        withAnimation {
          self.toastMessage = nil
        }
      }
    } catch {
      AppLogger.channels.error(
        "Failed to save nickname: \(error.localizedDescription, privacy: .public)"
      )
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
