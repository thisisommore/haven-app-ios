//
//  MessageSender.swift
//  iOSExample
//
//  Created by Om More on 19/10/25.
//

import SwiftUI

/// Displays the sender's name/codename for a message
struct MessageSender: View {
    let isIncoming: Bool
    let sender: SenderModel?
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        HStack {

            if !isIncoming {
                Text("You")
                    .font(.caption)
                    .foregroundStyle(.primary)
            } else if let sender {
                let hasNickname = sender.nickname != nil && !sender.nickname!.isEmpty
                let displayName: String = {
                    guard hasNickname else { return sender.codename }
                    let nick = sender.nickname!
                    let truncatedNick = nick.count > 10 ? String(nick.prefix(10)) + "…" : nick
                    return "\(truncatedNick) aka \(sender.codename)"
                }()
                Text(displayName).bold()
                    .font(.caption)
                    .foregroundStyle(
                        Color(hexNumber: sender.color).adaptive(
                            for: colorScheme
                        )
                    )
            }

        }
    }
}
