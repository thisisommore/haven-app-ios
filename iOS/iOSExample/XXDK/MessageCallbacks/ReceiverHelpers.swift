//
//  ReceiverHelpers.swift
//  iOSExample
//
//  Common utilities shared between DMReceiver and EventModel
//

import Bindings
import Foundation
import SQLiteData

final class ReceiverHelpers {
  static let shared = ReceiverHelpers()
  private init() {}
  @Dependency(\.defaultDatabase) private var database

  private static var cachedSelfChatId: Data?

  /// Parse identity from pubKey and codeset, returning codename and color
  static func parseIdentity(pubKey: Data?, codeset: Int) throws -> (codename: String, color: Int) {
    guard let identity = try BindingsStatic.constructIdentity(pubKey: pubKey, codeset: codeset)
    else {
      throw EventModelError.identityConstructionFailed
    }
    var colorStr = identity.Color
    if colorStr.hasPrefix("0x") || colorStr.hasPrefix("0X") {
      colorStr.removeFirst(2)
    }
    return (identity.Codename, Int(colorStr, radix: 16) ?? 0)
  }

  /// Check if sender's pubKey matches the "<self>" chat pubKey
  func isSenderSelf(senderPubKey: Data?) -> Bool {
    guard let senderPubKey else { return false }

    if Self.cachedSelfChatId == nil {
      if let selfChat = try? database.read({ db in
        try ChatModel.where { $0.name.eq("<self>") }.fetchOne(db)
      }) {
        Self.cachedSelfChatId = selfChat.pubKey
      }
    }

    if let selfId = Self.cachedSelfChatId {
      return selfId == senderPubKey
    }
    return false
  }

  /// Clear cached self chat ID (call after user switches)
  static func clearSelfChatCache() {
    self.cachedSelfChatId = nil
  }

  /// Fetch or create a sender, updating dmToken and nickname if exists
  func upsertSender(
    pubKey: Data,
    codename: String,
    nickname: String? = nil,
    dmToken: Int32,
    color: Int
  ) throws -> MessageSenderModel {
    if let existing = try database.read({ db in
      try MessageSenderModel.where { $0.pubkey.eq(pubKey) }.fetchOne(db)
    }) {
      var updated = existing
      updated.dmToken = dmToken
      if let nickname, !nickname.isEmpty {
        updated.nickname = nickname
      }
      try self.database.write { db in
        try MessageSenderModel.update(updated).execute(db)
      }
      return updated
    }

    let sender = MessageSenderModel(
      pubkey: pubKey,
      codename: codename,
      nickname: nickname,
      dmToken: dmToken,
      color: color
    )
    try database.write { db in
      try MessageSenderModel.insert { sender }.execute(db)
    }
    return sender
  }

  /// Insert a new text message
  func insertMessage(
    chat: ChatModel,
    sender: MessageSenderModel?,
    text: String,
    messageId: String,
    id: Int64,
    senderPubKey: Data?,
    replyTo: String? = nil,
    timestamp: Int64? = nil,
    status: Int64
  ) throws -> ChatMessageModel {
    let isIncoming = !self.isSenderSelf(senderPubKey: senderPubKey)

    var msg: ChatMessageModel
    if let timestamp {
      msg = ChatMessageModel(
        message: text,
        isIncoming: isIncoming,
        chatId: chat.id,
        senderId: sender?.id,
        id: id,
        externalId: messageId,
        replyTo: replyTo,
        timestamp: Date(timeIntervalSince1970: Double(timestamp) * 1e-6 * 1e-3),
        status: MessageStatus(status)
      )
    } else {
      msg = ChatMessageModel(
        message: text,
        isIncoming: isIncoming,
        chatId: chat.id,
        senderId: sender?.id,
        id: id,
        externalId: messageId,
        replyTo: replyTo,
        timestamp: Date(),
        status: MessageStatus(status)
      )
    }
    msg.isPlain = !MessageTextFormatting.containsHTML(text)
    try self.database.write { db in
      try ChatMessageModel.update(msg).execute(db)
    }

    try self.database.write { db in
      try ChatMessageModel.insert { msg }.execute(db)

      if isIncoming && msg.timestamp > chat.joinedAt {
        var updatedChat = chat
        updatedChat.unreadCount += 1
        try ChatModel.update(updatedChat).execute(db)
      }
    }

    return msg
  }

  /// Persist an incoming message: upserts sender and inserts message
  func persistIncomingMessage(
    chat: ChatModel,
    text: String,
    messageId: String,
    senderPubKey: Data?,
    senderCodename: String?,
    nickname: String? = nil,
    dmToken: Int32,
    color: Int,
    replyTo: String? = nil,
    timestamp: Int64? = nil,
    status: Int64
  ) throws -> ChatMessageModel {
    var sender: MessageSenderModel?
    if let senderCodename, let senderPubKey {
      sender = try self.upsertSender(
        pubKey: senderPubKey,
        codename: senderCodename,
        nickname: nickname,
        dmToken: dmToken,
        color: color
      )
    }

    let id = InternalIdGenerator.shared.next()
    return try self.insertMessage(
      chat: chat,
      sender: sender,
      text: text,
      messageId: messageId,
      id: id,
      senderPubKey: senderPubKey,
      replyTo: replyTo,
      timestamp: timestamp,
      status: status
    )
  }
}
