//
//  ChatMessages+Type.swift
//  iOSExample
//
//  Created by Om More on 21/03/26.
//
import HavenCore
import UIKit

public extension ChatMessageModel {
  func attributedText(color: UIColor = .label, size: CGFloat = 17) -> NSAttributedString {
    let tagStripped = self.message.stripParagraphTags()
    if self.isPlain {
      return NSAttributedString(string: tagStripped, attributes:
        [.foregroundColor: color, .font: UIFont.systemFont(ofSize: size)])
    }

    do {
      return try HTMLParser.parse(text: self.message, color: color, size: size)
    } catch {
      AppLogger.messaging.error("failed to parse html \(error.localizedDescription)")
      return NSAttributedString(string: tagStripped, attributes: [.foregroundColor: color, .font: UIFont.systemFont(ofSize: size)])
    }
  }
}

struct MessageWithSender: Hashable {
  let message: ChatMessageModel
  let sender: MessageSenderModel
  let replyTo: ChatMessageModel?
  let reactionEmojis: [String]
}

extension MessageWithSender {
  var attributedText: NSAttributedString {
    return self.message.attributedText()
  }
}

/// DataSource
enum Message: Hashable {
  case text(MessageWithSender)
  case date(String)

  static func == (lhs: Message, rhs: Message) -> Bool {
    switch (lhs, rhs) {
    case let (
      .text(lhsMessage),
      .text(rhsMessage)
    ):
      return lhsMessage.message == rhsMessage.message
        && lhsMessage.sender == rhsMessage.sender
        && lhsMessage.replyTo == rhsMessage.replyTo
        && lhsMessage.reactionEmojis == rhsMessage.reactionEmojis
    case let (.date(lhsDate), .date(rhsDate)):
      return lhsDate == rhsDate
    default:
      return false
    }
  }

  func hash(into hasher: inout Hasher) {
    switch self {
    case let .text(messageWithSender):
      hasher.combine(0)
      hasher.combine(messageWithSender.message)
      hasher.combine(messageWithSender.sender)
      hasher.combine(messageWithSender.replyTo)
      hasher.combine(messageWithSender.reactionEmojis)
    case let .date(date):
      hasher.combine(1)
      hasher.combine(date)
    }
  }
}
