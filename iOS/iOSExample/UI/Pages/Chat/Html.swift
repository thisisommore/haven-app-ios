//
//  Html.swift
//  iOSExample
//
//  Created by Om More on 09/03/26.
//

import Foundation
import SQLiteData
import UIKit

enum NewMessageRenderKind: Int16, Codable, QueryBindable {
  case unknown = 0
  case plain = 1
  case rich = 2
  case failed = 3
}

enum NewMessageRenderVersion {
  static let current: Int16 = 1
}

struct NewMessageStyleBits: OptionSet, Hashable {
  let rawValue: Int

  static let bold = NewMessageStyleBits(rawValue: 1 << 0)
  static let italic = NewMessageStyleBits(rawValue: 1 << 1)
  static let strike = NewMessageStyleBits(rawValue: 1 << 2)
  static let code = NewMessageStyleBits(rawValue: 1 << 3)
  static let pre = NewMessageStyleBits(rawValue: 1 << 4)
  static let blockquote = NewMessageStyleBits(rawValue: 1 << 5)
  static let link = NewMessageStyleBits(rawValue: 1 << 6)
}

struct NewMessageSpan: Codable, Hashable {
  var startUTF16: Int
  var endUTF16: Int
  var styleBits: Int
  var href: String?
}

struct NewMessageParsedPayload: Codable, Hashable {
  var version: Int16
  var text: String
  var spans: [NewMessageSpan]

  func attributedString(baseFont: UIFont) -> NSAttributedString {
    let attributedString = NSMutableAttributedString(
      string: text,
      attributes: [
        .font: baseFont,
        .foregroundColor: UIColor.label,
      ]
    )

    for span in self.spans {
      // Convert UTF-16 offsets to String.Index
      let startIdx = String.Index(utf16Offset: span.startUTF16, in: self.text)
      let endIdx = String.Index(utf16Offset: span.endUTF16, in: self.text)

      // Convert String.Index to NSRange
      let nsRange = NSRange(startIdx ..< endIdx, in: self.text)

      let styleBits = NewMessageStyleBits(rawValue: span.styleBits)

      if styleBits.contains(.bold) {
        if let currentFont = attributedString.attribute(
          .font, at: nsRange.location, effectiveRange: nil
        ) as? UIFont {
          let boldFont = UIFont.systemFont(ofSize: currentFont.pointSize, weight: .bold)
          attributedString.addAttribute(.font, value: boldFont, range: nsRange)
        }
      }

      if styleBits.contains(.italic) {
        if let currentFont = attributedString.attribute(
          .font, at: nsRange.location, effectiveRange: nil
        ) as? UIFont {
          if let italicDescriptor = currentFont.fontDescriptor.withSymbolicTraits(
            .traitItalic
          ) {
            let italicFont = UIFont(
              descriptor: italicDescriptor, size: currentFont.pointSize
            )
            attributedString.addAttribute(.font, value: italicFont, range: nsRange)
          }
        }
      }

      if styleBits.contains(.strike) {
        attributedString.addAttribute(
          .strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: nsRange
        )
      }

      if styleBits.contains(.code) || styleBits.contains(.pre) {
        let codeFont = UIFont.monospacedSystemFont(
          ofSize: baseFont.pointSize * 0.9, weight: .regular
        )
        attributedString.addAttribute(.font, value: codeFont, range: nsRange)
        attributedString.addAttribute(
          .backgroundColor, value: UIColor.systemGray5.withAlphaComponent(0.5),
          range: nsRange
        )
      }

      if styleBits.contains(.link), let href = span.href, let url = URL(string: href) {
        attributedString.addAttribute(.link, value: url, range: nsRange)
      }
    }

    return attributedString
  }
}

struct NewMessagePrecomputedRender {
  var containsMarkup: Bool
  var kind: NewMessageRenderKind
  var version: Int16
  var plainText: String
  var payloadData: Data?
}
