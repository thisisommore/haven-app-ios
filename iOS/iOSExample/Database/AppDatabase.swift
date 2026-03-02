//
//  AppDatabase.swift
//  iOSExample
//

import Foundation
import GRDB

struct AppDatabase {
    let dbQueue: DatabaseQueue

    init(_ dbQueue: DatabaseQueue) throws {
        self.dbQueue = dbQueue
        try migrator.migrate(dbQueue)
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        migrator.registerMigration("v1") { db in
            try db.create(table: "chatModel") { t in
                t.primaryKey("id", .text).notNull()
                t.column("name", .text).notNull()
                t.column("channelDescription", .text)
                t.column("dmToken", .integer)
                t.column("color", .integer).notNull().defaults(to: 0xE97451)
                t.column("isAdmin", .boolean).notNull().defaults(to: false)
                t.column("isSecret", .boolean).notNull().defaults(to: false)
                t.column("joinedAt", .datetime).notNull()
                t.column("unreadCount", .integer).notNull().defaults(to: 0)
            }

            try db.create(table: "messageSenderModel") { t in
                t.primaryKey("id", .text).notNull()
                t.column("pubkey", .blob).notNull()
                t.column("codename", .text).notNull()
                t.column("nickname", .text)
                t.column("dmToken", .integer).notNull().defaults(to: 0)
                t.column("color", .integer).notNull().defaults(to: 0xE97451)
            }

            try db.create(table: "chatMessageModel") { t in
                t.primaryKey("id", .text).notNull()
                t.column("internalId", .integer).notNull()
                t.column("message", .text).notNull()
                t.column("timestamp", .datetime).notNull()
                t.column("isIncoming", .boolean).notNull()
                t.column("isRead", .boolean).notNull().defaults(to: false)
                t.column("statusRaw", .integer).notNull().defaults(to: 1)
                t.column("senderId", .text).references("messageSenderModel", onDelete: .setNull)
                t.column("chatId", .text).notNull().references("chatModel", onDelete: .cascade)
                t.column("replyTo", .text)
                t.column("newContainsMarkup", .boolean).notNull().defaults(to: false)
                t.column("newRenderKindRaw", .integer).notNull().defaults(to: 0)
                t.column("newRenderVersion", .integer).notNull().defaults(to: 0)
                t.column("newRenderPlainText", .text)
                t.column("newRenderPayload", .blob)
            }
            try db.create(
                index: "chatMessageModel_chatId_timestamp_internalId",
                on: "chatMessageModel",
                columns: ["chatId", "timestamp", "internalId"]
            )

            try db.create(table: "messageReactionModel") { t in
                t.primaryKey("id", .text).notNull()
                t.column("internalId", .integer).notNull()
                t.column("targetMessageId", .text).notNull()
                t.column("emoji", .text).notNull()
                t.column("timestamp", .datetime).notNull()
                t.column("isMe", .boolean).notNull().defaults(to: false)
                t.column("senderId", .text).references("messageSenderModel", onDelete: .setNull)
            }
            try db.create(
                index: "messageReactionModel_targetMessageId",
                on: "messageReactionModel",
                columns: ["targetMessageId"]
            )
        }

        return migrator
    }

    static func makeDefault() throws -> AppDatabase {
        let url = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("haven_chat.sqlite")

        var config = Configuration()
        config.foreignKeysEnabled = true
        let dbQueue = try DatabaseQueue(path: url.path, configuration: config)
        return try AppDatabase(dbQueue)
    }

    static func makeInMemory() throws -> AppDatabase {
        var config = Configuration()
        config.foreignKeysEnabled = true
        let dbQueue = try DatabaseQueue(configuration: config)
        return try AppDatabase(dbQueue)
    }
}
