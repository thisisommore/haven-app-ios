//
//  Channel+Messaging.swift
//  iOSExample
//

import Bindings
import Foundation
import HavenCore
import SQLiteData

protocol ChannelsMessagingP {
  func send(msg: String, channelId: String)
  func reply(msg: String, channelId: String, replyToMessageIdB64: String)
  func react(
    emoji: String,
    toMessageIdB64: String,
    inChannelId channelId: String
  )
  func delete(channelId: String, messageId: String)
}

class ChannelsMessaging: ChannelsMessagingP {
  @Dependency(\.defaultDatabase) var database
  private let channelsManager: BindingsChannelsManagerWrapper
  init(channelsManager: BindingsChannelsManagerWrapper) {
    self.channelsManager = channelsManager
  }

  /// Send a message to a channel by Channel ID (base64-encoded)
  func send(msg: String, channelId: String) {
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
  func reply(msg: String, channelId: String, replyToMessageIdB64: String) {
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
      try self.channelsManager.sendReply(
        channelIdData,
        message: encodedMsg,
        messageToReactTo: replyToMessageId,
        validUntilMS: 30000,
        cmixParamsJSON: "".data,
        pingsJSON: nil
      )
    } catch {
      AppLogger.messaging.error(
        "sendReply(channel) failed: \(error.localizedDescription, privacy: .public)"
      )
    }
  }

  /// Send a reaction to a specific message in a channel
  func react(
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
      try self.channelsManager.sendReaction(
        channelIdData,
        reaction: emoji,
        messageToReactTo: targetMessageId,
        validUntilMS: Bindings.BindingsValidForeverBindings,
        cmixParamsJSON: "".data
      )
    } catch {
      AppLogger.messaging.error(
        "sendReaction(channel) failed: \(error.localizedDescription, privacy: .public)"
      )
    }
  }

  /// Delete a message from a channel (admin or message owner only)
  func delete(channelId: String, messageId: String) {
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
