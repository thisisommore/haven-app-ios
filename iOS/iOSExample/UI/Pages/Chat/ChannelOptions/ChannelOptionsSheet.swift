//
//  ChannelOptionsSheet.swift
//  iOSExample
//
//  Created by Om More
//

import HavenCore
import SQLiteData
import SwiftUI

struct ChannelOptionsSheet<T: XXDKP>: View {
  @State private var controller = ChannelOptionsController()
  @FetchAll private var mutedUsers: [ChannelMutedUserModel]

  var chat: ChatModel
  let onLeaveChannel: () -> Void
  var onDeleteChat: (() -> Void)?

  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject var xxdk: T

  @FocusState private var isNicknameFocused: Bool

  private var isDM: Bool {
    self.chat.dmToken != nil
  }

  private var channelId: String? {
    self.chat.channelId
  }

  private var channelMutedUsers: [ChannelMutedUserModel] {
    self.mutedUsers
  }

  init(chat: ChatModel, onLeaveChannel: @escaping () -> Void, onDeleteChat: (() -> Void)? = nil) {
    self.chat = chat
    self.onLeaveChannel = onLeaveChannel
    self.onDeleteChat = onDeleteChat
    _mutedUsers = FetchAll(
      ChannelMutedUserModel.where { $0.channelId.eq(chat.channelId ?? "") }
    )
  }

  var body: some View {
    NavigationStack {
      List {
        self.channelInfoSection
        self.notificationSettingsSection
        self.channelManagementSections
        self.leaveOrDeleteSection
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
    }
    .sheet(item: self.$controller.activeSheet, content: self.sheetContent)
    .overlay { self.toastOverlay }
  }

  private var channelInfoSection: some View {
    Section {
      VStack(alignment: .leading, spacing: 8) {
        Text(self.isDM ? "Name" : "Channel Name")
          .font(.caption)
          .foregroundColor(.secondary)
        Text(self.chat.name)
          .font(.body)
      }

      if !self.isDM {
        if let description = self.chat.channelDescription, !description.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("Description")
              .font(.caption)
              .foregroundColor(.secondary)
            Text(description)
              .font(.body)
          }
        }

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
                .foregroundColor(.haven)
              Text("Nickname will be truncated to 10 chars in display")
                .font(.caption)
                .foregroundColor(.haven)
            }
          }
        }

        Toggle("Direct Messages", isOn: self.$controller.isDMEnabled)
          .tint(.haven)
          .onChange(of: self.controller.isDMEnabled) { oldValue, newValue in
            self.controller.toggleDirectMessages(
              oldValue: oldValue, newValue: newValue, channelId: self.channelId, xxdk: self.xxdk
            )
          }

        if let urlString = self.controller.shareURL, let url = URL(string: urlString) {
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
    }
    .onAppear {
      self.controller.onAppear(channelId: self.channelId, chat: self.chat, xxdk: self.xxdk)
    }
  }

  @ViewBuilder
  private var notificationSettingsSection: some View {
    if !self.chat.isSelfChat {
      Section(
        header: Text("Notifications"),
        footer: Text("Muted turns notifications off. Other choices use push alerts.")
      ) {
        Menu {
          ChannelNotificationsLevelMenuButtons(
            levels: self.controller.notificationsLevels(for: self.chat),
            selectedLevel: self.controller.notificationsLevel
          ) { level in
            self.controller.setNotificationsLevel(
              level,
              chat: self.chat,
              xxdk: self.xxdk
            )
          }
        } label: {
          NotificationSettingRow(
            title: "Messages",
            subtitle: "Choose which messages can notify you",
            systemImage: self.controller.notificationsLevel == .none
              ? "speaker.slash.fill"
              : "bell.badge.fill",
            value: self.controller.notificationsLevel.displayName
          )
        }
        .tint(.primary)
      }
    }
  }

  @ViewBuilder
  private var channelManagementSections: some View {
    if !self.isDM {
      if self.channelId != nil, self.chat.isAdmin {
        Section(header: Text("Admin")) {
          Button {
            self.controller.activeSheet = .exportKey
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

      if self.channelId != nil, self.chat.isAdmin {
        Section(header: Text("Muted Users")) {
          if self.channelMutedUsers.isEmpty {
            Text("No muted users")
              .foregroundColor(.secondary)
          } else {
            ForEach(self.channelMutedUsers) { mutedUser in
              MutedUserRow(pubKey: mutedUser.pubkey) {
                self.controller.unmuteUser(
                  pubKey: mutedUser.pubkey,
                  channelId: self.channelId,
                  xxdk: self.xxdk
                )
              }
            }
          }
        }
      }

      if self.channelId != nil, !self.chat.isAdmin {
        Section {
          Button {
            self.controller.activeSheet = .importKey
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
    }
  }

  private var leaveOrDeleteSection: some View {
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

  @ViewBuilder
  private func sheetContent(_ sheet: ChannelOptionsActiveSheet) -> some View {
    switch sheet {
    case .exportKey:
      ExportChannelKeySheet(
        channelId: self.channelId ?? "",
        channelName: self.chat.name,
        xxdk: self.xxdk,
        onSuccess: { message in
          self.controller.handleExportSuccess(message: message)
        }
      )
    case .importKey:
      ImportChannelKeySheet(
        channelId: self.channelId ?? "",
        channelName: self.chat.name,
        xxdk: self.xxdk,
        onSuccess: { message in
          self.controller.handleImportSuccess(
            message: message, chatId: self.chat.id, chat: self.chat
          )
        }
      )
    }
  }

  @ViewBuilder
  private var toastOverlay: some View {
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
}

private struct NotificationSettingRow: View {
  let title: String
  let subtitle: String
  let value: String
  let systemImage: String

  init(title: String, subtitle: String, systemImage: String, value: String) {
    self.title = title
    self.subtitle = subtitle
    self.value = value
    self.systemImage = systemImage
  }

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: self.systemImage)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(Color.haven)
        .frame(width: 28, height: 28)

      VStack(alignment: .leading, spacing: 3) {
        Text(self.title)
          .foregroundStyle(Color(uiColor: .label))
        Text(self.subtitle)
          .font(.caption)
          .foregroundStyle(Color(uiColor: .secondaryLabel))
          .multilineTextAlignment(.leading)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      Spacer(minLength: 12)

      HStack(spacing: 6) {
        Text(self.value)
          .font(.subheadline)
          .foregroundStyle(Color(uiColor: .secondaryLabel))
          .lineLimit(1)
        Image(systemName: "chevron.up.chevron.down")
          .font(.system(size: 10, weight: .semibold))
          .foregroundStyle(Color(uiColor: .tertiaryLabel))
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 4)
    .contentShape(Rectangle())
  }
}

#Preview {
  Mock {
    ChannelOptionsPreviewWrapper()
  }
}

private struct ChannelOptionsPreviewWrapper: View {
  @FetchOne(ChatModel.where { $0.id.eq(previewChatId) }) private var chat: ChatModel?

  var body: some View {
    if var chat {
      ChannelOptionsSheet<XXDKMock>(chat: chat) {}
        .task {
          chat.channelDescription =
            "A channel for general team discussions and announcements"
        }
    } else {
      ProgressView()
    }
  }
}
