//
//  Channel+Messaging.swift
//  iOSExample
//

import Bindings
import Foundation
import SQLiteData

protocol ChannelsMessagingP {
  func sendDM(msg: String, channelId: String)
  func sendReply(msg: String, channelId: String, replyToMessageIdB64: String)
  func sendReaction(
    emoji: String,
    toMessageIdB64: String,
    inChannelId channelId: String
  )
  func deleteMessage(channelId: String, messageId: String)
}

class ChannelsMessaging: ChannelsMessagingP {
  @Dependency(\.defaultDatabase) var database
  private let channelsManager: BindingsChannelsManagerWrapper
  init(channelsManager: BindingsChannelsManagerWrapper) {
    self.channelsManager = channelsManager
  }

  /// Persist a reaction to SwiftData
  private func persistReaction(
    messageIdB64: String,
    emoji: String,
    targetMessageId: String,
    isMe: Bool = true
  ) {
    Task {
      do {
        let reaction = MessageReactionModel(
          id: InternalIdGenerator.shared.next(),
          externalId: messageIdB64,
          targetMessageId: targetMessageId,
          emoji: emoji,
          isMe: isMe
        )
        try self.database.write { db in
          try MessageReactionModel.insert { reaction }.execute(db)
        }
      } catch {
        AppLogger.messaging.error(
          "persistReaction failed: \(error.localizedDescription, privacy: .public)"
        )
      }
    }
  }

  /// Send a message to a channel by Channel ID (base64-encoded)
  func sendDM(msg: String, channelId: String) {
    let channelIdData =
      Data(base64Encoded: channelId) ?? channelId.data
    guard let encodedMsg = encodeMessage("<p>\(msg)</p>")
    else {
      AppLogger.messaging.error("sendDM(channel): failed to encode message")
      return
    }
    do {
      try self.channelsManager.sendMessage(
        channelIdData,
        message: encodedMsg,
        validUntilMS: 30000,
        cmixParamsJSON: "".data,
        pingsJSON: nil
      )
    } catch {
      AppLogger.messaging.error(
        "sendDM(channel) failed: \(error.localizedDescription, privacy: .public)"
      )
    }
  }

  /// Send a reply to a specific message in a channel
  func sendReply(msg: String, channelId: String, replyToMessageIdB64: String) {
    let channelIdData =
      Data(base64Encoded: channelId) ?? channelId.data
    guard let replyToMessageId = Data(base64Encoded: replyToMessageIdB64)
    else {
      return
    }
    guard let encodedMsg = encodeMessage("<p>\(msg)</p>")
    else {
      AppLogger.messaging.error("sendReply(channel): failed to encode message")
      return
    }
    do {
      let report = try channelsManager.sendReply(
        channelIdData,
        message: encodedMsg,
        messageToReactTo: replyToMessageId,
        validUntilMS: 30000,
        cmixParamsJSON: "".data,
        pingsJSON: nil
      )
      if let report {
        if let mid = report.messageID {} else {}
      }
    } catch {
      AppLogger.messaging.error(
        "sendReply(channel) failed: \(error.localizedDescription, privacy: .public)"
      )
    }
  }

  /// Send a reaction to a specific message in a channel
  func sendReaction(
    emoji: String,
    toMessageIdB64: String,
    inChannelId channelId: String
  ) {
    let channelIdData =
      Data(base64Encoded: channelId) ?? channelId.data
    guard let targetMessageId = Data(base64Encoded: toMessageIdB64)
    else {
      return
    }
    do {
      let report = try channelsManager.sendReaction(
        channelIdData,
        reaction: emoji,
        messageToReactTo: targetMessageId,
        validUntilMS: Bindings.BindingsValidForeverBindings,
        cmixParamsJSON: "".data
      )
      if let report, let messageID = report.messageID {
        self.persistReaction(
          messageIdB64: messageID.base64EncodedString(),
          emoji: emoji,
          targetMessageId: toMessageIdB64,
          isMe: true
        )
      }
    } catch {
      AppLogger.messaging.error(
        "sendReaction(channel) failed: \(error.localizedDescription, privacy: .public)"
      )
    }
  }

  /// Delete a message from a channel (admin or message owner only)
  func deleteMessage(channelId: String, messageId: String) {
    let channelIdData = Data(base64Encoded: channelId) ?? channelId.data
    guard let messageIdData = Data(base64Encoded: messageId)
    else {
      return
    }

    do {
      try self.channelsManager.deleteMessage(
        channelIdData, targetMessageIdBytes: messageIdData, cmixParamsJSON: "".data
      )
    } catch {
      AppLogger.messaging.error(
        "deleteMessage failed: \(error.localizedDescription, privacy: .public)"
      )
    }
  }
}
