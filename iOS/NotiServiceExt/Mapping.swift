//
//  Mapping.swift
//  iOSExample
//
//  Created by Om More on 09/04/26.
//
import Foundation
import HavenCore
import UserNotifications

extension UNNotificationContent {
  static func from(aggreate: RichMapping.Aggreate, sender: String) -> [UNNotificationContent] {
    var notifications: [UNNotificationContent] = []
    if aggreate.textCount > 0 {
      notifications.append(self.from(type: .text, sender: sender, count: aggreate.textCount))
    }
    if aggreate.replyCount > 0 {
      notifications.append(self.from(type: .reply, sender: sender, count: aggreate.replyCount))
    }
    if aggreate.reactionCount > 0 {
      notifications.append(self.from(type: .reaction, sender: sender, count: aggreate.reactionCount))
    }
    return notifications
  }

  static func from(type: RichMapping.NotificationType, sender: String, count: UInt) -> UNNotificationContent {
    let n = UNMutableNotificationContent()
    n.userInfo["id"] = "\(sender).\(type.rawValue)"
    n.threadIdentifier = sender
    n.userInfo["count"] = count
    n.title = sender
    n.body = "\(count) new \(count > 1 ? type.displayNamePlural : type.displayName)"
    return n
  }
}

enum RichMapping {
  struct Aggreate {
    var textCount: UInt = 0
    var replyCount: UInt = 0
    var reactionCount: UInt = 0

    // runs callback with every eligible type
    func forType(_ call: (_ type: NotificationType) -> Void) {
      if self.textCount > 0 {
        call(.text)
      }
      if self.replyCount > 0 {
        call(.reply)
      }
      if self.reactionCount > 0 {
        call(.reaction)
      }
    }

    mutating func addCount(_ type: NotificationType, count: UInt) {
      switch type {
      case .text:
        self.textCount += count
      case .reply:
        self.replyCount += count
      case .reaction:
        self.reactionCount += count
      default:
        break
      }
    }
  }

  enum NotificationType: String, Decodable {
    case text
    case adminText
    case reaction
    case silent
    case invitation
    case delete
    case pinned
    case mute
    case adminReplay
    case fileTransfer

    case reply

    case generic
    case mention

    var displayName: String {
      switch self {
      case .text: "message"
      case .reply: "reply"
      case .reaction: "reaction"
      default: ""
      }
    }

    var displayNamePlural: String {
      switch self {
      case .text: "messages"
      case .reply: "replies"
      case .reaction: "reactions"
      default: ""
      }
    }

    static func from(_ type: DMMessageType) -> NotificationType {
      switch type {
      case .text:
        .text
      case .reply:
        .reply
      case .reaction:
        .reaction
      case .silent:
        .silent
      case .invitation:
        .invitation
      case .delete:
        .delete
      }
    }

    static func from(_ type: ChannelPingType) -> NotificationType {
      switch type {
      case .reply:
        .reply
      case .generic:
        .generic
      case .mention:
        .mention
      }
    }

    static func from(_ type: ChannelsMessageType) -> NotificationType {
      switch type {
      case .text:
        .text
      case .adminText:
        .adminText
      case .reaction:
        .reaction
      case .silent:
        .silent
      case .invitation:
        .invitation
      case .delete:
        .delete
      case .pinned:
        .pinned
      case .mute:
        .mute
      case .adminReplay:
        .adminReplay
      case .fileTransfer:
        .fileTransfer
      }
    }
  }

  struct NotificationItem: Decodable {
    let chatName: String
    let type: NotificationType

    static func from(report: DMNotificationReport) throws -> NotificationItem {
      let chatName = Database.title(for: report)
      guard let chatName else { throw XXDKError.custom("chat name is nil") }

      return NotificationItem(chatName: chatName, type: NotificationType.from(report.type))
    }

    static func from(report: ChannelNotificationReport) throws -> NotificationItem {
      let chatName = Database.title(for: report)
      guard let chatName else { throw XXDKError.custom("chat name is nil") }

      if let pingType = report.pingType {
        return NotificationItem(chatName: chatName, type: NotificationType.from(pingType))
      }
      return NotificationItem(chatName: chatName, type: NotificationType.from(report.type))
    }
  }
}
