//
//  MessageHtmlParser.swift
//  iOSExample
//
//  Created by Om More on 09/03/26.
//

import Foundation

enum NewMessageHTMLClassifier {
  private static let tagPattern = #"<\s*/?\s*[a-zA-Z][^>]*>"#
  private static let singleParagraphPattern =
    #"^\s*<\s*p(?:\s+[^>]*)?>\s*[^<>]*\s*<\s*/\s*p\s*>\s*$"#

  static func hasMarkup(_ text: String) -> Bool {
    text.range(of: self.tagPattern, options: .regularExpression) != nil
  }

  static func isSimpleParagraphWrapper(_ text: String) -> Bool {
    text.range(of: self.singleParagraphPattern, options: .regularExpression) != nil
  }
}

enum NewMessageHTMLPrecomputer {
  static func precompute(rawHTML: String) -> Bool {
    let hasMarkup = NewMessageHTMLClassifier.hasMarkup(rawHTML)
    let isSimpleParagraph = NewMessageHTMLClassifier.isSimpleParagraphWrapper(rawHTML)
    return !hasMarkup || isSimpleParagraph
  }
}
