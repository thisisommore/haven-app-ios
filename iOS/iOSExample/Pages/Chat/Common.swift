//
//  Common.swift
//  iOSExample
//
//  Created by Om More on 28/09/25.
//

import Foundation

// Strips a single surrounding <p>...</p> pair if present (after trimming whitespace)
func stripParagraphTags(_ s: String) -> String {
    let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.hasPrefix("<p>") && trimmed.hasSuffix("</p>") {
        let inner = trimmed.dropFirst(3).dropLast(4)
        return String(inner)
    }
    return s
}

extension Notification.Name {
    static let chatMessagesUpdated = Notification.Name("chatMessagesUpdated")
}
