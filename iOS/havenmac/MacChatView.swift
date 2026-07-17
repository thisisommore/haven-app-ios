//
//  MacChatView.swift
//  haven
//
//  Chat detail column: message history plus the composer, with channel
//  options and reaction sheets.
//

import SwiftUI

struct MacChatView: View {
  @State private var controller: ChatPageController

  private let chatId: UUID

  @EnvironmentObject private var xxdk: XXDK
  @EnvironmentObject private var selectedChat: SelectedChat

  init(chatId: UUID) {
    self.chatId = chatId
    _controller = State(initialValue: ChatPageController(chatId: chatId))
  }

  private var isChannel: Bool {
    guard let chat = controller.chat else { return false }
    return chat.id != UUID.selfId && chat.dmToken == nil
  }

  var body: some View {
    VStack(spacing: 0) {
      MacChatMessagesView(chatId: self.chatId, controller: self.controller)

      if self.controller.isMuted {
        Text("You are muted in this channel")
          .font(.callout)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 10)
          .background(.bar)
      } else {
        MacComposer<XXDK>(
          chat: self.controller.chat,
          replyingTo: self.controller.replyingTo,
          onCancelReply: { self.controller.replyingTo = nil }
        )
      }
    }
    .navigationTitle(self.controller.chat?.name ?? "")
    .toolbar {
      if self.isChannel {
        ToolbarItem(placement: .primaryAction) {
          Button {
            self.controller.activeSheet = .channelOptions
          } label: {
            Image(systemName: "info.circle")
          }
          .help("Channel options")
        }
      }
    }
    .sheet(item: self.$controller.activeSheet) { sheet in
      switch sheet {
      case .channelOptions:
        if let chat = controller.chat {
          ChannelOptionsSheet<XXDK>(
            chat: chat,
            onLeaveChannel: { self.selectedChat.clear() }
          )
          .frame(minWidth: 480, minHeight: 560)
        }
      case let .emojiKeyboard(message):
        EmojiKeyboardSheet { emoji in
          guard !emoji.isEmpty else { return }
          self.controller.sendReaction(emoji, to: message, xxdk: self.xxdk)
        }
        .frame(minWidth: 400, minHeight: 460)
      }
    }
    .onAppear {
      self.controller.onAppear()
    }
    .onChange(of: self.controller.chat?.unreadCount) { _, newValue in
      self.controller.onUnreadCountChanged(newValue: newValue)
    }
  }
}
