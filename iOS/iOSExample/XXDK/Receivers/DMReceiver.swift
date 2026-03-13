//
//  DMReceiver.swift
//  iOSExample
//
//  Created by Om More on 24/09/25.
//

import Bindings
import SQLiteData
import SwiftData

class DMReceiverBuilder: NSObject, Bindings.BindingsDMReceiverBuilderProtocol {
    private var r: DMReceiver

    init(receiver: DMReceiver) {
        r = receiver
        super.init()
    }

    func build(_: String?) -> (any BindingsDMReceiverProtocol)? {
        return r
    }
}

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

class DMReceiver: NSObject, ObservableObject, Bindings.BindingsDMReceiverProtocol, Bindings
        .BindingsDmCallbacksProtocol
{
    func updateSentStatus(
        _ uuid: Int64, messageID: Data?, timestamp: Int64, roundID: Int64, status: Int64
    ) {
        let messageIDB64 = messageID?.base64EncodedString() ?? "nil"
        AppLogger.messaging.info(
            "func updateSentStatus(uuid: \(uuid, privacy: .public), messageID: \(messageIDB64, privacy: .public), timestamp: \(timestamp, privacy: .public), roundID: \(roundID, privacy: .public), status: \(status, privacy: .public))"
        )

        guard let parsedStatus = MessageStatus(rawValue: Int(status)) else {
            AppLogger.messaging.error(
                "updateSentStatus invalid status=\(status, privacy: .public) uuid=\(uuid, privacy: .public)"
            )
            return
        }

        do {
            try database.write { db in
                var message = try ChatMessageModel.where { $0.id.eq(uuid) }.fetchOne(db)
                if message == nil, let messageID {
                    let messageIDB64 = messageID.base64EncodedString()
                    message = try ChatMessageModel.where { $0.externalId.eq(messageIDB64) }
                        .fetchOne(db)
                }

                guard var message else { return }

                if parsedStatus == .failed {
                    try ChatMessageModel.delete(message).execute(db)
                } else {
                    message.status = parsedStatus
                    try ChatMessageModel.update(message).execute(db)
                }
            }
        } catch {
            AppLogger.messaging.error(
                "updateSentStatus db operation failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    func eventUpdate(_ eventType: Int64, jsonData: Data?) {
        guard let jsonData else {
            AppLogger.messaging.error(
                "DM event update payload is nil for eventType \(eventType, privacy: .public)"
            )
            return
        }

        do {
            switch eventType {
            case 1000:
                let parsed = try Parser.decode(DmNotificationUpdateJSON.self, from: jsonData)
                AppLogger.messaging.info(
                    "DM event parsed type=\(eventType, privacy: .public) payload=\(String(describing: parsed), privacy: .public)"
                )
            case 2000:
                let parsed = try Parser.decode(DmBlockedUserJSON.self, from: jsonData)
                AppLogger.messaging.info(
                    "DM event parsed type=\(eventType, privacy: .public) payload=\(String(describing: parsed), privacy: .public)"
                )
            case 3000:
                let parsed = try Parser.decode(DmMessageReceivedJSON.self, from: jsonData)
                AppLogger.messaging.info(
                    "DM event parsed type=\(eventType, privacy: .public) payload=\(String(describing: parsed), privacy: .public)"
                )
            case 4000:
                let parsed = try Parser.decode(DmMessageDeletedJSON.self, from: jsonData)
                AppLogger.messaging.info(
                    "DM event parsed type=\(eventType, privacy: .public) payload=\(String(describing: parsed), privacy: .public)"
                )
            default:
                AppLogger.messaging.debug(
                    "DM event update has unknown eventType \(eventType, privacy: .public)"
                )
            }
        } catch {
            AppLogger.messaging.error(
                "DM event update parse failed for eventType \(eventType, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    @Dependency(\.defaultDatabase) var database
    private let receiverHelpers = ReceiverHelpers()

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
        _ messageID: Data?, nickname: String?, text: Data?, partnerKey: Data?, senderKey: Data?,
        dmToken: Int32, codeset: Int, timestamp: Int64, roundId: Int64, mType: Int64,
        status: Int64
    ) -> Int64 {
        // Ensure UI updates happen on main thread
        let messageIDB64 = messageID?.base64EncodedString() ?? "nil"
        let textB64 = text?.base64EncodedString() ?? "nil"
        let partnerKeyB64 = partnerKey?.base64EncodedString() ?? "nil"
        let senderKeyB64 = senderKey?.base64EncodedString() ?? "nil"
        AppLogger.messaging.info(
            "func receive(messageID: \(messageIDB64, privacy: .public), nickname: \(nickname ?? "nil", privacy: .public), text: \(textB64, privacy: .public), partnerKey: \(partnerKeyB64, privacy: .public), senderKey: \(senderKeyB64, privacy: .public), dmToken: \(dmToken, privacy: .public), codeset: \(codeset, privacy: .public), timestamp: \(timestamp, privacy: .public), roundId: \(roundId, privacy: .public), mType: \(mType, privacy: .public), status: \(status, privacy: .public))"
        )

        guard let messageID else { fatalError("no msg id") }
        guard let text else { fatalError("no text") }
        guard let decodedMessage = decodeMessage(text.base64EncodedString()) else {
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

        let m = try! persistIncoming(
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
        guard let decodedReply = decodeMessage(replyTextB64) else {
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

        let m = try! persistIncoming(
            message: decodedReply, codename: codename, partnerKey: partnerKey,
            senderKey: senderKey, dmToken: dmToken, messageId: messageID, color: color,
            timestamp: timestamp, status: status
        )
        return m.id
    }

    func receiveText(
        _ messageID: Data?, nickname: String?, text: String?, partnerKey: Data?, senderKey: Data?,
        dmToken: Int32, codeset: Int, timestamp: Int64, roundId: Int64, status: Int64
    ) -> Int64 {
        // if roundId == 0 {
        //     return InternalIdGenerator.shared.next()
        // }
        let messageIDB64 = messageID?.base64EncodedString() ?? "nil"
        let partnerKeyB64 = partnerKey?.base64EncodedString() ?? "nil"
        let senderKeyB64 = senderKey?.base64EncodedString() ?? "nil"
        AppLogger.messaging.info(
            "func receiveText(messageID: \(messageIDB64, privacy: .public), nickname: \(nickname ?? "nil", privacy: .public), text: \(text ?? "nil", privacy: .public), partnerKey: \(partnerKeyB64, privacy: .public), senderKey: \(senderKeyB64, privacy: .public), dmToken: \(dmToken, privacy: .public), codeset: \(codeset, privacy: .public), timestamp: \(timestamp, privacy: .public), roundId: \(roundId, privacy: .public), status: \(status, privacy: .public))"
        )

        guard let messageID else { fatalError("no msg id") }
        let messageTextB64 = text ?? ""
        guard let decodedText = decodeMessage(messageTextB64) else {
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

        let m = try! persistIncoming(
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

        return try! receiverHelpers.persistIncomingMessage(
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
            let pubKeyB64 = pubKey.base64EncodedString()
            if let existingByKey = try database.read({ db in
                try ChatModel.where { $0.id.eq(pubKeyB64) }.fetchOne(db)
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
