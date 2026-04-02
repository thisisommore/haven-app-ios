//
//  Chat.page+Controller.swift
//  iOSExample
//
//  Created by Om More on 22/09/25.
//

import Observation
import SQLiteData
import SwiftUI

enum ChatSheet: Identifiable {
  case channelOptions
  case emojiKeyboard(ChatMessageModel)

  var id: String {
    switch self {
    case .channelOptions:
      return "channelOptions"
    case let .emojiKeyboard(message):
      return "emojiKeyboard-\(message.externalId)"
    }
  }
}

@MainActor
@Observable
final class ChatPageController {
  var replyingTo: ChatMessageModel?
  var activeSheet: ChatSheet?
  var isAdmin: Bool = false
  var isMuted: Bool = false

  @ObservationIgnored
  @FetchOne var chat: ChatModel?

  @ObservationIgnored
  @FetchOne var firstMessage: ChatMessageModel?

  @ObservationIgnored
  @Dependency(\.defaultDatabase) var database

  init(chatId: UUID) {
    _chat = FetchOne(ChatModel.where { $0.id.eq(chatId) })
    _firstMessage = FetchOne(ChatMessageModel.where { $0.chatId.eq(chatId) })
  }

  func markMessagesAsRead(chat: ChatModel) {
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

  func onAppear<T: XXDKP>(chat: ChatModel, xxdk: T) {
    self.isAdmin = chat.isAdmin
    if chat.isChannel, let channelId = chat.channelId {
      self.isMuted = xxdk.channel.isMuted(channelId: channelId)
    } else {
      self.isMuted = false
    }
    self.markMessagesAsRead(chat: chat)
  }

  func refreshMuteFromNotification<T: XXDKP>(
    _ notification: Notification, chat: ChatModel, xxdk: T
  ) {
    guard chat.isChannel, let channelId = chat.channelId else { return }
    if let channelID = notification.userInfo?["channelID"] as? String,
       channelID == channelId {
      self.isMuted = xxdk.channel.isMuted(channelId: channelId)
    }
  }

  func onSheetDismissed(chat: ChatModel?) {
    self.isAdmin = chat?.isAdmin ?? false
  }

  func onUnreadCountChanged(
    newValue: Int?, chat: ChatModel
  ) {
    guard let newValue, newValue > 0 else { return }
    self.markMessagesAsRead(chat: chat)
  }

  func sendReaction<T: XXDKP>(
    _ emoji: String, to message: ChatMessageModel, chat: ChatModel?, xxdk: T
  ) {
    guard !emoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    guard let chat else { return }

    if let token = chat.dmToken, let pubKey = chat.pubKey {
      Task.detached {
        xxdk.dm?.react(
          emoji: emoji,
          toMessageIdB64: message.externalId,
          toPubKey: pubKey,
          partnerToken: token
        )
      }
      return
    }
    if let channelId = chat.channelId {
      Task.detached {
        xxdk.channel.msg.react(
          emoji: emoji,
          toMessageIdB64: message.externalId,
          inChannelId: channelId
        )
      }
    }
  }

  func deleteReaction<T: XXDKP>(
    _ reaction: MessageReactionModel, channelId: String, xxdk: T
  ) {
    let externalId = reaction.externalId
    Task {
      try? self.database.write { db in
        let match = MessageReactionModel.where { r in
          r.externalId.eq(externalId)
        }
        if var updated = try match.fetchOne(db) {
          updated.status = .deleting
          try MessageReactionModel.update(updated).execute(db)
        }
      }
      Task.detached {
        xxdk.channel.msg.delete(
          channelId: channelId,
          messageId: externalId
        )
      }
    }
  }

  func deleteMessage<T: XXDKP>(
    _ messageExternalId: String, channelId: String, xxdk: T
  ) {
    Task {
      try? self.database.write { db in
        let match = ChatMessageModel.where { msg in
          msg.externalId.eq(messageExternalId)
        }
        if var message = try match.fetchOne(db) {
          message.status = .deleting
          try ChatMessageModel.update(message).execute(db)
        }
      }
      Task.detached {
        xxdk.channel.msg.delete(
          channelId: channelId,
          messageId: messageExternalId
        )
      }
    }
  }

  func muteUser<T: XXDKP>(_ pubKey: Data, channelId: String, xxdk: T) {
    Task.detached {
      do {
        try xxdk.channel.muteUser(channelId: channelId, pubKey: pubKey, mute: true)
      } catch {
        AppLogger.channels.error(
          "muteUser failed: \(error.localizedDescription, privacy: .public)"
        )
      }
    }
  }

  func leaveChannel<T: XXDKP>(
    chatId: UUID, chat: ChatModel?, xxdk: T,
    dismiss: @escaping () -> Void
  ) {
    Task {
      do {
        guard let channelId = chat?.channelId else { return }
        try xxdk.channel.leave(channelId: channelId)
        let chatsToDelete =
          try? await database.read { db in
            try ChatModel.where { $0.id.eq(chatId) }.fetchAll(db)
          }
        if let chatsToDelete {
          try? await self.database.write { db in
            for chatToDelete in chatsToDelete {
              try ChatModel.delete(chatToDelete).execute(db)
            }
          }
        }
        await MainActor.run {
          dismiss()
        }
      } catch {
        AppLogger.channels.error(
          "Failed to leave channel: \(error.localizedDescription, privacy: .public)"
        )
      }
    }
  }
}
