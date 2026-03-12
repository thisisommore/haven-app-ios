//
//  ReceiverHelpers.swift
//  iOSExample
//
//  Common utilities shared between DMReceiver and EventModel
//

import Bindings
import Foundation
import SQLiteData
import SwiftData

class ReceiverHelpers {
    @Dependency(\.defaultDatabase) var database

    private static var cachedSelfChatId: Data?

    private func postChatMessageUpdate(chatId: String) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .chatMessagesUpdated,
                object: nil,
                userInfo: ["chatId": chatId]
            )
        }
    }

    /// Parse identity from pubKey and codeset, returning codename and color
    static func parseIdentity(pubKey: Data?, codeset: Int) throws -> (codename: String, color: Int)
    {
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
                Self.cachedSelfChatId = Data(base64Encoded: selfChat.id)
            }
        }

        if let selfId = Self.cachedSelfChatId {
            return selfId == senderPubKey
        }
        return false
    }

    /// Clear cached self chat ID (call after user switches)
    static func clearSelfChatCache() {
        cachedSelfChatId = nil
    }

    /// Fetch or create a sender, updating dmToken and nickname if exists
    func upsertSender(
        pubKey: Data,
        codename: String,
        nickname: String? = nil,
        dmToken: Int32,
        color: Int
    ) throws -> MessageSenderModel {
        let senderId = pubKey.base64EncodedString()

        if let existing = try database.read({ db in
            try MessageSenderModel.where { $0.id.eq(senderId) }.fetchOne(db)
        }) {
            var updated = existing
            updated.dmToken = dmToken
            if let nickname, !nickname.isEmpty {
                updated.nickname = nickname
            }
            try database.write { db in
                try MessageSenderModel.update(updated).execute(db)
            }
            return updated
        }

        let sender = MessageSenderModel(
            id: senderId,
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
        internalId: Int64,
        senderPubKey: Data?,
        replyTo: String? = nil,
        timestamp: Int64? = nil
    ) throws -> ChatMessageModel {
        let isIncoming = !isSenderSelf(senderPubKey: senderPubKey)

        var msg: ChatMessageModel
        if let timestamp {
            msg = ChatMessageModel(
                message: text,
                isIncoming: isIncoming,
                chatId: chat.id,
                senderId: sender?.id,
                id: messageId,
                internalId: internalId,
                replyTo: replyTo,
                timestamp: timestamp
            )
        } else {
            msg = ChatMessageModel(
                message: text,
                isIncoming: isIncoming,
                chatId: chat.id,
                senderId: sender?.id,
                id: messageId,
                internalId: internalId,
                replyTo: replyTo
            )
        }

        let precomputedRender = NewMessageHTMLPrecomputer.precompute(rawHTML: text)
        msg.newContainsMarkup = precomputedRender.containsMarkup
        msg.newRenderKind = precomputedRender.kind
        msg.newRenderVersion = Int(precomputedRender.version)
        msg.newRenderPlainText = precomputedRender.plainText
        msg.newRenderPayload = precomputedRender.payloadData
        try database.write { db in
            try ChatMessageModel.update(msg).execute(db)
        }

        try database.write { db in
            try ChatMessageModel.insert { msg }.execute(db)

            if isIncoming && msg.timestamp > chat.joinedAt {
                var updatedChat = chat
                updatedChat.unreadCount += 1
                try ChatModel.update(updatedChat).execute(db)
            }
        }

        postChatMessageUpdate(chatId: chat.id)
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
        timestamp: Int64? = nil
    ) throws -> ChatMessageModel {
        var sender: MessageSenderModel? = nil
        if let senderCodename, let senderPubKey {
            sender = try upsertSender(
                pubKey: senderPubKey,
                codename: senderCodename,
                nickname: nickname,
                dmToken: dmToken,
                color: color
            )
        }

        let internalId = InternalIdGenerator.shared.next()
        return try insertMessage(
            chat: chat,
            sender: sender,
            text: text,
            messageId: messageId,
            internalId: internalId,
            senderPubKey: senderPubKey,
            replyTo: replyTo,
            timestamp: timestamp
        )
    }
}
