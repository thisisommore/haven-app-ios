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

  @EnvironmentObject var selectedChat: SelectedChat
  @EnvironmentObject var xxdk: T
  @Environment(\.dismiss) private var dismiss

  init(chatId: UUID) {
    self.chatId = chatId
    _controller = State(initialValue: ChatPageController(chatId: chatId))
  }

  private var chatTitle: String {
    guard let name = self.controller.chat?.name else {
      return ""
    }
    return name == "ChatModel.selfChatInternalName" ? "Notes" : name
  }

  private var toolbar: some ToolbarContent {
    Group {
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
          self.controller.activeSheet = .channelOptions
        } label: {
          HStack(spacing: 4) {
            Text(self.chatTitle)
              .font(.headline.weight(.semibold))
              .foregroundStyle(.primary)
            if let chat = self.controller.chat {
              if chat.isChannel {
                if chat.isSecret == true {
                  SecretBadge()
                }
                if chat.isAdmin {
                  AdminBadge()
                }
              }
              if !chat.isSelfChat {
                NotificationStatusIcon(level: chat.notificationLevel)
              }
            }
          }
        }
      }
    }
  }

  private var chatMessagesStack: some View {
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
            self.controller.activeSheet = .emojiKeyboard(message)
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
  }

  @ViewBuilder
  private var bottomInset: some View {
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

  private var root: some View {
    self.chatMessagesStack
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.appBackground)
      .safeAreaInset(edge: .bottom, spacing: 0) {
        self.bottomInset
      }
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarBackButtonHidden(true)
      .toolbar {
        self.toolbar
      }
      .sheet(
        item: self.$controller.activeSheet
      ) { sheet in
        switch sheet {
        case .channelOptions:
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
        case let .emojiKeyboard(message):
          EmojiKeyboardSheet { emoji in
            if emoji.isEmpty {
              self.controller.activeSheet = nil
              return
            }
            self.controller.sendReaction(
              emoji, to: message, chat: self.controller.chat, xxdk: self.xxdk
            )
            self.controller.activeSheet = nil
          }
        }
      }
  }

  var body: some View {
    self.root
      .onAppear {
        self.controller.onAppear()
      }
      .id("chat-\(self.chatId.uuidString)")
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
    ChatView<XXDKMock>(chatId: previewChatId)
  }
}
