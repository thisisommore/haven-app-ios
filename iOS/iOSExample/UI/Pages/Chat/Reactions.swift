//
//  Reactions.swift
//  iOSExample
//
//  Created by Om More on 28/09/25.
//

import SQLiteData
import SwiftUI

struct ReactorsSheet: View {
  let groupedReactions: [(emoji: String, reactions: [MessageReactionModel])]
  let selectedEmoji: String?
  @State private var currentEmoji: String?
  @Dependency(\.defaultDatabase) var database

  var displayedReactions: [MessageReactionModel] {
    if let emoji = currentEmoji ?? selectedEmoji {
      return self.groupedReactions.first { $0.emoji == emoji }?.reactions ?? []
    }
    return self.groupedReactions.flatMap { $0.reactions }
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        // Emoji tabs
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            ForEach(self.groupedReactions, id: \.emoji) { group in
              Button {
                self.currentEmoji = group.emoji
              } label: {
                HStack(spacing: 4) {
                  Text(group.emoji)
                  Text("\(group.reactions.count)")
                    .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                  (self.currentEmoji ?? self.selectedEmoji) == group.emoji
                    ? Color.accentColor.opacity(0.2)
                    : Color.secondary.opacity(0.1)
                )
                .clipShape(Capsule())
              }
              .buttonStyle(.plain)
            }
          }
          .padding(.horizontal)
        }
        .padding(.vertical, 12)

        Divider()

        // Reactors list
        List(self.displayedReactions, id: \.id) { reaction in
          HStack {
            Text(reaction.emoji)
              .font(.title2)
            Text(self.senderCodename(for: reaction))
              .foregroundStyle(reaction.isMe ? Color.accentColor : Color.primary)
            Spacer()
            if reaction.isMe {
              Text("You")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }
        .listStyle(.plain)
      }
      .navigationTitle("Reactions")
      .navigationBarTitleDisplayMode(.inline)
    }
  }

  private func senderCodename(for reaction: MessageReactionModel) -> String {
    if reaction.isMe {
      return "You"
    }
    guard let sender = try? database.read({ db in
      try MessageSenderModel.where { $0.id.eq(reaction.senderId) }.fetchOne(db)
    })
    else { return "Unknown" }
    return sender.codename
  }
}
