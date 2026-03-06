//
//  ChatStore.swift
//  iOSExample
//

import Combine
import Foundation
import GRDB

final class ChatStore: ObservableObject {
    let db: AppDatabase

    init(database: AppDatabase) {
        db = database
    }

    var dbQueue: DatabaseQueue { db.dbQueue }

    // MARK: - Chat CRUD

    func insertChat(_ chat: ChatModel) throws {
        try dbQueue.write { db in
            try chat.insert(db)
        }
    }

    func upsertChat(_ chat: ChatModel) throws {
        try dbQueue.write { db in
            try chat.save(db)
        }
    }

    func fetchChat(id: String) throws -> ChatModel? {
        try dbQueue.read { db in
            try ChatModel.fetchOne(db, key: id)
        }
    }

    func fetchAllChats() throws -> [ChatModel] {
        try dbQueue.read { db in
            try ChatModel.fetchAll(db)
        }
    }

    func deleteChat(id: String) throws {
        try dbQueue.write { db in
            _ = try ChatModel.deleteOne(db, key: id)
        }
    }

    func updateChatAdmin(id: String, isAdmin: Bool) throws {
        try dbQueue.write { db in
            if var chat = try ChatModel.fetchOne(db, key: id) {
                chat.isAdmin = isAdmin
                try chat.update(db)
            }
        }
    }

    func deleteAllChats() throws {
        try dbQueue.write { db in
            _ = try MessageReactionModel.deleteAll(db)
            _ = try ChatMessageModel.deleteAll(db)
            _ = try MessageSenderModel.deleteAll(db)
            _ = try ChatModel.deleteAll(db)
        }
    }

    // MARK: - Sender CRUD

    func upsertSender(
        pubKey: Data,
        codename: String,
        nickname: String? = nil,
        dmToken: Int32,
        color: Int
    ) throws -> MessageSenderModel {
        try dbQueue.write { db in
            let senderId = pubKey.base64EncodedString()
            if var existing = try MessageSenderModel.fetchOne(db, key: senderId) {
                existing.dmToken = dmToken
                if let nickname, !nickname.isEmpty {
                    existing.nickname = nickname
                }
                try existing.update(db)
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
            try sender.insert(db)
            return sender
        }
    }

    func fetchSender(id: String) throws -> MessageSenderModel? {
        try dbQueue.read { db in
            try MessageSenderModel.fetchOne(db, key: id)
        }
    }

    func fetchSender(pubkey: Data) throws -> MessageSenderModel? {
        try dbQueue.read { db in
            try MessageSenderModel.filter(Column("pubkey") == pubkey).fetchOne(db)
        }
    }

    func fetchSenders(ids: [String]) throws -> [String: MessageSenderModel] {
        try dbQueue.read { db in
            let senders = try MessageSenderModel.filter(ids.contains(Column("id"))).fetchAll(db)
            return Dictionary(uniqueKeysWithValues: senders.map { ($0.id, $0) })
        }
    }

    // MARK: - Message CRUD

    func insertMessage(_ message: ChatMessageModel) throws {
        try dbQueue.write { db in
            try message.insert(db)
        }
    }

    func insertMessageAndBumpUnread(_ message: ChatMessageModel) throws {
        try dbQueue.write { db in
            try message.insert(db)
            if message.isIncoming {
                if let chat = try ChatModel.fetchOne(db, key: message.chatId),
                   message.timestamp > chat.joinedAt
                {
                    try db.execute(
                        sql: "UPDATE chatModel SET unreadCount = unreadCount + 1 WHERE id = ?",
                        arguments: [message.chatId]
                    )
                }
            }
        }
    }

    func fetchMessage(id: String) throws -> ChatMessageModel? {
        try dbQueue.read { db in
            try ChatMessageModel.fetchOne(db, key: id)
        }
    }

    func fetchMessage(internalId: Int64) throws -> ChatMessageModel? {
        try dbQueue.read { db in
            try ChatMessageModel.filter(Column("internalId") == internalId).fetchOne(db)
        }
    }

    func updateMessage(internalId: Int64, newId: String?, newStatusRaw: Int64?) throws -> ChatMessageModel? {
        try dbQueue.write { db in
            guard var msg = try ChatMessageModel
                .filter(Column("internalId") == internalId)
                .fetchOne(db)
            else { return nil }
            if let newId {
                msg.id = newId
            }
            if let newStatusRaw {
                msg.statusRaw = newStatusRaw
            }
            try msg.update(db)
            return msg
        }
    }

    func deleteMessage(id: String) throws {
        try dbQueue.write { db in
            _ = try ChatMessageModel.deleteOne(db, key: id)
        }
    }

    func markMessagesAsRead(chatId: String) throws {
        try dbQueue.write { db in
            guard let chat = try ChatModel.fetchOne(db, key: chatId) else { return }
            try db.execute(
                sql: """
                    UPDATE chatMessageModel SET isRead = 1
                    WHERE chatId = ? AND isIncoming = 1 AND isRead = 0 AND timestamp > ?
                    """,
                arguments: [chatId, chat.joinedAt]
            )
            try db.execute(
                sql: "UPDATE chatModel SET unreadCount = 0 WHERE id = ?",
                arguments: [chatId]
            )
        }
    }

    // MARK: - Message Paging

    func fetchLatestMessages(chatId: String, limit: Int) throws -> [ChatMessageModel] {
        try dbQueue.read { db in
            let rows = try ChatMessageModel
                .filter(Column("chatId") == chatId)
                .order(Column("timestamp").desc, Column("internalId").desc)
                .limit(limit)
                .fetchAll(db)
            return rows.reversed()
        }
    }

    func fetchOlderMessages(chatId: String, beforeTimestamp: Date, beforeInternalId: Int64, limit: Int) throws -> [ChatMessageModel] {
        try dbQueue.read { db in
            let rows = try ChatMessageModel
                .filter(Column("chatId") == chatId)
                .filter(
                    Column("timestamp") < beforeTimestamp ||
                        (Column("timestamp") == beforeTimestamp && Column("internalId") < beforeInternalId)
                )
                .order(Column("timestamp").desc, Column("internalId").desc)
                .limit(limit)
                .fetchAll(db)
            return rows.reversed()
        }
    }

    func fetchNewerMessages(chatId: String, afterTimestamp: Date, afterInternalId: Int64, limit: Int) throws -> [ChatMessageModel] {
        try dbQueue.read { db in
            try ChatMessageModel
                .filter(Column("chatId") == chatId)
                .filter(
                    Column("timestamp") > afterTimestamp ||
                        (Column("timestamp") == afterTimestamp && Column("internalId") > afterInternalId)
                )
                .order(Column("timestamp").asc, Column("internalId").asc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    func countNewerMessages(chatId: String, afterTimestamp: Date, afterInternalId: Int64) throws -> Int {
        try dbQueue.read { db in
            try ChatMessageModel
                .filter(Column("chatId") == chatId)
                .filter(
                    Column("timestamp") > afterTimestamp ||
                        (Column("timestamp") == afterTimestamp && Column("internalId") > afterInternalId)
                )
                .fetchCount(db)
        }
    }

    func fetchMessagesInRange(chatId: String, oldestTimestamp: Date, oldestInternalId: Int64, newestTimestamp: Date, newestInternalId: Int64) throws -> [ChatMessageModel] {
        try dbQueue.read { db in
            try ChatMessageModel
                .filter(Column("chatId") == chatId)
                .filter(
                    (Column("timestamp") > oldestTimestamp ||
                        (Column("timestamp") == oldestTimestamp && Column("internalId") >= oldestInternalId))
                        && (Column("timestamp") < newestTimestamp ||
                            (Column("timestamp") == newestTimestamp && Column("internalId") <= newestInternalId))
                )
                .order(Column("timestamp").asc, Column("internalId").asc)
                .fetchAll(db)
        }
    }

    func fetchMessages(ids: [String]) throws -> [ChatMessageModel] {
        try dbQueue.read { db in
            try ChatMessageModel
                .filter(ids.contains(Column("id")))
                .order(Column("timestamp").asc, Column("internalId").asc)
                .fetchAll(db)
        }
    }

    // MARK: - Reaction CRUD

    func insertReaction(_ reaction: MessageReactionModel) throws {
        try dbQueue.write { db in
            try reaction.insert(db)
        }
    }

    func upsertReaction(_ reaction: MessageReactionModel) throws {
        try dbQueue.write { db in
            try reaction.save(db)
        }
    }

    func fetchReactions(targetMessageId: String) throws -> [MessageReactionModel] {
        try dbQueue.read { db in
            try MessageReactionModel
                .filter(Column("targetMessageId") == targetMessageId)
                .order(Column("internalId").asc)
                .fetchAll(db)
        }
    }

    func fetchReactions(targetMessageIds: [String]) throws -> [String: [MessageReactionModel]] {
        guard !targetMessageIds.isEmpty else { return [:] }
        return try dbQueue.read { db in
            let reactions = try MessageReactionModel
                .filter(targetMessageIds.contains(Column("targetMessageId")))
                .order(Column("internalId").asc)
                .fetchAll(db)
            return Dictionary(grouping: reactions, by: { $0.targetMessageId })
        }
    }

    func deleteReaction(id: String) throws {
        try dbQueue.write { db in
            _ = try MessageReactionModel.deleteOne(db, key: id)
        }
    }

    func deleteReaction(messageId: String, emoji: String) throws {
        try dbQueue.write { db in
            _ = try MessageReactionModel
                .filter(Column("id") == messageId && Column("emoji") == emoji)
                .deleteAll(db)
        }
    }

    func deduplicateAndUpsertReaction(
        reactionMessageId: String,
        targetMessageId: String,
        emoji: String,
        senderId: String?,
        internalId: Int64
    ) throws -> MessageReactionModel {
        try dbQueue.write { db in
            let candidates = try MessageReactionModel
                .filter(Column("targetMessageId") == targetMessageId && Column("emoji") == emoji)
                .fetchAll(db)

            let sameSender = candidates.filter { $0.senderId == senderId }

            if let canonical = sameSender.first(where: { $0.id == reactionMessageId }) ?? sameSender.first {
                var updated = canonical
                if updated.id != reactionMessageId {
                    try MessageReactionModel.deleteOne(db, key: updated.id)
                    updated.id = reactionMessageId
                    try updated.insert(db)
                }
                if updated.senderId == nil, senderId != nil {
                    updated.senderId = senderId
                    try updated.update(db)
                }
                for dup in sameSender where dup.id != updated.id {
                    try MessageReactionModel.deleteOne(db, key: dup.id)
                }
                return updated
            } else {
                let newReaction = MessageReactionModel(
                    id: reactionMessageId,
                    internalId: internalId,
                    targetMessageId: targetMessageId,
                    emoji: emoji,
                    senderId: senderId
                )
                try newReaction.insert(db)
                return newReaction
            }
        }
    }

    // MARK: - Fetch-or-create helpers

    func fetchOrCreateDMChat(pubKey: Data, codename: String, dmToken: Int32, color: Int) throws -> ChatModel {
        try dbQueue.write { db in
            let pubKeyB64 = pubKey.base64EncodedString()
            if let existing = try ChatModel.fetchOne(db, key: pubKeyB64) {
                return existing
            }
            let newChat = ChatModel(pubKey: pubKey, name: codename, dmToken: dmToken, color: color)
            try newChat.insert(db)
            return newChat
        }
    }

    func fetchOrCreateChannelChat(channelId: String, channelName: String) throws -> ChatModel {
        try dbQueue.write { db in
            if let existing = try ChatModel.fetchOne(db, key: channelId) {
                return existing
            }
            let newChat = ChatModel(channelId: channelId, name: channelName)
            try newChat.insert(db)
            return newChat
        }
    }
}
