//
//  Chat.page.swift
//  iOSExample
//
//  Created by Om More on 22/09/25.
//

import SQLiteData
import SwiftUI

struct ChatView<T: XXDKP>: View {
  @State private var controller = ChatPageController()

  let chatId: UUID
  let chatTitle: String

  @EnvironmentObject var selectedChat: SelectedChat
  @EnvironmentObject var xxdk: T
  @Environment(\.dismiss) private var dismiss

  @Dependency(\.defaultDatabase) var database
  @FetchOne private var chat: ChatModel?
  @FetchOne private var firstMessage: ChatMessageModel?

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
          self.controller.replyingTo = message
        }
      } onReact: { message in
        self.controller.reactingTo = message
      } onDeleteReaction: { reaction in
        self.controller.deleteReaction(
          reaction, channelId: self.chat?.channelId, xxdk: self.xxdk
        )
      }
      if self.firstMessage == nil {
        EmptyChatView()
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.appBackground)
    .safeAreaInset(edge: .bottom, spacing: 0) {
      if self.controller.isMuted {
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
          replyTo: self.controller.replyingTo,
          onCancelReply: {
            self.controller.replyingTo = nil
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
          self.controller.showChannelOptions = true
        } label: {
          HStack(spacing: 4) {
            Text(self.chatTitle == "<self>" ? "Notes" : self.chatTitle)
              .font(.headline.weight(.semibold))
              .foregroundStyle(.primary)
            if let chat, chat.isChannel {
              if chat.isSecret == true {
                SecretBadge()
              }
              if self.controller.isAdmin {
                AdminBadge()
              }
            }
          }
        }
      }
    }
    .sheet(isPresented: self.$controller.showChannelOptions) {
      if let chat = self.chat {
        ChannelOptionsView<T>(chat: chat) {
          self.controller.leaveChannel(
            chatId: self.chatId,
            chat: self.chat,
            xxdk: self.xxdk,
            database: self.database,
            dismiss: { self.dismiss() }
          )
        }
        .environmentObject(self.xxdk)
      }
    }
    .sheet(item: self.$controller.reactingTo) { message in
      NavigationStack {
        EmojiKeyboard { emoji in
          if emoji.isEmpty {
            self.controller.reactingTo = nil
            return
          }
          self.controller.sendReaction(
            emoji, to: message, chat: self.chat, xxdk: self.xxdk
          )
          self.controller.reactingTo = nil
        }
      }
    }
    .onAppear {
      if let chat {
        self.controller.onAppear(
          chat: chat, xxdk: self.xxdk, database: self.database
        )
      }
    }
    .onReceive(
      NotificationCenter.default.publisher(for: .userMuteStatusChanged)
    ) { notification in
      if let chat {
        self.controller.refreshMuteFromNotification(
          notification, chat: chat, xxdk: self.xxdk
        )
      }
    }
    .id("chat-\(self.chatId.uuidString)")
    .onChange(of: self.controller.showChannelOptions) { _, newValue in
      self.controller.onChannelOptionsVisibilityChanged(
        newValue: newValue, chat: self.chat
      )
    }
    .onChange(of: self.chat?.unreadCount) { _, newValue in
      if let chat {
        self.controller.onUnreadCountChanged(
          newValue: newValue, chat: chat, database: self.database
        )
      }
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
