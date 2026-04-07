//
//  v1_init.swift
//  iOSExample
//
//  Created by Om More on 15/03/26.
//

import SQLiteData

public extension DatabaseMigrator {
  mutating func v1() {
    self.registerMigration("v1:init") { db in
      try #sql(
        """
        CREATE TABLE "chats"(
          "id" TEXT NOT NULL PRIMARY KEY,
          "name" TEXT NOT NULL,
          "channelId" TEXT UNIQUE,
          "pubKey" BLOB UNIQUE,
          "channelDescription" TEXT,
          "dmToken" INTEGER,
          "color" INTEGER NOT NULL,
          "isAdmin" INTEGER NOT NULL,
          "isSecret" INTEGER NOT NULL,
          "joinedAt" TEXT NOT NULL,
          "unreadCount" INTEGER NOT NULL
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
          "dmToken" INTEGER,
          "color" INTEGER NOT NULL
        ) STRICT
        """
      )
      .execute(db)

      try #sql(
        """
        CREATE TABLE "channelMutedUsers"(
          "id" TEXT NOT NULL PRIMARY KEY,
          "channelId" TEXT NOT NULL REFERENCES "chats"("channelId") ON DELETE CASCADE,
          "pubkey" BLOB NOT NULL,
          UNIQUE("channelId", "pubkey")
        ) STRICT
        """
      )
      .execute(db)

      try #sql(
        """
        CREATE TABLE "chatMessages"(
          "id" INTEGER NOT NULL PRIMARY KEY,
          "externalId" TEXT NOT NULL UNIQUE,
          "message" TEXT NOT NULL,
          "timestamp" TEXT NOT NULL,
          "isIncoming" INTEGER NOT NULL,
          "isRead" INTEGER NOT NULL,
          "status" INTEGER NOT NULL,
          "senderId" TEXT REFERENCES "messageSenders"("id"),
          "chatId" TEXT NOT NULL REFERENCES "chats"("id") ON DELETE CASCADE,
          "replyTo" TEXT,
          "isPlain" INTEGER NOT NULL
        ) STRICT
        """
      )
      .execute(db)

      try #sql(
        """
        CREATE TABLE "messageReactions"(
          "id" INTEGER NOT NULL PRIMARY KEY,
          "externalId" TEXT NOT NULL UNIQUE,
          "targetMessageId" TEXT NOT NULL,
          "emoji" TEXT NOT NULL,
          "timestamp" TEXT NOT NULL,
          "senderId" TEXT NOT NULL REFERENCES "messageSenders"("id"),
          "status" INTEGER NOT NULL
        ) STRICT
        """
      )
      .execute(db)
    }
  }
}
