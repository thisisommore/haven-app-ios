import Bindings
import Dispatch
import Foundation
import SwiftData

extension Notification.Name {
    static let userMuteStatusChanged = Notification.Name("userMuteStatusChanged")
}

final class ChannelEventModelBuilder: NSObject, BindingsEventModelBuilderProtocol {
    private var r: ChannelEventModel

    var modelActor: SwiftDataActor?

    // Allow late injection from the app so the EventModel can persist messages
    func configure(modelActor: SwiftDataActor) {
        self.modelActor = modelActor
        // Propagate immediately to the underlying model if already created
        r.configure(modelActor: modelActor)
    }

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

    var modelActor: SwiftDataActor?

    func configure(modelActor: SwiftDataActor) {
        self.modelActor = modelActor
    }

    // MARK: - Helper Methods

    func update(
        fromMessageID messageID: Data?,
        messageUpdateInfoJSON: Data?,
        ret0_ _: UnsafeMutablePointer<Int64>?
    ) throws {
        let msgIdB64 = messageID?.base64EncodedString()
        let jsonString = messageUpdateInfoJSON.flatMap { String(data: $0, encoding: .utf8) } ?? "nil"
        AppLogger.messaging.debug("DEL update(fromMessageID) messageID: \(msgIdB64 ?? "nil", privacy: .public) json: \(jsonString, privacy: .public)")
    }

    func update(fromUUID uuid: Int64, messageUpdateInfoJSON: Data?) throws {
        guard let messageUpdateInfoJSON else {
            return
        }

        let jsonString = String(data: messageUpdateInfoJSON, encoding: .utf8) ?? "nil"
        let updateInfo = try Parser.decode(MessageUpdateInfoJSON.self, from: messageUpdateInfoJSON)

        AppLogger.messaging.debug("DEL update(fromUUID) uuid: \(uuid, privacy: .public) json: \(jsonString, privacy: .public)")

        guard let modelActor else {
            return
        }

        let descriptor = FetchDescriptor<ChatMessageModel>(
            predicate: #Predicate { $0.internalId == uuid }
        )

        if let message = try modelActor.fetch(descriptor).first {
            if updateInfo.MessageIDSet, let newMessageId = updateInfo.MessageID {
                message.id = newMessageId
            }
            if updateInfo.StatusSet, let newStatus = updateInfo.Status {
                message.statusRaw = Int64(newStatus)
            }
            try modelActor.save()
            let updatedChatId = message.chat.id
            let updatedMessageId = message.id
            let hasStatusUpdate = updateInfo.StatusSet && updateInfo.Status != nil
            DispatchQueue.main.async {
                var userInfo: [String: Any] = [
                    "chatId": updatedChatId,
                    "messageId": updatedMessageId,
                    "messageInternalId": uuid,
                ]
                if hasStatusUpdate {
                    userInfo["updateKind"] = "status"
                }
                NotificationCenter.default.post(
                    name: .chatMessagesUpdated,
                    object: nil,
                    userInfo: userInfo
                )
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
        guard let modelActor else {
            throw EventModelError.modelActorNotAvailable
        }
        let descriptor = FetchDescriptor<ChatModel>(
            predicate: #Predicate { $0.id == channelId }
        )
        if let existing = try modelActor.fetch(descriptor).first {
            return existing
        }
        let newChat = ChatModel(channelId: channelId, name: channelName)
        modelActor.insert(newChat)
        try modelActor.save()
        return newChat
    }

    // Persist a message into SwiftData if modelActor is set
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
        do {
            guard let modelActor else {
                fatalError("no modelActor")
            }
            let chat = try fetchOrCreateChannelChat(
                channelId: channelId,
                channelName: channelName
            )

            guard let messageIdB64 = messageIdB64, !messageIdB64.isEmpty else {
                fatalError("no message id")
            }

            let msg = try ReceiverHelpers.persistIncomingMessage(
                ctx: modelActor,
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
            AppLogger.storage.critical("persist msg error: \(error.localizedDescription, privacy: .public)")
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
        status: Int64,
        hidden _: Bool
    ) -> Int64 {
        let messageIdB64 = messageID?.base64EncodedString()
        let messageTextB64 = text ?? ""
        let statusString = MessageStatus(rawValue: status)?.name ?? "unknown"

        do {
            let (codename, color) = try ReceiverHelpers.parseIdentity(pubKey: pubKey, codeset: codeset)
            let channelIdB64 = channelID?.base64EncodedString() ?? "unknown"
            if let decodedText = decodeMessage(messageTextB64) {
                AppLogger.messaging.debug("DEL received messageID: \(messageIdB64 ?? "nil", privacy: .public) text: \(decodedText, privacy: .public) status: \(statusString, privacy: .public)")
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
        guard let reactionMessageId = messageID?.base64EncodedString(), !reactionMessageId.isEmpty else {
            fatalError("no reaction message id")
        }

        do {
            guard let modelActor else {
                fatalError("no modelActor")
            }

            let (codename, color) = try ReceiverHelpers.parseIdentity(pubKey: pubKey, codeset: codeset)

            var sender: MessageSenderModel? = nil
            if let pubKey {
                sender = try ReceiverHelpers.upsertSender(
                    ctx: modelActor,
                    pubKey: pubKey,
                    codename: codename,
                    nickname: nickname,
                    dmToken: dmToken,
                    color: color
                )
            }

            // De-duplicate by message target + emoji + sender.
            // If a duplicate exists, update its id instead of creating another row.
            let duplicateDescriptor = FetchDescriptor<MessageReactionModel>(
                predicate: #Predicate { reaction in
                    reaction.targetMessageId == targetId && reaction.emoji == reactionText
                }
            )
            let duplicateCandidates = try modelActor.fetch(duplicateDescriptor)
            let senderId = sender?.id
            let sameSenderReactions = duplicateCandidates.filter { reaction in
                reaction.sender?.id == senderId
            }

            let record: MessageReactionModel
            if let canonical = sameSenderReactions.first(where: { $0.id == reactionMessageId }) ?? sameSenderReactions.first {
                if canonical.id != reactionMessageId {
                    canonical.id = reactionMessageId
                }
                if canonical.sender == nil, let sender {
                    canonical.sender = sender
                }
                // If duplicates already exist, keep one canonical row.
                for duplicate in sameSenderReactions where duplicate !== canonical {
                    modelActor.delete(duplicate)
                }
                record = canonical
            } else {
                let internalId = InternalIdGenerator.shared.next()
                let newRecord = MessageReactionModel(
                    id: reactionMessageId,
                    internalId: internalId,
                    targetMessageId: targetId,
                    emoji: reactionText,
                    sender: sender
                )
                modelActor.insert(newRecord)
                record = newRecord
            }

            try modelActor.save()
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
            guard let modelActor else {
                return
            }
            let descriptor = FetchDescriptor<MessageReactionModel>(
                predicate: #Predicate {
                    $0.id == messageId && $0.emoji == emoji
                }
            )
            let reactions = try modelActor.fetch(descriptor)

            for reaction in reactions {
                modelActor.delete(reaction)
            }

            try modelActor.save()
        } catch {
            AppLogger.storage.error("EventModel: Failed to delete reaction: \(error.localizedDescription, privacy: .public)")
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

    func updateFromMessageID(
        messageID: Data?,
        messageUpdateInfoJSON: Data?,
        ret0_ _: UnsafeMutablePointer<Int64>?
    ) throws -> Bool {
        let msgIdB64 = messageID?.base64EncodedString()
        let jsonString = messageUpdateInfoJSON.flatMap { String(data: $0, encoding: .utf8) } ?? "nil"
        AppLogger.messaging.debug("DEL updateFromMessageID messageID: \(msgIdB64 ?? "nil", privacy: .public) json: \(jsonString, privacy: .public)")
        return true
    }

    func updateFromUUID(_ uuid: Int64, messageUpdateInfoJSON: Data?) throws
        -> Bool
    {
        guard let messageUpdateInfoJSON else {
            return false
        }

        let jsonString = String(data: messageUpdateInfoJSON, encoding: .utf8) ?? "nil"

        let updateInfo = try Parser.decode(MessageUpdateInfoJSON.self, from: messageUpdateInfoJSON)
        let hasMessageIdUpdate = updateInfo.MessageIDSet && updateInfo.MessageID != nil
        let hasStatusUpdate = updateInfo.StatusSet && updateInfo.Status != nil
        guard hasMessageIdUpdate || hasStatusUpdate else {
            return false
        }
        let newMessageIdLog = updateInfo.MessageID ?? "nil"
        AppLogger.messaging.debug("DEL updateFromUUID uuid: \(uuid, privacy: .public) newMessageID: \(newMessageIdLog, privacy: .public) json: \(jsonString, privacy: .public)")

        guard let modelActor else {
            return false
        }

        let descriptor = FetchDescriptor<ChatMessageModel>(
            predicate: #Predicate { $0.internalId == uuid }
        )

        if let message = try modelActor.fetch(descriptor).first {
            if let newMessageId = updateInfo.MessageID {
                message.id = newMessageId
            }
            if let newStatus = updateInfo.Status {
                message.statusRaw = Int64(newStatus)
            }
            try modelActor.save()
            let updatedChatId = message.chat.id
            let updatedMessageId = message.id
            DispatchQueue.main.async {
                var userInfo: [String: Any] = [
                    "chatId": updatedChatId,
                    "messageId": updatedMessageId,
                    "messageInternalId": uuid,
                ]
                if hasStatusUpdate {
                    userInfo["updateKind"] = "status"
                }
                NotificationCenter.default.post(
                    name: .chatMessagesUpdated,
                    object: nil,
                    userInfo: userInfo
                )
            }
            return true
        }

        return false
    }

    func getMessage(_ messageID: Data?) throws -> Data {
        guard let messageID else {
            throw EventModelError.messageNotFound
        }

        let messageIdB64 = messageID.base64EncodedString()

        guard let modelActor else {
            throw EventModelError.modelActorNotAvailable
        }

        // Check ChatMessage
        let msgDescriptor = FetchDescriptor<ChatMessageModel>(
            predicate: #Predicate { $0.id == messageIdB64 }
        )
        if let msg = try? modelActor.fetch(msgDescriptor).first {
            let pubKeyData = msg.sender?.pubkey ?? Data()
            let modelMsg = ModelMessageJSON(
                pubKey: pubKeyData,
                messageID: messageID
            )
            return try Parser.encode(modelMsg)
        }

        // Check MessageReaction - if message not found, check if it's a reaction
        let reactionDescriptor = FetchDescriptor<MessageReactionModel>(
            predicate: #Predicate { $0.id == messageIdB64 }
        )
        if let reaction = try? modelActor.fetch(reactionDescriptor).first {
            let pubKeyData = reaction.sender?.pubkey ?? Data()
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

        guard let modelActor else {
            fatalError("deleteMessage: no modelActor available")
        }

        do {
            // First, try to find and delete a ChatMessage
            let messageDescriptor = FetchDescriptor<ChatMessageModel>(
                predicate: #Predicate { $0.id == messageIdB64 }
            )
            let messages = try modelActor.fetch(messageDescriptor)

            if !messages.isEmpty {
                for message in messages {
                    modelActor.delete(message)
                }
                try modelActor.save()
                return
            }

            // If no message found, check for reactions
            let reactionDescriptor = FetchDescriptor<MessageReactionModel>(
                predicate: #Predicate { $0.id == messageIdB64 }
            )
            let reactions = try modelActor.fetch(reactionDescriptor)

            if !reactions.isEmpty {
                for reaction in reactions {
                    modelActor.delete(reaction)
                }
                try modelActor.save()
                return
            }

        } catch {
            AppLogger.storage.error("EventModel: Failed to delete message/reaction: \(error.localizedDescription, privacy: .public)")
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
