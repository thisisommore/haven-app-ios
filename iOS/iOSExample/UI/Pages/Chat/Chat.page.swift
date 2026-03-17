//
//  Chat.page.swift
//  iOSExample
//
//  Created by Om More on 22/09/25.
//

import SQLiteData
import SwiftUI

struct ChatView<T: XXDKP>: View {
  let chatId: UUID
  let chatTitle: String

  @EnvironmentObject var selectedChat: SelectedChat
  @Dependency(\.defaultDatabase) var database
  @FetchOne private var chat: ChatModel?
  @FetchOne private var firstMessage: ChatMessageModel?

  private var isChannel: Bool {
    guard let chat else { return false }
    return chat.name != "<self>" && chat.dmToken == nil
  }

  @Environment(\.dismiss) private var dismiss
  @State private var replyingTo: ChatMessageModel?
  @State private var showChannelOptions: Bool = false
  @State private var isAdmin: Bool = false
  @State private var isMuted: Bool = false
  @EnvironmentObject var xxdk: T

  private func markMessagesAsRead() {
    guard let chat else { return }
    let joinedAt = chat.joinedAt
    let chatId = chat.id

    guard
      let unreadMessages = try? database.read({ db in
        try ChatMessageModel.where { message in
          message.chatId.eq(chatId) && message.isIncoming && !message.isRead
            && message.timestamp > joinedAt
        }.fetchAll(db)
      }), !unreadMessages.isEmpty
    else { return }

    var updatedChat = chat
    updatedChat.unreadCount = 0

    try? self.database.write { db in
      for var message in unreadMessages {
        message.isRead = true
        try ChatMessageModel.update(message).execute(db)
      }
      try ChatModel.update(updatedChat).execute(db)
    }
  }

  init(chatId: UUID, chatTitle: String) {
    self.chatId = chatId
    self.chatTitle = chatTitle
    _chat = FetchOne(ChatModel.where { $0.id.eq(chatId) })
    _firstMessage = FetchOne(ChatMessageModel.where { $0.chatId.eq(chatId) })
  }

  var body: some View {
    ZStack {
      ChatMessages(chatId: self.chatId) { message in
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
          self.replyingTo = message
        }
      }
      if self.firstMessage == nil {
        EmptyChatView()
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.appBackground)
    .safeAreaInset(edge: .bottom, spacing: 0) {
      if self.isMuted {
        HStack {
          Image(systemName: "speaker.slash.fill")
            .foregroundColor(.secondary)
          Text("You are muted in this channel")
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
      } else {
        MessageForm<T>(
          chat: self.chat,
          replyTo: self.replyingTo,
          onCancelReply: {
            self.replyingTo = nil
          }
        )
        .padding(.vertical, 4)
      }
    }
    .navigationBarTitleDisplayMode(.inline)
    .navigationBarBackButtonHidden(true)
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button {
          if self.selectedChat.chatId == self.chatId {
            self.selectedChat.clear()
          } else {
            self.dismiss()
          }
        } label: {
          HStack(spacing: 2) {
            Image(systemName: "chevron.left")
            Text("back")
          }
          .font(.headline)
          .foregroundStyle(.haven)
        }
      }
      ToolbarItem(placement: .principal) {
        Button {
          self.showChannelOptions = true
        } label: {
          HStack(spacing: 4) {
            Text(self.chatTitle == "<self>" ? "Notes" : self.chatTitle)
              .font(.headline.weight(.semibold))
              .foregroundStyle(.primary)
            if self.isChannel && self.chat?.isSecret == true {
              SecretBadge()
            }
            if self.isChannel && self.isAdmin {
              AdminBadge()
            }
          }
        }
      }
    }
    .sheet(isPresented: self.$showChannelOptions) {
      ChannelOptionsView<T>(chat: self.chat) {
        Task {
          do {
            guard let channelId = self.chat?.channelId else { return }
            try self.xxdk.channel.leaveChannel(channelId: channelId)
            let chatsToDelete =
              try? await database.read { db in
                try ChatModel.where { $0.id.eq(self.chatId) }.fetchAll(db)
              }
            if let chatsToDelete {
              try? await self.database.write { db in
                for chatToDelete in chatsToDelete {
                  try ChatModel.delete(chatToDelete).execute(db)
                }
              }
            }
            await MainActor.run {
              self.dismiss()
            }
          } catch {
            AppLogger.channels.error(
              "Failed to leave channel: \(error.localizedDescription, privacy: .public)"
            )
          }
        }
      }
      .environmentObject(self.xxdk)
    }
    .onAppear {
      self.isAdmin = self.chat?.isAdmin ?? false
      if self.isChannel, let channelId = self.chat?.channelId {
        self.isMuted = self.xxdk.channel.isMuted(channelId: channelId)
      } else {
        self.isMuted = false
      }
      // Mark all incoming messages as read
      self.markMessagesAsRead()
    }
    .onReceive(NotificationCenter.default.publisher(for: .userMuteStatusChanged)) { notification in
      if let channelID = notification.userInfo?["channelID"] as? String,
         channelID == self.chat?.channelId {
        guard self.isChannel, let channelId = self.chat?.channelId else { return }
        self.isMuted = self.xxdk.channel.isMuted(channelId: channelId)
      }
    }
    .id("chat-\(self.chatId.uuidString)")
    .onChange(of: self.showChannelOptions) { _, newValue in
      if !newValue {
        self.isAdmin = self.chat?.isAdmin ?? false
      }
    }
    .onChange(of: self.chat?.unreadCount) { _, newValue in
      guard let newValue, newValue > 0 else { return }
      self.markMessagesAsRead()
    }
  }
}

#Preview {
  ChatView<XXDKMock>(
    chatId: previewChatId,
    chatTitle: "Mayur"
  )
  .mock()
}
