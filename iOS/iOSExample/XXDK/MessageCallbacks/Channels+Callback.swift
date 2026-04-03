import Bindings
import Foundation
import SQLiteData

final class ChannelEventModelBuilder: NSObject, BindingsEventModelProtocol, BindingsEventModelBuilderProtocol {
  @Dependency(\.defaultDatabase) private var database
  private let receiverHelpers = ReceiverHelpers.shared
  func build(_: String?) -> BindingsEventModelProtocol? {
    return self
  }

  func update(
    fromMessageID _: Data?,
    messageUpdateInfoJSON _: Data?,
    ret0_ _: UnsafeMutablePointer<Int64>?
  ) throws {}

  func update(fromUUID uuid: Int64, messageUpdateInfoJSON: Data?) throws {
    guard let messageUpdateInfoJSON
    else { return }

    let updateInfo = try Parser.decode(MessageUpdateInfoJSON.self, from: messageUpdateInfoJSON)
    let message = try database.read { db in
      try ChatMessageModel.where { $0.id.eq(uuid) }.fetchOne(db)
    }
    if var message {
      if updateInfo.StatusSet, let newStatusRaw = updateInfo.Status,
         let newStatus = MessageStatus(newStatusRaw), newStatus == .failed {
        try self.database.write { db in
          try ChatMessageModel.delete(message).execute(db)
        }
        return
      }

      if updateInfo.MessageIDSet, let newMessageId = updateInfo.MessageID {
        message.externalId = newMessageId
      }
      if updateInfo.StatusSet, let newStatusRaw = updateInfo.Status,
         let newStatus = MessageStatus(newStatusRaw) {
        message.status = newStatus
      }
      try self.database.write { db in
        try ChatMessageModel.update(message).execute(db)
      }
      return
    }

    let reaction = try database.read { db in
      try MessageReactionModel.where { $0.id.eq(uuid) }.fetchOne(db)
    }
    if var reaction {
      if updateInfo.StatusSet, let newStatusRaw = updateInfo.Status,
         let newStatus = MessageStatus(newStatusRaw), newStatus == .failed {
        try self.database.write { db in
          try MessageReactionModel.delete(reaction).execute(db)
        }
        return
      }

      if updateInfo.MessageIDSet, let newMessageId = updateInfo.MessageID {
        reaction.externalId = newMessageId
      }
      if updateInfo.StatusSet, let newStatusRaw = updateInfo.Status,
         let newStatus = MessageStatus(newStatusRaw) {
        reaction.status = newStatus
      }
      try self.database.write { db in
        try MessageReactionModel.update(reaction).execute(db)
      }
    }
  }

  private func existingStoredMessage(
    messageId: String
  ) throws -> ChatMessageModel? {
    try self.database.read { db in
      try ChatMessageModel.where { $0.externalId.eq(messageId) }.fetchOne(db)
    }
  }

  /// Persist a message into SwiftData
  private func persistMessage(
    channelId: String, text: String, senderCodename: String, senderPubKey: Data, messageIdB64: String,
    replyTo: String? = nil, timestamp: Int64, dmToken: Int32? = nil, color: Int, nickname: String? = nil,
    status: Int64
  ) -> Int64 {
    do {
      let chat = try database.read { db in
        try ChatModel.where { $0.channelId.eq(channelId) }.fetchOne(db)
      }

      guard let chat else {
        throw XXDKError.channelNotFound
      }

      let msg = try receiverHelpers.persistIncomingMessage(
        chat: chat,
        text: text,
        messageId: messageIdB64,
        senderPubKey: senderPubKey,
        senderCodename: senderCodename,
        nickname: nickname,
        dmToken: dmToken ?? 0,
        color: color,
        replyTo: replyTo,
        timestamp: timestamp,
        status: status
      )

      return msg.id
    } catch {
      AppLogger.storage.error(
        "persist msg error: \(error.localizedDescription, privacy: .public)"
      )
      fatalError(
        error.localizedDescription
      )
    }
  }

  func joinChannel(_: String?) {}

  func leaveChannel(_: Data?) {}
  func receiveMessage(
    _ channelID: Data?, messageID: Data?, nickname: String?, text: String?, pubKey: Data?,
    dmToken: Int32, codeset: Int, timestamp: Int64, lease _: Int64, roundID _: Int64,
    messageType _: Int64, status: Int64, hidden _: Bool
  ) -> Int64 {
    guard let messageID, let text, let pubKey else {
      fatalError("unexpected nil params found")
    }
    let messageIdB64 = messageID.base64EncodedString()

    if let existing = try? existingStoredMessage(messageId: messageIdB64) {
      return existing.id
    }

    do {
      let (codename, color) = try ReceiverHelpers.parseIdentity(
        pubKey: pubKey, codeset: codeset
      )
      guard let channelIdB64 = channelID?.base64EncodedString(), let decodedText = decodeMessage(text) else {
        fatalError("failed to decode channelID/text")
      }
      return self.persistMessage(
        channelId: channelIdB64,
        text: decodedText,
        senderCodename: codename,
        senderPubKey: pubKey,
        messageIdB64: messageIdB64,
        timestamp: timestamp,
        dmToken: dmToken,
        color: color,
        nickname: nickname,
        status: status
      )
    } catch {
      fatalError("something went wrong \(error)")
    }
  }

  func receiveReaction(
    _: Data?, messageID: Data?, reactionTo: Data?, nickname: String?, reaction: String?, pubKey: Data?,
    dmToken: Int32, codeset: Int, timestamp _: Int64, lease _: Int64, roundID _: Int64, messageType _: Int64,
    status: Int64, hidden _: Bool
  ) -> Int64 {
    guard let pubKey else { fatalError("no pub key") }
    let reactionText = reaction ?? ""
    let targetMessageIdB64 = reactionTo?.base64EncodedString()

    guard let targetId = targetMessageIdB64, !targetId.isEmpty
    else {
      fatalError("no target id")
    }
    guard !reactionText.isEmpty
    else {
      fatalError("no reaction")
    }
    guard let reactionMessageId = messageID?.base64EncodedString(), !reactionMessageId.isEmpty
    else {
      fatalError("no reaction message id")
    }

    do {
      let (codename, color) = try ReceiverHelpers.parseIdentity(
        pubKey: pubKey, codeset: codeset
      )

      if let existing = try? self.database.read({ db in
        try MessageReactionModel.where { $0.externalId.eq(reactionMessageId) }.fetchOne(db)
      }) {
        return existing.id
      }
      let sender = try self.receiverHelpers.upsertSender(
        pubKey: pubKey,
        codename: codename,
        nickname: nickname,
        dmToken: dmToken,
        color: color
      )
      let isSelfSender = self.receiverHelpers.isSenderSelf(senderPubKey: pubKey)
      let reactionSenderId = isSelfSender ? UUID.selfId : sender.id

      // De-duplicate by message target + emoji + sender.
      // If a duplicate exists, update its id instead of creating another row.
      let sameSenderReactions = try database.read { db in
        try MessageReactionModel.where {
          $0.targetMessageId.eq(targetId) && $0.emoji.eq(reactionText)
            && $0.senderId.eq(reactionSenderId)
        }.fetchAll(db)
      }

      let record: MessageReactionModel
      if var canonical = sameSenderReactions.first(where: { $0.externalId == reactionMessageId })
        ?? sameSenderReactions.first {
        if canonical.externalId != reactionMessageId {
          canonical.externalId = reactionMessageId
        }
        if canonical.senderId != reactionSenderId {
          canonical.senderId = reactionSenderId
        }
        if let newStatus = MessageStatus(status) {
          canonical.status = newStatus
        }
        try self.database.write { db in
          try MessageReactionModel.update(canonical).execute(db)
        }

        // If duplicates already exist, keep one canonical row.
        for duplicate in sameSenderReactions where duplicate.id != canonical.id {
          try database.write { db in
            try MessageReactionModel.delete(duplicate).execute(db)
          }
        }
        record = canonical
      } else {
        let id = InternalIdGenerator.shared.next()
        var newRecord = MessageReactionModel(
          id: id,
          externalId: reactionMessageId,
          targetMessageId: targetId,
          emoji: reactionText,
          senderId: reactionSenderId
        )
        if let newStatus = MessageStatus(status) {
          newRecord.status = newStatus
        }
        try self.database.write { db in
          try MessageReactionModel.insert { newRecord }.execute(db)
        }
        record = newRecord
      }

      return record.id
    } catch {
      fatalError(
        "failed to store message reaction \(error.localizedDescription)"
      )
    }
  }

  func receiveReply(
    _ channelID: Data?, messageID: Data?, reactionTo: Data?, nickname: String?, text: String?,
    pubKey: Data?, dmToken: Int32, codeset: Int, timestamp: Int64, lease _: Int64, roundID _: Int64,
    messageType _: Int64, status: Int64, hidden _: Bool
  ) -> Int64 {
    guard let messageID, let text, let reactionTo, let channelID, let pubKey else {
      fatalError("unexpected nil params found")
    }
    let messageIdB64 = messageID.base64EncodedString()

    if let existing = try? existingStoredMessage(messageId: messageIdB64) {
      return existing.id
    }

    let nick: String
    let color: Int
    do {
      (nick, color) = try ReceiverHelpers.parseIdentity(pubKey: pubKey, codeset: codeset)
    } catch {
      fatalError("\(error)")
    }
    let channelIdB64 = channelID.base64EncodedString()
    guard let decodedReply = decodeMessage(text) else {
      fatalError("failed to decode text")
    }
    return self.persistMessage(
      channelId: channelIdB64,
      text: decodedReply,
      senderCodename: nick,
      senderPubKey: pubKey,
      messageIdB64: messageIdB64,
      replyTo: reactionTo.base64EncodedString(),
      timestamp: timestamp,
      dmToken: dmToken, color: color,
      nickname: nickname, status: status
    )
  }

  func getMessage(_ messageID: Data?) throws -> Data {
    guard let messageID
    else {
      throw EventModelError.messageNotFound
    }

    let messageIdB64 = messageID.base64EncodedString()
    if let sender = try? database.read({ db in
      try ChatMessageModel
        .where { $0.externalId.eq(messageIdB64) }
        .join(MessageSenderModel.all) { $0.senderId.eq($1.id) }
        .select { _, sender in sender }
        .fetchOne(db)
    }) {
      let pubKeyData = sender.pubkey
      let modelMsg = ModelMessageJSON(
        pubKey: pubKeyData,
        messageID: messageID
      )
      return try Parser.encode(modelMsg)
    }

    // Check MessageReaction - if message not found, check if it's a reaction
    if let sender = try? database.read({ db in
      try MessageReactionModel
        .where { $0.externalId.eq(messageIdB64) }
        .join(MessageSenderModel.all) { $0.senderId.eq($1.id) }
        .select { _, sender in sender }
        .fetchOne(db)
    }) {
      let pubKeyData = sender.pubkey
      let modelMsg = ModelMessageJSON(
        pubKey: pubKeyData,
        messageID: messageID
      )
      return try Parser.encode(modelMsg)
    }
    // Not found
    throw EventModelError.messageNotFound
  }

  func deleteMessage(_ messageID: Data?) throws {
    guard let messageID
    else {
      fatalError("message id is nil")
    }

    let messageIdB64 = messageID.base64EncodedString()

    do {
      // First, try to find and delete a ChatMessage
      let message = try database.read { db in
        try ChatMessageModel.where { $0.externalId.eq(messageIdB64) }.fetchOne(db)
      }

      if let message {
        try self.database.write { db in
          try ChatMessageModel.delete(message).execute(db)
        }
        return
      }

      // If no message found, check for reactions
      let reaction = try database.read { db in
        try MessageReactionModel.where { $0.externalId.eq(messageIdB64) }.fetchOne(db)
      }

      if let reaction {
        try self.database.write { db in
          try MessageReactionModel.delete(reaction).execute(db)
        }
        return
      }
    } catch {
      AppLogger.storage.error(
        "EventModel: Failed to delete message/reaction: \(error.localizedDescription, privacy: .public)"
      )
    }
  }

  func muteUser(_ channelID: Data?, pubkey: Data?, unmute: Bool) {
    guard let channelID, let pubkey
    else {
      fatalError("unexpected nil params found")
    }

    let channelIdB64 = channelID.base64EncodedString()

    do {
      try self.database.write { db in
        guard try ChatModel.where({ $0.channelId.eq(channelIdB64) }).fetchOne(db) != nil
        else {
          fatalError("mute callback received for unknown channel")
        }

        let existing = try ChannelMutedUserModel.where {
          $0.channelId.eq(channelIdB64) && $0.pubkey.eq(pubkey)
        }.fetchOne(db)

        if unmute {
          if let existing {
            try ChannelMutedUserModel.delete(existing).execute(db)
          }
        } else if existing == nil {
          let mutedUser = ChannelMutedUserModel(
            channelId: channelIdB64,
            pubkey: pubkey
          )
          try ChannelMutedUserModel.insert { mutedUser }.execute(db)
        }
      }
    } catch {
      fatalError("failed to persist channel mute state: \(error.localizedDescription)")
    }
  }
}

