//
//  Formatting.swift
//  iOSExample
//
//  Created by Om More on 16/03/26.
//
//
//  Formatting.swift
//  iOSExample
//
//  Created by Om More on 16/03/26.
//
import Foundation
import UIKit // Required for UIFont and text attributes

extension NSRange {
  static var first: NSRange {
    NSRange(location: 0, length: 1)
  }

  init(_ location: Int) {
    self.init(location: location, length: 1)
  }
}

extension String {
  static let fontSize: CGFloat = 18
  static let defaultAttributes: [NSAttributedString.Key: Any] = [
    .font: UIFont.systemFont(ofSize: fontSize),
    .foregroundColor: UIColor.label,
  ]

  /// Strips a single surrounding <p>...</p> pair if present (after trimming whitespace)
  func stripParagraphTags() -> String {
    let t = self.trimmingCharacters(in: .whitespacesAndNewlines)
    return t.hasPrefix("<p>") &&
      t.hasSuffix("</p>") ?
      String(t.dropFirst(3).dropLast(4)) : self
  }
}

enum MessageTextFormatting {
  /// True if any HTML tag remains after stripping a single root-level `<p>...</p>` wrapper.
  /// Nested `<p>` / `</p>` still counts as HTML.
  static func containsHTML(_ text: String) -> Bool {
    let s = text.stripParagraphTags()
    guard let regex = try? NSRegularExpression(pattern: #"<[^>]+>"#, options: .caseInsensitive) else {
      return false
    }
    return regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
  }
}
