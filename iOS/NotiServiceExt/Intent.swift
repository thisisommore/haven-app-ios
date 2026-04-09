//
//  Mapping.swift
//  iOSExample
//
//  Created by Om More on 08/04/26.
//
import HavenCore
import Intents
import os
import UIKit
import UserNotifications

struct Intent {
  static func mapToUserIntent(name: String) -> INInteraction {
    let avatarImage = self.makeAvatarImage(for: name)
    let sender = self.makeConversationPerson(for: name, avatarImage: avatarImage)
    let intent = self.makeIntent(for: name, body: "new message", sender: sender, avatarImage: avatarImage)

    let interaction = INInteraction(intent: intent, response: nil)
    interaction.direction = .incoming
    return interaction
  }

  static func makeAvatarImage(for title: String) -> INImage? {
    guard let data = initialsImage(text: initials(for: title)) else {
      AppLogger.messaging.warning("PushABCDOM failed to render initials avatar")
      return nil
    }

    return INImage(imageData: data)
  }

  static func makeConversationPerson(for item: String, avatarImage: INImage?) -> INPerson {
    var nameComponents = PersonNameComponents()
    nameComponents.nickname = item

    return INPerson(
      personHandle: INPersonHandle(value: item, type: .unknown),
      nameComponents: nameComponents,
      displayName: item,
      image: avatarImage,
      contactIdentifier: nil,
      customIdentifier: UUID().uuidString,
      isMe: false
    )
  }

  static func makeIntent(
    for name: String,
    body: String,
    sender: INPerson,
    avatarImage: INImage?
  ) -> INSendMessageIntent {
    let intent = INSendMessageIntent(
      recipients: nil,
      outgoingMessageType: .outgoingMessageText,
      content: body,
      speakableGroupName: nil,
      conversationIdentifier: name,
      serviceName: "Haven",
      sender: sender,
      attachments: nil
    )
    intent.setImage(avatarImage, forParameterNamed: \.sender)
    return intent
  }

  private static func initialsImage(text: String, size: CGFloat = 60) -> Data? {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))

    return renderer.pngData { _ in
      let rect = CGRect(origin: .zero, size: CGSize(width: size, height: size))
      UIColor.systemOrange.setFill()
      UIBezierPath(ovalIn: rect).fill()

      let fontScale: CGFloat = switch text.count {
      case 0 ... 2:
        0.4
      case 3:
        0.3
      case 4:
        0.25
      default:
        0.2
      }

      let attributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: size * fontScale, weight: .semibold),
        .foregroundColor: UIColor.label,
      ]
      let textSize = (text as NSString).size(withAttributes: attributes)
      let textRect = CGRect(
        x: (size - textSize.width) / 2,
        y: (size - textSize.height) / 2,
        width: textSize.width,
        height: textSize.height
      )
      (text as NSString).draw(in: textRect, withAttributes: attributes)
    }
  }

  private static func initials(for title: String) -> String {
    let condensed = String(title.filter { !$0.isWhitespace })
    guard !condensed.isEmpty else {
      return String(title.prefix(3)).uppercased()
    }

    let letters = condensed.filter { $0.isLetter }
    let hasUppercaseLetters = letters.contains { $0.isUppercase }
    let hasLowercaseLetters = letters.contains { $0.isLowercase }

    if !(hasUppercaseLetters && hasLowercaseLetters) {
      return String(condensed.prefix(3)).uppercased()
    }

    let parts = self.splitCamelCaseWords(condensed)
    guard parts.count > 1 else {
      return String(parts.first?.prefix(3) ?? "")
    }

    return self.initialsFromCamelCaseSegments(parts)
  }

  private static func splitCamelCaseWords(_ string: String) -> [String] {
    let characters = Array(string)
    guard !characters.isEmpty else {
      return []
    }

    var parts: [String] = []
    var wordStart = 0

    for index in 1 ..< characters.count {
      if characters[index].isUppercase, characters[index - 1].isLowercase {
        parts.append(String(characters[wordStart ..< index]))
        wordStart = index
      }
    }

    parts.append(String(characters[wordStart ..< characters.count]))
    return parts
  }

  private static func initialsFromCamelCaseSegments(_ segments: [String]) -> String {
    var initials = ""

    for segment in segments where !segment.isEmpty {
      let remainingCharacterCount = 3 - initials.count
      guard remainingCharacterCount > 0 else {
        break
      }

      let lettersOnly = segment.filter { $0.isLetter }
      let isAllUppercaseRun = !lettersOnly.isEmpty && lettersOnly.allSatisfy { $0.isUppercase }

      if isAllUppercaseRun, segment.count > 1 {
        let characterCount = min(2, remainingCharacterCount, segment.count)
        initials += String(segment.prefix(characterCount))
      } else {
        initials += String(segment.prefix(1))
      }
    }

    return initials.isEmpty ? String(segments.joined().prefix(3)) : initials
  }
}
