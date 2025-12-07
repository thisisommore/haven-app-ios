//
//  Chat.swift
//  iOSExample
//
//  Created by Om More on 24/09/25.
//

import SwiftData
import Foundation



@Model
class Chat {
    // For channels, this is the channel ID. For DMs, this is the pub key.
    @Attribute(.unique) var id: String
    // Human-readable name (channel name or partner codename)
    var name: String
    // Channel description
    var channelDescription: String?

    // needed for direct dm
    var dmToken: Int32?
    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.chat)
    var messages = [ChatMessage]()
    var color: Int = 0xE97451
    // Whether user is admin of this channel
    var isAdmin: Bool = false
    // Timestamp when user joined this chat
    var joinedAt: Date = Date()
    // Unread message count (stored for SwiftUI reactivity)
    var unreadCount: Int = 0
    
    // Recalculate unread count from messages
    func recalculateUnreadCount() {
        unreadCount = messages.filter { $0.isIncoming && !$0.isRead && $0.timestamp > joinedAt }.count
    }

    // General initializer (use for channels where you have a channel id and name)
    init(channelId: String, name: String, description: String? = nil, isAdmin: Bool = false) {
        self.id = channelId
        self.name = name
        self.channelDescription = description
        self.isAdmin = isAdmin
        self.joinedAt = Date()
    }

    // initializer for DM chats where pubkey and dmToken is required
    init(pubKey: Data, name: String, dmToken: Int32, color: Int) {
        self.id = pubKey.base64EncodedString()
        self.name = name
        self.dmToken = dmToken
        self.color = color
        self.joinedAt = Date()
    }

    func add(m: ChatMessage){
        messages.append(m)
    }
}


