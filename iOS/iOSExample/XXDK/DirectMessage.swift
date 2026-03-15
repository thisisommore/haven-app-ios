//
//  DirectMessage.swift
//  iOSExample
//

import Bindings
import Foundation
import SQLiteData

protocol DirectMessageP {
  func getPublicKey() -> Data?
  func sendDM(msg: String, toPubKey: Data, partnerToken: Int32)
  func sendReply(msg: String, toPubKey: Data, partnerToken: Int32, replyToMessageIdB64: String)
  func sendReaction(
    emoji: String,
    toMessageIdB64: String,
    toPubKey: Data,
    partnerToken: Int32
  )
  func getToken() -> Int64
  func getNickname() throws -> String
  func setNickname(_ nickname: String) throws
}

class DirectMessage: DirectMessageP {
  @Dependency(\.defaultDatabase) var database
  private let DM: BindingsDMClientWrapper
  init(DM: BindingsDMClientWrapper) {
    self.DM = DM
  }

  func getToken() -> Int64 {
    self.DM.getToken()
  }

  func getPublicKey() -> Data? {
    self.DM.getPublicKey()
  }

  func getNickname() throws -> String {
    try self.DM.getNickname()
  }

  func setNickname(_ nickname: String) throws {
    try self.DM.setNickname(nickname)
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

  func sendDM(msg: String, toPubKey: Data, partnerToken: Int32) {
    guard let encodedMsg = encodeMessage("<p>\(msg)</p>")
    else {
      AppLogger.messaging.error("sendDM(DM): failed to encode message")
      return
    }
    do {
      let report = try DM.sendText(
        toPubKey,
        partnerToken: partnerToken,
        message: encodedMsg,
        leaseTimeMS: 0,
        cmixParamsJSON: "".data
      )

      if let report, report.messageID != nil {
        let _: String = {
          if let found = try? database.read({ db in
            try ChatModel.where { $0.pubKey.eq(toPubKey) }.fetchOne(db)
          }) {
            return found.name
          }
          return "Direct Message"
        }()
      }
    } catch {
      AppLogger.messaging.error(
        "Unable to send: \(error.localizedDescription, privacy: .public)"
      )
    }
  }

  /// Send a reply to a specific message in a DM conversation
  func sendReply(
    msg: String,
    toPubKey: Data,
    partnerToken: Int32,
    replyToMessageIdB64: String
  ) {
    guard let replyToMessageId = Data(base64Encoded: replyToMessageIdB64)
    else {
      return
    }
    guard let encodedMsg = encodeMessage("<p>\(msg)</p>")
    else {
      AppLogger.messaging.error("sendReply(DM): failed to encode message")
      return
    }
    do {
      let report = try DM.sendReply(
        toPubKey,
        partnerToken: partnerToken,
        replyMessage: encodedMsg,
        replyToBytes: replyToMessageId,
        leaseTimeMS: 0,
        cmixParamsJSON: "".data
      )
      if let report, report.messageID != nil {
        let _: String = {
          if let found = try? database.read({ db in
            try ChatModel.where { $0.pubKey.eq(toPubKey) }.fetchOne(db)
          }) {
            return found.name
          }
          return "Direct Message"
        }()
      } else {
        AppLogger.messaging.warning("DM sendReply returned no messageID")
      }
    } catch {
      AppLogger.messaging.error(
        "Unable to send reply: \(error.localizedDescription, privacy: .public)"
      )
      fatalError("Unable to send reply: " + error.localizedDescription)
    }
  }

  /// Send a reaction to a specific message in a DM conversation
  func sendReaction(
    emoji: String,
    toMessageIdB64: String,
    toPubKey: Data,
    partnerToken: Int32
  ) {
    guard let targetMessageId = Data(base64Encoded: toMessageIdB64)
    else {
      return
    }
    do {
      let report = try DM.sendReaction(
        toPubKey,
        partnerToken: partnerToken,
        reaction: emoji,
        reactToBytes: targetMessageId,
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
        "Unable to send reaction: \(error.localizedDescription, privacy: .public)"
      )
      fatalError("Unable to send reaction: " + error.localizedDescription)
    }
  }
}
