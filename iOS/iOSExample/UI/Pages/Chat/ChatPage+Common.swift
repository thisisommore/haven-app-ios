//
//  ChatPage+Common.swift
//  iOSExample
//
//  Created by Om More on 28/09/25.
//

import Foundation

/// Strips a single surrounding <p>...</p> pair if present (after trimming whitespace)
func stripParagraphTags(_ s: String) -> String {
  let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
  return t.hasPrefix("<p>") &&
    t.hasSuffix("</p>") ?
    String(t.dropFirst(3).dropLast(4)) : s
}
