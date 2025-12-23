//
//  ReceiverHelpers.swift
//  iOSExample
//
//  Common utilities shared between DMReceiver and EventModel
//

import Bindings
import SwiftData

enum ReceiverHelpers {
    /// Parse identity from pubKey and codeset, returning codename and color
    static func parseIdentity(pubKey: Data?, codeset: Int) throws -> (codename: String, color: Int) {
        var err: NSError?
        guard let identityData = Bindings.BindingsConstructIdentity(pubKey, codeset, &err) else {
            throw err ?? EventModelError.identityConstructionFailed
        }
        let identity = try Parser.decodeIdentity(from: identityData)
        var colorStr = identity.color
        if colorStr.hasPrefix("0x") || colorStr.hasPrefix("0X") {
            colorStr.removeFirst(2)
        }
        return (identity.codename, Int(colorStr, radix: 16) ?? 0)
    }

    /// Check if sender's pubKey matches the "<self>" chat pubKey
    static func isSenderSelf(senderPubKey: Data?, ctx: SwiftDataActor) -> Bool {
        let selfChatDescriptor = FetchDescriptor<ChatModel>(predicate: #Predicate { $0.name == "<self>" })
        if let selfChat = try? ctx.fetch(selfChatDescriptor).first {
            guard let senderPubKey = senderPubKey else { return false }
            return Data(base64Encoded: selfChat.id) == senderPubKey
        }
        return false
    }

    /// Fetch or create a sender, updating dmToken and nickname if exists
    static func upsertSender(
        ctx: SwiftDataActor,
        pubKey: Data,
        codename: String,
        nickname: String? = nil,
        dmToken: Int32,
        color: Int
    ) throws -> MessageSenderModel {
        let senderId = pubKey.base64EncodedString()
        let descriptor = FetchDescriptor<MessageSenderModel>(predicate: #Predicate { $0.id == senderId })

        if let existing = try ctx.fetch(descriptor).first {
            existing.dmToken = dmToken
            if let nickname = nickname, !nickname.isEmpty {
                existing.nickname = nickname
            }
            try ctx.save()
            return existing
        }

        let sender = MessageSenderModel(
            id: senderId,
            pubkey: pubKey,
            codename: codename,
            nickname: nickname,
            dmToken: dmToken,
            color: color
        )
        ctx.insert(sender)
        try ctx.save()
        return sender
    }

    /// Insert a new text message
    static func insertMessage(
        ctx: SwiftDataActor,
        chat: ChatModel,
        sender: MessageSenderModel?,
        text: String,
        messageId: String,
        internalId: Int64,
        senderPubKey: Data?,
        replyTo: String? = nil,
        timestamp: Int64? = nil
    ) throws -> ChatMessageModel {
        let isIncoming = !isSenderSelf(senderPubKey: senderPubKey, ctx: ctx)

        let msg: ChatMessageModel
        if let ts = timestamp {
            msg = ChatMessageModel(
                message: text,
                isIncoming: isIncoming,
                chat: chat,
                sender: sender,
                id: messageId,
                internalId: internalId,
                replyTo: replyTo,
                timestamp: ts
            )
        } else {
            msg = ChatMessageModel(
                message: text,
                isIncoming: isIncoming,
                chat: chat,
                sender: sender,
                id: messageId,
                internalId: internalId,
                replyTo: replyTo
            )
        }

        ctx.insert(msg)
        chat.messages.append(msg)

        if isIncoming && msg.timestamp > chat.joinedAt {
            chat.unreadCount += 1
        }

        try ctx.save()
        return msg
    }

    /// Persist an incoming message: upserts sender and inserts message
    static func persistIncomingMessage(
        ctx: SwiftDataActor,
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
        if let codename = senderCodename, let pubKey = senderPubKey {
            sender = try upsertSender(
                ctx: ctx,
                pubKey: pubKey,
                codename: codename,
                nickname: nickname,
                dmToken: dmToken,
                color: color
            )
        }

        let internalId = InternalIdGenerator.shared.next()
        return try insertMessage(
            ctx: ctx,
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
