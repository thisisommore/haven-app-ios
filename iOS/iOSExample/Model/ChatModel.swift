//
//  ChatModel.swift
//  iOSExample
//
//  Created by Om More on 24/09/25.
//

import Foundation
import SQLiteData

@Table("chats")
struct ChatModel: Identifiable, Hashable {
    let id: String
    var name: String
    var channelDescription: String?
    var dmToken: Int32?
    var color: Int = 0xE97451
    var isAdmin: Bool = false
    var isSecret: Bool = false
    var joinedAt: Date = .init()
    var unreadCount: Int = 0
}

extension ChatModel {
    init(
        channelId: String, name: String, description: String? = nil, isAdmin: Bool = false,
        isSecret: Bool = false
    ) {
        id = channelId
        self.name = name
        channelDescription = description
        self.isAdmin = isAdmin
        self.isSecret = isSecret
    }

    init(pubKey: Data, name: String, dmToken: Int32, color: Int) {
        id = pubKey.base64EncodedString()
        self.name = name
        self.dmToken = dmToken
        self.color = color
    }
}
