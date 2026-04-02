//
//  Chat.page.swift
//  iOSExample
//
//  Created by Om More on 22/09/25.
//

import SQLiteData
import SwiftUI

struct ChatView<T: XXDKP>: View {
  @State private var controller: ChatPageController

  let chatId: UUID
  let chatTitle: String

  @EnvironmentObject var selectedChat: SelectedChat
  @EnvironmentObject var xxdk: T
  @Environment(\.dismiss) private var dismiss

  init(chatId: UUID, chatTitle: String) {
    self.chatId = chatId
    self.chatTitle = chatTitle
    _controller = State(initialValue: ChatPageController(chatId: chatId))
  }

  var body: some View {
    ZStack {
      if let chat = self.controller.chat {
        ChatMessages(
          chat: chat,
          onReply: { message in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
              self.controller.replyingTo = message
            }
          },
          onReact: { message in
            self.controller.reactingTo = message
          },
          onDeleteMessage: { messageExternalId in
            if let channelId = self.controller.chat?.channelId {
              self.controller.deleteMessage(
                messageExternalId, channelId: channelId, xxdk: self.xxdk
              )
            }
          },
          onMuteUser: { pubKey in
            if let channelId = self.controller.chat?.channelId {
              self.controller.muteUser(pubKey, channelId: channelId, xxdk: self.xxdk)
            }
          },
          onDeleteReaction: { reaction in
            if let channelId = self.controller.chat?.channelId {
              self.controller.deleteReaction(
                reaction, channelId: channelId, xxdk: self.xxdk
              )
            }
          }
        )
      }

      if self.controller.firstMessage == nil {
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
          chat: self.controller.chat,
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
            if let chat = self.controller.chat, chat.isChannel {
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
      if let chat = self.controller.chat {
        ChannelOptionsSheet<T>(chat: chat) {
          self.controller.leaveChannel(
            chatId: self.chatId,
            chat: self.controller.chat,
            xxdk: self.xxdk,
            dismiss: { self.dismiss() }
          )
        }
        .environmentObject(self.xxdk)
      }
    }
    .sheet(item: self.$controller.reactingTo) { message in
      EmojiKeyboardSheet { emoji in
        if emoji.isEmpty {
          self.controller.reactingTo = nil
          return
        }
        self.controller.sendReaction(
          emoji, to: message, chat: self.controller.chat, xxdk: self.xxdk
        )
        self.controller.reactingTo = nil
      }
    }
    .onAppear {
      if let chat = self.controller.chat {
        self.controller.onAppear(
          chat: chat, xxdk: self.xxdk
        )
      }
    }
    .onReceive(
      NotificationCenter.default.publisher(for: .userMuteStatusChanged)
    ) { notification in
      if let chat = self.controller.chat {
        self.controller.refreshMuteFromNotification(
          notification, chat: chat, xxdk: self.xxdk
        )
      }
    }
    .id("chat-\(self.chatId.uuidString)")
    .onChange(of: self.controller.showChannelOptions) { _, newValue in
      self.controller.onChannelOptionsVisibilityChanged(
        newValue: newValue, chat: self.controller.chat
      )
    }
    .onChange(of: self.controller.chat?.unreadCount) { _, newValue in
      if let chat = self.controller.chat {
        self.controller.onUnreadCountChanged(
          newValue: newValue, chat: chat
        )
      }
    }
  }
}

#Preview {
  Mock {
    ChatView<XXDKMock>(
      chatId: previewChatId,
      chatTitle: "Mayur"
    )
  }
}
