//
//  ChatMessage.swift
//  iOSExample
//
//  Created by Om More on 17/10/25.
//
import Foundation
import SQLiteData

/// Message type enum matching channel message types
enum MessageType: Int64 {
    case text = 1
    case reply = 2
    case reaction = 3
}

/// Message delivery status
enum MessageStatus: Int, QueryBindable {
    case unsent = 0
    case sent = 1
    case delivered = 2
    case failed = 3

    var name: String {
        switch self {
        case .unsent: return "unsent"
        case .sent: return "sent"
        case .delivered: return "delivered"
        case .failed: return "failed"
        }
    }
}

@Table("chatMessages")
struct ChatMessageModel: Identifiable, Hashable {
    var id: String
    var internalId: Int64
    var message: String
    var timestamp: Date
    var isIncoming: Bool
    var isRead: Bool = false
    var status: MessageStatus = .sent
    var senderId: String?
    var chatId: String
    var replyTo: String?
    var newContainsMarkup: Bool = false
    var newRenderKind: NewMessageRenderKind = .unknown
    var newRenderVersion: Int = 0
    var newRenderPlainText: String
    var newRenderPayload: Data?

    init(
        message: String, isIncoming: Bool, chatId: String, senderId: String? = nil,
        id: String, internalId: Int64, replyTo: String? = nil,
        timestamp: Int64 = Int64(Date().timeIntervalSince1970 * 1e+6 * 1e+3),
        isRead: Bool = false
    ) {
        self.id = id
        self.internalId = internalId
        self.message = message
        self.timestamp = Date(timeIntervalSince1970: Double(timestamp) * 1e-6 * 1e-3)
        self.isIncoming = isIncoming
        self.isRead = isRead
        self.senderId = senderId
        self.chatId = chatId
        self.replyTo = replyTo
        newRenderPlainText = message
    }
}
