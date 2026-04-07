//
//  ChatMessage.swift
//  iOSExample
//
//  Created by Om More on 17/10/25.
//
import Foundation
import SQLiteData
import UIKit

/// Message delivery status
public enum MessageStatus: Int, QueryBindable, Sendable {
  case unsent = 0
  case sent = 1
  case delivered = 2
  case failed = 3
  case deleting = 9

  public var name: String {
    switch self {
    case .unsent: return "unsent"
    case .sent: return "sent"
    case .delivered: return "delivered"
    case .failed: return "failed"
    case .deleting: return "deleting"
    }
  }

  /// Int64 since we receive that from network
  public init?(_ rawValue: Int64) {
    guard let s = MessageStatus(rawValue: Int(rawValue)) else {
      return nil
    }
    self = s
  }

  public init?(_ rawValue: Int) {
    guard let s = MessageStatus(rawValue: Int(rawValue)) else {
      return nil
    }
    self = s
  }
}

@Table("chatMessages")
public struct ChatMessageModel: Identifiable, Hashable, Sendable {
  public var id: Int64
  public var externalId: String
  public var message: String
  public var timestamp: Date
  public var isIncoming: Bool
  public var isRead: Bool = false
  public var status: MessageStatus
  public var senderId: UUID?
  public var chatId: UUID
  public var replyTo: String?
  public var isPlain: Bool = false

  public init(
    message: String, isIncoming: Bool, chatId: UUID, senderId: UUID? = nil,
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
    self.status = status ?? .unsent
  }
}
