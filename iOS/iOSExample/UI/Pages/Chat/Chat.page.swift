//
//  Chat.page.swift
//  iOSExample
//
//  Created by Om More on 22/09/25.
//

import SQLiteData
import SwiftUI

struct ChatView<T: XXDKP>: View {
  let chatId: String
  let chatTitle: String

  @EnvironmentObject var selectedChat: SelectedChat
  @Dependency(\.defaultDatabase) var database
  @FetchOne private var chat: ChatModel?

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

  init(chatId: String, chatTitle: String) {
    self.chatId = chatId
    self.chatTitle = chatTitle
    _chat = FetchOne(ChatModel.where { $0.id.eq(chatId) })
  }

  var body: some View {
    ZStack {
      ChatMessages(chatId: self.chatId) { message in
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
          self.replyingTo = message
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .safeAreaInset(edge: .bottom) {
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
            Text("Back")
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
            try self.xxdk.leaveChannel(channelId: self.chatId)
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
      self.isMuted = self.isChannel ? self.xxdk.isMuted(channelId: self.chatId) : false
      // Mark all incoming messages as read
      self.markMessagesAsRead()
    }
    .onReceive(NotificationCenter.default.publisher(for: .userMuteStatusChanged)) { notification in
      if let channelID = notification.userInfo?["channelID"] as? String,
         channelID == chatId {
        guard self.isChannel else { return }
        self.isMuted = self.xxdk.isMuted(channelId: self.chatId)
      }
    }
    .id("chat-\(self.chatId)")
    .onChange(of: self.showChannelOptions) { _, newValue in
      if !newValue {
        self.isAdmin = self.chat?.isAdmin ?? false
      }
    }
    .background(ChatBackgroundView())
  }
}

#Preview {
  ChatView<XXDKMock>(
    chatId: previewChatId,
    chatTitle: "Mayur"
  )
  .mock()
}
