//
//  Database.swift
//  iOSExample
//
//  Created by Om More on 06/03/26.
//

import Foundation
import SQLiteData

func appDatabase() throws -> any DatabaseWriter {
  @Dependency(\.context) var context
  var configuration = Configuration()
  #if DEBUG
    configuration.prepareDatabase { db in
      db.trace(options: .profile) {
        if context == .preview {
          print("\($0.expandedDescription)")
        } else {
          AppLogger.app.debug("\($0.expandedDescription)")
        }
      }
    }
  #endif
  let appSupportDir = try FileManager.default.url(
    for: .applicationSupportDirectory,
    in: .userDomainMask,
    appropriateFor: nil,
    create: true
  )
  let dbPath = appSupportDir.appendingPathComponent("SQLiteData.db").path
  let database = try defaultDatabase(path: dbPath, configuration: configuration)
  AppLogger.app.info("open '\(database.path)'")
  var migrator = DatabaseMigrator()
  #if DEBUG
    migrator.eraseDatabaseOnSchemaChange = true
  #endif

  //TODO migrations in separate folder with versioning/description
  migrator.registerMigration("v1:Create tables") { db in
    try #sql(
      """
      CREATE TABLE "chats"(
        "id" TEXT NOT NULL PRIMARY KEY,
        "name" TEXT NOT NULL,
        "channelDescription" TEXT,
        "dmToken" INTEGER,
        "color" INTEGER NOT NULL DEFAULT 15299665,
        "isAdmin" INTEGER NOT NULL DEFAULT 0,
        "isSecret" INTEGER NOT NULL DEFAULT 0,
        "joinedAt" TEXT NOT NULL,
        "unreadCount" INTEGER NOT NULL DEFAULT 0
      ) STRICT
      """
    )
    .execute(db)

    try #sql(
      """
      CREATE TABLE "messageSenders"(
        "id" TEXT NOT NULL PRIMARY KEY,
        "pubkey" BLOB NOT NULL,
        "codename" TEXT NOT NULL,
        "nickname" TEXT,
        "dmToken" INTEGER NOT NULL DEFAULT 0,
        "color" INTEGER NOT NULL
      ) STRICT
      """
    )
    .execute(db)

    try #sql(
      """
      CREATE TABLE "chatMessages"(
        "id" TEXT NOT NULL PRIMARY KEY,
        "internalId" INTEGER NOT NULL,
        "message" TEXT NOT NULL,
        "timestamp" TEXT NOT NULL,
        "isIncoming" INTEGER NOT NULL,
        "isRead" INTEGER NOT NULL DEFAULT 0,
        "statusRaw" INTEGER NOT NULL DEFAULT 1,
        "senderId" TEXT REFERENCES "messageSenders"("id"),
        "chatId" TEXT NOT NULL REFERENCES "chats"("id") ON DELETE CASCADE,
        "replyTo" TEXT,
        "newContainsMarkup" INTEGER NOT NULL DEFAULT 0,
        "newRenderKindRaw" INTEGER NOT NULL DEFAULT 0,
        "newRenderVersion" INTEGER NOT NULL DEFAULT 0,
        "newRenderPlainText" TEXT,
        "newRenderPayload" BLOB
      ) STRICT
      """
    )
    .execute(db)

    try #sql(
      """
      CREATE TABLE "messageReactions"(
        "id" TEXT NOT NULL PRIMARY KEY,
        "internalId" INTEGER NOT NULL,
        "targetMessageId" TEXT NOT NULL,
        "emoji" TEXT NOT NULL,
        "timestamp" TEXT NOT NULL,
        "isMe" INTEGER NOT NULL DEFAULT 0,
        "senderId" TEXT REFERENCES "messageSenders"("id")
      ) STRICT
      """
    )
    .execute(db)

    try #sql(
      """
      CREATE TABLE "generatedIdentities"(
        "privateIdentity" BLOB NOT NULL,
        "codename" TEXT NOT NULL,
        "codeset" INTEGER NOT NULL,
        "pubkey" TEXT NOT NULL
      ) STRICT
      """
    )
    .execute(db)
  }
  try migrator.migrate(database)
  return database
}
