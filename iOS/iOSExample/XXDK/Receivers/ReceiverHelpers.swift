//
//  ReceiverHelpers.swift
//  iOSExample
//
//  Common utilities shared between DMReceiver and EventModel
//

import Bindings
import Foundation

enum ReceiverHelpers {
    private static var cachedSelfChatId: Data?

    private static func postChatMessageUpdate(chatId: String) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .chatMessagesUpdated,
                object: nil,
                userInfo: ["chatId": chatId]
            )
        }
    }

    /// Parse identity from pubKey and codeset, returning codename and color
    static func parseIdentity(pubKey: Data?, codeset: Int) throws -> (codename: String, color: Int) {
        guard let identity = try BindingsStatic.constructIdentity(pubKey: pubKey, codeset: codeset) else {
            throw EventModelError.identityConstructionFailed
        }
        var colorStr = identity.Color
        if colorStr.hasPrefix("0x") || colorStr.hasPrefix("0X") {
            colorStr.removeFirst(2)
        }
        return (identity.Codename, Int(colorStr, radix: 16) ?? 0)
    }

    /// Check if sender's pubKey matches the "<self>" chat pubKey
    static func isSenderSelf(senderPubKey: Data?, store: ChatStore) -> Bool {
        guard let senderPubKey else { return false }

        if cachedSelfChatId == nil {
            if let allChats = try? store.fetchAllChats(),
               let selfChat = allChats.first(where: { $0.name == "<self>" })
            {
                cachedSelfChatId = Data(base64Encoded: selfChat.id)
            }
        }

        if let selfId = cachedSelfChatId {
            return selfId == senderPubKey
        }
        return false
    }

    /// Clear cached self chat ID (call after user switches)
    static func clearSelfChatCache() {
        cachedSelfChatId = nil
    }

    /// Fetch or create a sender, updating dmToken and nickname if exists
    static func upsertSender(
        store: ChatStore,
        pubKey: Data,
        codename: String,
        nickname: String? = nil,
        dmToken: Int32,
        color: Int
    ) throws -> MessageSenderModel {
        try store.upsertSender(
            pubKey: pubKey,
            codename: codename,
            nickname: nickname,
            dmToken: dmToken,
            color: color
        )
    }

    /// Insert a new text message
    static func insertMessage(
        store: ChatStore,
        chatId: String,
        senderId: String?,
        text: String,
        messageId: String,
        internalId: Int64,
        senderPubKey: Data?,
        replyTo: String? = nil,
        timestamp: Int64? = nil
    ) throws -> ChatMessageModel {
        let isIncoming = !isSenderSelf(senderPubKey: senderPubKey, store: store)

        let msg: ChatMessageModel
        if let timestamp {
            msg = ChatMessageModel(
                message: text,
                isIncoming: isIncoming,
                chatId: chatId,
                senderId: senderId,
                id: messageId,
                internalId: internalId,
                replyTo: replyTo,
                timestamp: timestamp
            )
        } else {
            msg = ChatMessageModel(
                message: text,
                isIncoming: isIncoming,
                chatId: chatId,
                senderId: senderId,
                id: messageId,
                internalId: internalId,
                replyTo: replyTo
            )
        }

        try store.insertMessageAndBumpUnread(msg)
        postChatMessageUpdate(chatId: chatId)
        return msg
    }

    /// Persist an incoming message: upserts sender and inserts message
    static func persistIncomingMessage(
        store: ChatStore,
        chatId: String,
        text: String,
        messageId: String,
        senderPubKey: Data?,
        senderCodename: String?,
        nickname: String? = nil,
        dmToken: Int32,
        color: Int,
        replyTo: String? = nil,
        timestamp: Int64? = nil
    ) throws -> ChatMessageModel {
        var senderId: String? = nil
        if let senderCodename, let senderPubKey {
            let sender = try upsertSender(
                store: store,
                pubKey: senderPubKey,
                codename: senderCodename,
                nickname: nickname,
                dmToken: dmToken,
                color: color
            )
            senderId = sender.id
        }

        let internalId = InternalIdGenerator.shared.next()
        return try insertMessage(
            store: store,
            chatId: chatId,
            senderId: senderId,
            text: text,
            messageId: messageId,
            internalId: internalId,
            senderPubKey: senderPubKey,
            replyTo: replyTo,
            timestamp: timestamp
        )
    }
}
