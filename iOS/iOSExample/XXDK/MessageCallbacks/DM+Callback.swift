//
//  DM+Callback.swift
//  iOSExample
//
//  Created by Om More on 24/09/25.
//

import Bindings
import HavenCore
import SQLiteData

// DMReceiver's are callbacks for message processing. These include
// message reception and retrieval of specific data to process a message.
// DmCallbacks are events that signify the UI should be updated
// for full details see the docstrings or the "bindings" folder
// inside the core codebase.
// We implement them both inside the same object for convenience of passing updates to the UI.
// Your implementation may vary based on your needs.

struct ReceivedMessage: Identifiable {
  var Msg: String
  var id = UUID()
}

final class DMReceiverBuilder: NSObject, ObservableObject, Bindings.BindingsDMReceiverProtocol, Bindings
  .BindingsDmCallbacksProtocol, Bindings.BindingsDMReceiverBuilderProtocol {
  func build(_: String?) -> (any BindingsDMReceiverProtocol)? {
    return self
  }

  func updateSentStatus(
    _ uuid: Int64, messageID: Data?, timestamp _: Int64, roundID _: Int64, status: Int64
  ) {
    guard let parsedStatus = MessageStatus(status)
    else {
      AppLogger.messaging.error(
        "updateSentStatus invalid status=\(status, privacy: .public) uuid=\(uuid, privacy: .public)"
      )
      return
    }

    do {
      var message = try database.read { db in
        try ChatMessageModel.where { $0.id.eq(uuid) }.fetchOne(db)
      }
      if message == nil, let messageID {
        let messageIDB64 = messageID.base64EncodedString()
        message = try self.database.read { db in
          try ChatMessageModel.where { $0.externalId.eq(messageIDB64) }.fetchOne(db)
        }
      }

      if var message {
        try self.database.write { db in
          if parsedStatus == .failed {
            try ChatMessageModel.delete(message).execute(db)
          } else {
            message.status = parsedStatus
            try ChatMessageModel.update(message).execute(db)
          }
        }
        return
      }

      var reaction = try database.read { db in
        try MessageReactionModel.where { $0.id.eq(uuid) }.fetchOne(db)
      }
      if reaction == nil, let messageID {
        let messageIDB64 = messageID.base64EncodedString()
        reaction = try self.database.read { db in
          try MessageReactionModel.where { $0.externalId.eq(messageIDB64) }.fetchOne(db)
        }
      }

      guard var reaction else { return }

      try self.database.write { db in
        if parsedStatus == .failed {
          try MessageReactionModel.delete(reaction).execute(db)
        } else {
          reaction.status = parsedStatus
          try MessageReactionModel.update(reaction).execute(db)
        }
      }
    } catch {
      AppLogger.messaging.error(
        "updateSentStatus db operation failed: \(error.localizedDescription, privacy: .public)"
      )
    }
  }

  func eventUpdate(_ eventType: Int64, jsonData: Data?) {
    guard let jsonData
    else {
      AppLogger.messaging.error(
        "DM event update payload is nil for eventType \(eventType, privacy: .public)"
      )
      return
    }

    do {
      switch eventType {
      case 1000:
        _ = try Parser.decode(DmNotificationUpdateJSON.self, from: jsonData)
      case 2000:
        _ = try Parser.decode(DmBlockedUserJSON.self, from: jsonData)
      case 3000:
        _ = try Parser.decode(DmMessageReceivedJSON.self, from: jsonData)
      case 4000:
        _ = try Parser.decode(DmMessageDeletedJSON.self, from: jsonData)
      default: break
      }
    } catch {
      AppLogger.messaging.error(
        "DM event update parse failed for eventType \(eventType, privacy: .public): \(error.localizedDescription, privacy: .public)"
      )
    }
  }

  @Dependency(\.defaultDatabase) private var database
  private let receiverHelpers = ReceiverHelpers.shared

  func deleteMessage(_: Data?, senderPubKey _: Data?) -> Bool {
    return true
  }

  func getConversation(_: Data?) -> Data? {
    return "".data
  }

  func getConversations() -> Data? {
    return "[]".data
  }

  func receive(
    _ messageID: Data?, nickname _: String?, text: Data?, partnerKey: Data?, senderKey: Data?,
    dmToken: Int32, codeset: Int, timestamp: Int64, roundId _: Int64, mType _: Int64,
    status: Int64
  ) -> Int64 {
    guard let messageID else { fatalError("no msg id") }
    guard let text else { fatalError("no text") }
    guard let decodedMessage = decodeMessage(text.base64EncodedString())
    else {
      fatalError("decode failed")
    }

    let codename: String
    let color: Int
    do {
      (codename, color) = try ReceiverHelpers.parseIdentity(
        pubKey: partnerKey, codeset: codeset
      )
    } catch {
      fatalError("\(error)")
    }

    let m = try! self.persistIncoming(
      message: decodedMessage, codename: codename, partnerKey: partnerKey,
      senderKey: senderKey, dmToken: dmToken, messageId: messageID, color: color,
      timestamp: timestamp, status: status
    )
    // Note: this should be a UUID in your database so
    // you can uniquely identify the message.
    return m.id
  }

  func receiveReaction(
    _: Data?, reactionTo _: Data?, nickname _: String?, reaction _: String?,
    partnerKey _: Data?, senderKey _: Data?, dmToken _: Int32, codeset _: Int,
    timestamp _: Int64, roundId _: Int64, status _: Int64
  ) -> Int64 {
    // Note: this should be a UUID in your database so
    // you can uniquely identify the message.
    return InternalIdGenerator.shared.next()
  }

  func receiveReply(
    _ messageID: Data?, reactionTo _: Data?, nickname _: String?, text: String?,
    partnerKey: Data?, senderKey: Data?, dmToken: Int32, codeset: Int, timestamp: Int64,
    roundId _: Int64, status: Int64
  ) -> Int64 {
    guard let messageID else { fatalError("no msg id") }
    let replyTextB64 = text ?? ""
    guard let decodedReply = decodeMessage(replyTextB64)
    else {
      fatalError("decode failed")
    }

    let codename: String
    let color: Int
    do {
      (codename, color) = try ReceiverHelpers.parseIdentity(
        pubKey: partnerKey, codeset: codeset
      )
    } catch {
      fatalError("\(error)")
    }

    let m = try! self.persistIncoming(
      message: decodedReply, codename: codename, partnerKey: partnerKey,
      senderKey: senderKey, dmToken: dmToken, messageId: messageID, color: color,
      timestamp: timestamp, status: status
    )
    return m.id
  }

  func receiveText(
    _ messageID: Data?, nickname _: String?, text: String?, partnerKey: Data?, senderKey: Data?,
    dmToken: Int32, codeset: Int, timestamp: Int64, roundId _: Int64, status: Int64
  ) -> Int64 {
    guard let messageID else { fatalError("no msg id") }
    let messageTextB64 = text ?? ""
    guard let decodedText = decodeMessage(messageTextB64)
    else {
      fatalError("decode failed")
    }

    let codename: String
    let color: Int
    do {
      (codename, color) = try ReceiverHelpers.parseIdentity(
        pubKey: partnerKey, codeset: codeset
      )
    } catch {
      fatalError("\(error)")
    }

    let m = try! self.persistIncoming(
      message: decodedText, codename: codename, partnerKey: partnerKey,
      senderKey: senderKey, dmToken: dmToken, messageId: messageID, color: color,
      timestamp: timestamp, status: status
    )
    return m.id
  }

  private func persistIncoming(
    message: String, codename: String?, partnerKey: Data?, senderKey: Data?, dmToken: Int32,
    messageId: Data, color: Int, timestamp: Int64, status: Int64
  ) throws -> ChatMessageModel {
    guard let partnerKey else { fatalError("partner key is not available") }
    let name =
      (codename?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap {
        $0.isEmpty ? nil : $0
      } ?? "Unknown"

    let chat = try fetchOrCreateDMChat(
      codename: name, pubKey: partnerKey, dmToken: dmToken,
      color: color
    )

    return try! self.receiverHelpers.persistIncomingMessage(
      chat: chat,
      text: message,
      messageId: messageId.base64EncodedString(),
      senderPubKey: senderKey,
      senderCodename: name,
      dmToken: dmToken,
      color: color,
      timestamp: timestamp,
      status: status
    )
  }

  private func fetchOrCreateDMChat(
    codename: String, pubKey: Data?, dmToken: Int32?, color: Int
  ) throws -> ChatModel {
    if let pubKey {
      if let existingByKey = try database.read({ db in
        try ChatModel.where { $0.pubKey.eq(pubKey) }.fetchOne(db)
      }) {
        return existingByKey
      } else {
        guard let dmToken else { throw XXDKError.dmTokenRequired }
        let newChat = ChatModel(
          pubKey: pubKey, name: codename, dmToken: dmToken, color: color
        )
        try database.write { db in
          try ChatModel.insert { newChat }.execute(db)
        }
        return newChat
      }
    } else {
      // Fallback to codename-based lookup (may collide)
      if let existingByName = try database.read({ db in
        try ChatModel.where { $0.name.eq(codename) }.fetchOne(db)
      }) {
        return existingByName
      } else {
        throw XXDKError.pubkeyRequired
      }
    }
  }
}
