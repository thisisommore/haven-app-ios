//
//  ChatMessage.swift
//  iOSExample
//
//  Created by Om More on 17/10/25.
//
import Foundation
import SQLiteData

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

  /// Int64 since we receive that from network
  init?(_ rawValue: Int64) {
    guard let s = MessageStatus(rawValue: Int(rawValue)) else {
      return nil
    }
    self = s
  }
}

@Table("chatMessages")
struct ChatMessageModel: Identifiable, Hashable {
  var id: Int64
  var externalId: String
  var message: String
  var timestamp: Date
  var isIncoming: Bool
  var isRead: Bool = false
  var status: MessageStatus
  var senderId: UUID?
  var chatId: String
  var replyTo: String?
  var newContainsMarkup: Bool = false
  var newRenderKind: NewMessageRenderKind = .unknown
  var newRenderVersion: Int = 0
  var newRenderPlainText: String
  var newRenderPayload: Data?

  init(
    message: String, isIncoming: Bool, chatId: String, senderId: UUID? = nil,
    id: Int64, externalId: String, replyTo: String? = nil,
    timestamp: Date,
    isRead: Bool = false, status: MessageStatus?
  ) {
    self.id = id
    self.externalId = externalId
    self.message = message
    self.timestamp = timestamp
    self.isIncoming = isIncoming
    self.isRead = isRead
    self.senderId = senderId
    self.chatId = chatId
    self.replyTo = replyTo
    self.newRenderPlainText = message
    self.status = status ?? .unsent
  }
}
