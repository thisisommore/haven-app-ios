import Foundation
import HavenCore
import SwiftSoup
import UIKit

final class HTMLParser {
  /// stack like, we add tags as we go deeper,
  /// when existing node this tag is used to determine which style to apply to text
  private var activeTag: [String] = []
  private var href: String?
  private var orderedListCounts: [Int] = []
  private let nsAttributedString = NSMutableAttributedString()
  private let color: UIColor
  private let size: CGFloat

  /// this attributes applied as default, it can be overriden see @appendAttributes
  private let baseAttrs: [NSAttributedString.Key: Any]

  private let boldFont: UIFont
  private let italicFont: UIFont
  private init(color: UIColor, size: CGFloat) {
    self.color = color
    self.size = size
    self.baseAttrs = [
      .font: UIFont.systemFont(ofSize: self.size),
      .foregroundColor: self.color,
    ]
    self.boldFont = UIFont.systemFont(ofSize: self.size, weight: .bold)
    self.italicFont = UIFont.italicSystemFont(ofSize: size)
  }

  /// Counts trailing newlines in the rendered output while ignoring spaces.
  /// This lets block elements and `<br>` share the same line-break policy.
  private func trailingNewlineCount() -> Int {
    let s = self.nsAttributedString.string
    var count = 0
    var index = s.unicodeScalars.endIndex
    while index > s.unicodeScalars.startIndex {
      s.unicodeScalars.formIndex(before: &index)
      let scalar = s.unicodeScalars[index]
      if scalar == "\n" {
        count += 1
      } else if CharacterSet.whitespaces.contains(scalar) {
        continue
      } else {
        break
      }
    }
    return count
  }

  /// Prevents repeated `<p>` / `<br>` nodes from producing more than one
  /// empty visual line in the final output.
  private func appendLineBreakIfNeeded() {
    guard self.trailingNewlineCount() < 2 else { return }
    self.appendAttributes("\n")
  }

  private func isAtStartOfLine() -> Bool {
    guard let lastScalar = self.nsAttributedString.string.unicodeScalars.last else {
      return true
    }
    return lastScalar == "\n"
  }

  /// SwiftSoup preserves indentation from the source HTML.
  /// Trim leading whitespace only when this text starts a new rendered line.
  private func normalizedText(for textNode: TextNode) -> String {
    let originalText = textNode.text()
    guard self.shouldTrimLeadingWhitespace(for: textNode) else {
      return originalText
    }

    return String(originalText.trimmingPrefix(while: { $0.isWhitespace || $0.isNewline }))
  }

  private func shouldTrimLeadingWhitespace(for textNode: TextNode) -> Bool {
    if textNode.siblingIndex == 0 {
      return true
    }

    if textNode.previousSibling()?.nodeName() == "br" {
      return true
    }

    return self.isAtStartOfLine()
  }

  /// clean leading and trailing whitespace, should be used after parsing
  func cleanChars() {
    let trimChars = CharacterSet.whitespacesAndNewlines
    // Trim trailing
    while let last = nsAttributedString.string.unicodeScalars.last,
          trimChars.contains(last) {
      self.nsAttributedString.deleteCharacters(
        in: NSRange(location: self.nsAttributedString.length - 1, length: 1)
      )
    }

    // Trim leading
    while let first = nsAttributedString.string.unicodeScalars.first,
          trimChars.contains(first) {
      self.nsAttributedString.deleteCharacters(
        in: NSRange(location: 0, length: 1)
      )
    }
  }

  /// Appends text using the base attributes plus any tag-specific overrides.
  private func appendAttributes(_ str: String, attrs: [NSAttributedString.Key: Any] = [:]) {
    // no attrs to add/override skip merging
    let finalAttrs = attrs.isEmpty
      ? self.baseAttrs
      // merge attributes, override old key with new on conflict
      : self.baseAttrs.merging(attrs) { _, new in new }
    self.nsAttributedString.append(NSAttributedString(string: str, attributes: finalAttrs))
  }

  private func orderedListDepth(for node: SwiftSoup.Node) -> Int {
    var depth = 0
    var current = node.parent()
    while let currentNode = current {
      let nodeName = currentNode.nodeName()
      if nodeName == "ol" || nodeName == "ul" {
        depth += 1
      }
      current = currentNode.parent()
    }
    return max(depth - 1, 0)
  }

  private func orderedListPrefix(for node: SwiftSoup.Node, number: Int) -> String {
    let indent = String(repeating: "    ", count: self.orderedListDepth(for: node))
    return "\n\(indent)\(number). "
  }
}

extension HTMLParser: NodeVisitor {
  func head(_ node: SwiftSoup.Node, _: Int) throws {
    let nodeName = node.nodeName()
    // body can be returned by swiftsoup, skip it, we only interested in child nodes
    if nodeName == "body" { return }

    if let el = node as? Element {
      self.activeTag.append(nodeName)

      if nodeName == "a" {
        if el.hasAttr("href") {
          self.href = try! el.attr("href")
        }
      }
      if nodeName == "p" {
        // Add paragraph spacing before the paragraph content so any preserved
        // indentation inside the `<p>` can be trimmed as leading whitespace.
        self.appendLineBreakIfNeeded()
      }

      if nodeName == "ol" {
        self.orderedListCounts.append(1)
      }
      if nodeName == "li" {
        guard let parent = node.parent() else { return }
        if parent.nodeName() == "ol" {
          let countIndex = self.orderedListCounts.count - 1
          let count = self.orderedListCounts[countIndex]
          self.appendAttributes(self.orderedListPrefix(for: node, number: count))
          self.orderedListCounts[countIndex] += 1
        } else if parent.nodeName() == "ul" {
          self.appendAttributes("\n- ")
        }
      }
    }
  }

  func tail(_ node: SwiftSoup.Node, _: Int) throws {
    let nodeName = node.nodeName()
    // body can be returned by swiftsoup, skip it, we only interested in child nodes
    if nodeName == "body" { return }

    // Element nodes that affect layout after their children are processed.
    if let el = node as? Element {
      if nodeName == "br" {
        self.appendLineBreakIfNeeded()
      }
      if nodeName == "ol", !self.orderedListCounts.isEmpty {
        self.orderedListCounts.removeLast()
      }

      if self.activeTag.last == nodeName {
        if nodeName == "a" {
          if el.hasAttr("href") {
            self.href = nil
          }
        }

        self.activeTag.removeLast()
      }
    }

    // Text nodes carry the actual visible content.
    if let tn = node as? TextNode {
      let text = self.normalizedText(for: tn)

      var attrs: [NSAttributedString.Key: Any] = [:]
      for tag in self.activeTag {
        if tag == "a", let href = href, let url = URL(string: href) {
          attrs[.link] = url
        } else if tag == "b" || tag == "strong" {
          attrs[.font] = self.boldFont
        } else if tag == "i" || tag == "em" {
          attrs[.font] = self.italicFont
        } else if tag == "s" {
          attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }
      }
      self.appendAttributes(text, attrs: attrs)
    }
  }
}

extension HTMLParser {
  private static let safelist = try! Whitelist.none()
    .addTags("blockquote", "p", "a", "br", "code", "ol", "ul",
             "li", "pre", "i", "strong", "b", "em", "s")
    .addAttributes("a", "href")
  static func parse(text: String, color: UIColor, size: CGFloat) throws -> NSAttributedString {
    let parser = Self(color: color, size: size)
    guard let cleanText = try SwiftSoup.clean(text, Self.safelist) else {
      throw XXDKError.custom("failed to clean html")
    }
    let doc = try parseBodyFragment(cleanText)
    parser.nsAttributedString.beginEditing()
    guard let body = doc.body() else {
      throw XXDKError.custom("body is nil")
    }
    try body.traverse(parser)

    parser.cleanChars()
    parser.nsAttributedString.endEditing()
    return parser.nsAttributedString
  }
}
