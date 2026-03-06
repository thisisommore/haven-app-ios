import Bindings
import Dispatch
import Foundation

extension Notification.Name {
    static let userMuteStatusChanged = Notification.Name("userMuteStatusChanged")
}

final class ChannelEventModelBuilder: NSObject, BindingsEventModelBuilderProtocol {
    private var r: ChannelEventModel

    var chatStore: ChatStore?

    func configure(chatStore: ChatStore) {
        self.chatStore = chatStore
        r.configure(chatStore: chatStore)
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
    var chatStore: ChatStore?

    func configure(chatStore: ChatStore) {
        self.chatStore = chatStore
    }

    // MARK: - Helper Methods

    func update(
        fromMessageID messageID: Data?,
        messageUpdateInfoJSON: Data?,
        ret0_ _: UnsafeMutablePointer<Int64>?
    ) throws {
    }

    func update(fromUUID uuid: Int64, messageUpdateInfoJSON: Data?) throws {
        guard let messageUpdateInfoJSON else {
            return
        }

        let updateInfo = try Parser.decode(MessageUpdateInfoJSON.self, from: messageUpdateInfoJSON)

        guard let chatStore else {
            return
        }

        var newId: String? = nil
        var newStatus: Int64? = nil
        if updateInfo.MessageIDSet, let mid = updateInfo.MessageID {
            newId = mid
        }
        if updateInfo.StatusSet, let s = updateInfo.Status {
            newStatus = Int64(s)
        }

        if let updated = try chatStore.updateMessage(internalId: uuid, newId: newId, newStatusRaw: newStatus) {
            let updatedChatId = updated.chatId
            let updatedMessageId = updated.id
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
            guard let chatStore else {
                fatalError("no chatStore")
            }
            let chat = try chatStore.fetchOrCreateChannelChat(
                channelId: channelId,
                channelName: channelName
            )

            guard let messageIdB64 = messageIdB64, !messageIdB64.isEmpty else {
                fatalError("no message id")
            }

            let msg = try ReceiverHelpers.persistIncomingMessage(
                store: chatStore,
                chatId: chat.id,
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

        do {
            let (codename, color) = try ReceiverHelpers.parseIdentity(pubKey: pubKey, codeset: codeset)
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
        guard let reactionMessageId = messageID?.base64EncodedString(), !reactionMessageId.isEmpty else {
            fatalError("no reaction message id")
        }

        do {
            guard let chatStore else {
                fatalError("no chatStore")
            }

            let (codename, color) = try ReceiverHelpers.parseIdentity(pubKey: pubKey, codeset: codeset)

            var senderId: String? = nil
            if let pubKey {
                let sender = try ReceiverHelpers.upsertSender(
                    store: chatStore,
                    pubKey: pubKey,
                    codename: codename,
                    nickname: nickname,
                    dmToken: dmToken,
                    color: color
                )
                senderId = sender.id
            }

            let internalId = InternalIdGenerator.shared.next()
            let record = try chatStore.deduplicateAndUpsertReaction(
                reactionMessageId: reactionMessageId,
                targetMessageId: targetId,
                emoji: reactionText,
                senderId: senderId,
                internalId: internalId
            )

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
            guard let chatStore else {
                return
            }
            try chatStore.deleteReaction(messageId: messageId, emoji: emoji)
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

    func getMessage(_ messageID: Data?) throws -> Data {
        guard let messageID else {
            throw EventModelError.messageNotFound
        }

        let messageIdB64 = messageID.base64EncodedString()

        guard let chatStore else {
            throw EventModelError.modelActorNotAvailable
        }

        if let msg = try chatStore.fetchMessage(id: messageIdB64) {
            let pubKeyData: Data
            if let senderId = msg.senderId, let sender = try? chatStore.fetchSender(id: senderId) {
                pubKeyData = sender.pubkey
            } else {
                pubKeyData = Data()
            }
            let modelMsg = ModelMessageJSON(
                pubKey: pubKeyData,
                messageID: messageID
            )
            return try Parser.encode(modelMsg)
        }

        if let reaction = try? chatStore.fetchReactions(targetMessageIds: [messageIdB64])[messageIdB64]?.first(where: { $0.id == messageIdB64 }) {
            let pubKeyData: Data
            if let senderId = reaction.senderId, let sender = try? chatStore.fetchSender(id: senderId) {
                pubKeyData = sender.pubkey
            } else {
                pubKeyData = Data()
            }
            let modelMsg = ModelMessageJSON(
                pubKey: pubKeyData,
                messageID: messageID
            )
            return try Parser.encode(modelMsg)
        }

        throw EventModelError.messageNotFound
    }

    func deleteMessage(_ messageID: Data?) throws {
        guard let messageID else {
            fatalError("message id is nil")
        }

        let messageIdB64 = messageID.base64EncodedString()

        guard let chatStore else {
            fatalError("deleteMessage: no chatStore available")
        }

        do {
            if let _ = try chatStore.fetchMessage(id: messageIdB64) {
                try chatStore.deleteMessage(id: messageIdB64)
                return
            }
            try chatStore.deleteReaction(id: messageIdB64)
        } catch {
            AppLogger.storage.error("EventModel: Failed to delete message/reaction: \(error.localizedDescription, privacy: .public)")
        }
    }

    func muteUser(_ channelID: Data?, pubkey _: Data?, unmute _: Bool) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .userMuteStatusChanged,
                object: nil,
                userInfo: ["channelID": channelID?.base64EncodedString() ?? ""]
            )
        }
    }
}
