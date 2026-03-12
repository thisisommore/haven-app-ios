import Bindings
import Dispatch
import Foundation
import SQLiteData
import SwiftData

extension Notification.Name {
    static let userMuteStatusChanged = Notification.Name("userMuteStatusChanged")
}

final class ChannelEventModelBuilder: NSObject, BindingsEventModelBuilderProtocol {
    private var r: ChannelEventModel

    init(model: ChannelEventModel) {
        r = model
        super.init()
    }

    func build(_: String?) -> (any BindingsEventModelProtocol)? {
        return r
    }
}

final class ChannelEventModel: NSObject, BindingsEventModelProtocol {
    // Optional SwiftData container for persisting chats/messages
    @Dependency(\.defaultDatabase) var database
    private let receiverHelpers = ReceiverHelpers()

    // MARK: - Helper Methods

    func update(
        fromMessageID _: Data?,
        messageUpdateInfoJSON _: Data?,
        ret0_ _: UnsafeMutablePointer<Int64>?
    ) throws {}

    func update(fromUUID uuid: Int64, messageUpdateInfoJSON: Data?) throws {
        guard let messageUpdateInfoJSON else {
            return
        }

        let updateInfo = try Parser.decode(MessageUpdateInfoJSON.self, from: messageUpdateInfoJSON)
        var message = try database.read {
            db in
            try ChatMessageModel.where { $0.internalId.eq(uuid) }.fetchOne(db)
        }
        if var message {
            if updateInfo.MessageIDSet, let newMessageId = updateInfo.MessageID {
                message.id = newMessageId
            }
            if updateInfo.StatusSet, let newStatusRaw = updateInfo.Status,
                let newStatus = MessageStatus(rawValue: newStatusRaw)
            {
                message.status = newStatus
            }
            try database.write { db in
                try ChatMessageModel.update(message).execute(db)
            }
        }
    }

    private func short(_ data: Data?) -> String {
        guard let data else { return "nil" }
        let b64 = data.base64EncodedString()
        return b64.count > 16 ? String(b64.prefix(16)) + "…" : b64
    }

    // Fetch existing Chat by channelId or create a new one
    private func fetchOrCreateChannelChat(
        channelId: String,
        channelName: String
    ) throws -> ChatModel {
        let existing = try database.read { db in
            try ChatModel.where { $0.id.eq(channelId) }.fetchOne(db)
        }

        if let existing {
            return existing
        }
        let newChat = ChatModel(channelId: channelId, name: channelName)
        try database.write {
            db in
            try ChatModel.insert { newChat }.execute(db)
        }
        return newChat
    }

    // Persist a message into SwiftData
    private func persistMessage(
        channelId: String,
        channelName: String,
        text: String,
        senderCodename: String?,
        senderPubKey: Data?,
        messageIdB64: String? = nil,
        replyTo: String? = nil,
        timestamp: Int64,
        dmToken: Int32? = nil,
        color: Int,
        nickname: String? = nil
    ) -> Int64 {
        print(
            "PM: channelId=\(channelId) channelName=\(channelName) text=\(text) senderCodename=\(senderCodename ?? "nil") senderPubKey=\(short(senderPubKey)) messageIdB64=\(messageIdB64 ?? "nil") replyTo=\(replyTo ?? "nil") timestamp=\(timestamp) dmToken=\(dmToken.map { String($0) } ?? "nil") color=\(color) nickname=\(nickname ?? "nil")"
        )
        do {
            let chat = try fetchOrCreateChannelChat(
                channelId: channelId,
                channelName: channelName
            )

            guard let messageIdB64 = messageIdB64, !messageIdB64.isEmpty else {
                fatalError("no message id")
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
                timestamp: timestamp
            )

            return msg.internalId
        } catch {
            AppLogger.storage.critical(
                "persist msg error: \(error.localizedDescription, privacy: .public)")
            fatalError(
                error.localizedDescription
            )
        }
    }

    func joinChannel(_: String?) {}

    func leaveChannel(_: Data?) {}

    func receiveMessage(
        _ channelID: Data?,
        messageID: Data?,
        nickname: String?,
        text: String?,
        pubKey: Data?,
        dmToken: Int32,
        codeset: Int,
        timestamp: Int64,
        lease _: Int64,
        roundID _: Int64,
        messageType _: Int64,
        status _: Int64,
        hidden _: Bool
    ) -> Int64 {
        let messageIdB64 = messageID?.base64EncodedString()
        let messageTextB64 = text ?? ""

        do {
            let (codename, color) = try ReceiverHelpers.parseIdentity(
                pubKey: pubKey, codeset: codeset
            )
            let channelIdB64 = channelID?.base64EncodedString() ?? "unknown"
            if let decodedText = decodeMessage(messageTextB64) {
                return persistMessage(
                    channelId: channelIdB64,
                    channelName: "Channel \(String(channelIdB64.prefix(8)))",
                    text: decodedText,
                    senderCodename: codename,
                    senderPubKey: pubKey,
                    messageIdB64: messageIdB64,
                    timestamp: timestamp,
                    dmToken: dmToken,
                    color: color,
                    nickname: nickname
                )
            }
            return 0
        } catch {
            fatalError("something went wrong \(error)")
        }
    }

    func receiveReaction(
        _ channelID: Data?,
        messageID: Data?,
        reactionTo: Data?,
        nickname: String?,
        reaction: String?,
        pubKey: Data?,
        dmToken: Int32,
        codeset: Int,
        timestamp _: Int64,
        lease _: Int64,
        roundID _: Int64,
        messageType _: Int64,
        status _: Int64,
        hidden _: Bool
    ) -> Int64 {
        let reactionText = reaction ?? ""
        let targetMessageIdB64 = reactionTo?.base64EncodedString()

        guard let targetId = targetMessageIdB64, !targetId.isEmpty else {
            fatalError("no target id")
        }
        guard !reactionText.isEmpty else {
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

            var sender: MessageSenderModel? = nil
            if let pubKey {
                sender = try receiverHelpers.upsertSender(
                    pubKey: pubKey,
                    codename: codename,
                    nickname: nickname,
                    dmToken: dmToken,
                    color: color
                )
            }

            // De-duplicate by message target + emoji + sender.
            // If a duplicate exists, update its id instead of creating another row.
            let sameSenderReactions = try database.read { db in
                try MessageReactionModel.where {
                    $0.targetMessageId.eq(targetId) && $0.emoji.eq(reactionText)
                        && $0.senderId.eq(sender?.id)
                }.fetchAll(db)
            }

            let record: MessageReactionModel
            if var canonical = sameSenderReactions.first(where: { $0.id == reactionMessageId })
                ?? sameSenderReactions.first
            {
                if canonical.id != reactionMessageId {
                    canonical.id = reactionMessageId
                }
                if canonical.senderId == nil, let sender {
                    canonical.senderId = sender.id
                }
                // If duplicates already exist, keep one canonical row.
                for duplicate in sameSenderReactions where duplicate.id != canonical.id {
                    try database.write { db in
                        try MessageReactionModel.delete(duplicate).execute(db)
                    }
                }
                record = canonical
            } else {
                let internalId = InternalIdGenerator.shared.next()
                let newRecord = MessageReactionModel(
                    id: reactionMessageId,
                    internalId: internalId,
                    targetMessageId: targetId,
                    emoji: reactionText,
                    senderId: sender?.id
                )
                try database.write { db in
                    try MessageReactionModel.insert { newRecord }.execute(db)
                }
                record = newRecord
            }

            if let channelID {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .chatMessagesUpdated,
                        object: nil,
                        userInfo: ["chatId": channelID.base64EncodedString()]
                    )
                }
            }
            return record.internalId
        } catch {
            fatalError(
                "failed to store message reaction \(error.localizedDescription)"
            )
        }
    }

    func deleteReaction(messageId: String, emoji: String) {
        do {
            let reactions = try database.read { db in
                try MessageReactionModel.where {
                    $0.id.eq(messageId) && $0.emoji.eq(emoji)
                }.fetchAll(db)
            }

            for reaction in reactions {
                try database.write { db in
                    try MessageReactionModel.delete(reaction).execute(db)
                }
            }
        } catch {
            AppLogger.storage.error(
                "EventModel: Failed to delete reaction: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    func receiveReply(
        _ channelID: Data?,
        messageID: Data?,
        reactionTo: Data?,
        nickname: String?,
        text: String?,
        pubKey: Data?,
        dmToken: Int32,
        codeset: Int,
        timestamp: Int64,
        lease _: Int64,
        roundID _: Int64,
        messageType _: Int64,
        status _: Int64,
        hidden _: Bool
    ) -> Int64 {
        let messageIdB64 = messageID?.base64EncodedString()
        let replyTextB64 = text ?? ""

        let nick: String
        let color: Int
        do {
            (nick, color) = try ReceiverHelpers.parseIdentity(pubKey: pubKey, codeset: codeset)
        } catch {
            fatalError("\(error)")
        }
        let channelIdB64 = channelID?.base64EncodedString() ?? "unknown"
        guard let reactionTo else {
            fatalError("reactionTo is missing")
        }
        if let decodedReply = decodeMessage(replyTextB64) {
            return persistMessage(
                channelId: channelIdB64,
                channelName: "Channel \(String(channelIdB64.prefix(8)))",
                text: decodedReply,
                senderCodename: nick,
                senderPubKey: pubKey,
                messageIdB64: messageIdB64,
                replyTo: reactionTo.base64EncodedString(),
                timestamp: timestamp,
                dmToken: dmToken, color: color,
                nickname: nickname
            )
        }
        return 0
    }

    func getMessage(_ messageID: Data?) throws -> Data {
        guard let messageID else {
            throw EventModelError.messageNotFound
        }

        let messageIdB64 = messageID.base64EncodedString()

        if let sender = try? database.read({ db in
            try ChatMessageModel
                .where { $0.id.eq(messageIdB64) }
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
                .where { $0.id.eq(messageIdB64) }
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
        guard let messageID else {
            fatalError("message id is nil")
        }

        let messageIdB64 = messageID.base64EncodedString()

        do {
            // First, try to find and delete a ChatMessage
            let messages = try database.read { db in
                try ChatMessageModel.where { $0.id.eq(messageIdB64) }.fetchAll(db)
            }

            if !messages.isEmpty {
                for message in messages {
                    try database.write { db in
                        try ChatMessageModel.delete(message).execute(db)
                    }
                }
                return
            }

            // If no message found, check for reactions
            let reactions = try database.read { db in
                try MessageReactionModel.where { $0.id.eq(messageIdB64) }.fetchAll(db)
            }

            if !reactions.isEmpty {
                for reaction in reactions {
                    try database.write { db in
                        try MessageReactionModel.delete(reaction).execute(db)
                    }
                }
                return
            }

        } catch {
            AppLogger.storage.error(
                "EventModel: Failed to delete message/reaction: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    func muteUser(_ channelID: Data?, pubkey _: Data?, unmute _: Bool) {
        // Post notification for UI to refresh mute status
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .userMuteStatusChanged,
                object: nil,
                userInfo: ["channelID": channelID?.base64EncodedString() ?? ""]
            )
        }
    }
}
