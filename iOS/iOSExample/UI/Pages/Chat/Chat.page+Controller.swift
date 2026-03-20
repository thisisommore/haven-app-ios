//
//  Chat.page+Controller.swift
//  iOSExample
//
//  Created by Om More on 22/09/25.
//

import Observation
import SQLiteData
import SwiftUI

@MainActor
@Observable
final class ChatPageController {
  var replyingTo: ChatMessageModel?
  var reactingTo: ChatMessageModel?
  var showChannelOptions: Bool = false
  var isAdmin: Bool = false
  var isMuted: Bool = false

  func markMessagesAsRead(chat: ChatModel?, database: any DatabaseWriter) {
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

    try? database.write { db in
      for var message in unreadMessages {
        message.isRead = true
        try ChatMessageModel.update(message).execute(db)
      }
      try ChatModel.update(updatedChat).execute(db)
    }
  }

  func onAppear<T: XXDKP>(chat: ChatModel?, xxdk: T, database: any DatabaseWriter) {
    self.isAdmin = chat?.isAdmin ?? false
    if Self.isChannel(chat), let channelId = chat?.channelId {
      self.isMuted = xxdk.channel.isMuted(channelId: channelId)
    } else {
      self.isMuted = false
    }
    self.markMessagesAsRead(chat: chat, database: database)
  }

  func refreshMuteFromNotification<T: XXDKP>(
    _ notification: Notification, chat: ChatModel?, xxdk: T
  ) {
    guard Self.isChannel(chat), let channelId = chat?.channelId else { return }
    if let channelID = notification.userInfo?["channelID"] as? String,
       channelID == channelId {
      self.isMuted = xxdk.channel.isMuted(channelId: channelId)
    }
  }

  func onChannelOptionsVisibilityChanged(newValue: Bool, chat: ChatModel?) {
    if !newValue {
      self.isAdmin = chat?.isAdmin ?? false
    }
  }

  func onUnreadCountChanged(
    newValue: Int?, chat: ChatModel?, database: any DatabaseWriter
  ) {
    guard let newValue, newValue > 0 else { return }
    self.markMessagesAsRead(chat: chat, database: database)
  }

  func sendReaction<T: XXDKP>(
    _ emoji: String, to message: ChatMessageModel, chat: ChatModel?, xxdk: T
  ) {
    guard !emoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    guard let chat else { return }

    if let token = chat.dmToken, let pubKey = chat.pubKey {
      Task.detached {
        xxdk.dm?.sendReaction(
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
        xxdk.channel.msg.sendReaction(
          emoji: emoji,
          toMessageIdB64: message.externalId,
          inChannelId: channelId
        )
      }
    }
  }

  func deleteReaction<T: XXDKP>(
    _ reaction: MessageReactionModel, channelId: String?, xxdk: T
  ) {
    guard let channelId else { return }

    Task.detached {
      xxdk.channel.msg.deleteMessage(
        channelId: channelId,
        messageId: reaction.externalId
      )
    }
  }

  func leaveChannel<T: XXDKP>(
    chatId: UUID, chat: ChatModel?, xxdk: T, database: any DatabaseWriter,
    dismiss: @escaping () -> Void
  ) {
    Task {
      do {
        guard let channelId = chat?.channelId else { return }
        try xxdk.channel.leaveChannel(channelId: channelId)
        let chatsToDelete =
          try? await database.read { db in
            try ChatModel.where { $0.id.eq(chatId) }.fetchAll(db)
          }
        if let chatsToDelete {
          try? await database.write { db in
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

  static func isChannel(_ chat: ChatModel?) -> Bool {
    guard let chat else { return false }
    return chat.name != "<self>" && chat.dmToken == nil
  }
}
