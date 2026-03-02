//
//  ChatModel.swift
//  iOSExample
//
//  Created by Om More on 24/09/25.
//

import Foundation
import GRDB

struct ChatModel: Identifiable, Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "chatModel"

    // For channels, this is the channel ID. For DMs, this is the pub key.
    var id: String
    // Human-readable name (channel name or partner codename)
    var name: String
    // Channel description
    var channelDescription: String?

    // needed for direct dm
    var dmToken: Int32?
    var color: Int = 0xE97451
    // Whether user is admin of this channel
    var isAdmin: Bool = false
    // Whether this is a secret channel
    var isSecret: Bool = false
    // Timestamp when user joined this chat
    var joinedAt: Date = Date()
    // Unread message count (stored for SwiftUI reactivity)
    var unreadCount: Int = 0

    // General initializer (use for channels where you have a channel id and name)
    init(channelId: String, name: String, description: String? = nil, isAdmin: Bool = false, isSecret: Bool = false) {
        id = channelId
        self.name = name
        channelDescription = description
        self.isAdmin = isAdmin
        self.isSecret = isSecret
        joinedAt = Date()
    }

    // initializer for DM chats where pubkey and dmToken is required
    init(pubKey: Data, name: String, dmToken: Int32, color: Int) {
        id = pubKey.base64EncodedString()
        self.name = name
        self.dmToken = dmToken
        self.color = color
        joinedAt = Date()
    }
}
