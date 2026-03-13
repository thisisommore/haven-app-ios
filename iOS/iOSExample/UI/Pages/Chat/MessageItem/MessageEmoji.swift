//
//  MessageEmoji.swift
//  iOSExample
//
//  Created by Om More on 19/10/25.
//

import Foundation

/// Available emoji reactions for messages
enum MessageEmoji: String, CaseIterable, Identifiable {
    case laugh = "😂"
    case laughLoud = "🤣"
    case redHeart = "❤️"
    case cry = "😭"
    case like = "👍"
    case custom
    case none

    var id: Self { self }

    /// Get emoji tag from string
    static func from(_ emoji: String) -> MessageEmoji {
        switch emoji {
        case "😂": return .laugh
        case "😭": return .cry
        case "👍": return .like
        case "❤️": return .redHeart
        default: return .none
        }
    }
}
