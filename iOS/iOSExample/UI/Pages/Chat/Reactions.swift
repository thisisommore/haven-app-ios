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
  let canDeleteMyReactions: Bool
  var onDeleteReaction: ((MessageReactionModel) -> Void)?
  @State private var currentEmoji: String?
  @Dependency(\.defaultDatabase) var database

  init(
    groupedReactions: [(emoji: String, reactions: [MessageReactionModel])],
    selectedEmoji: String?,
    canDeleteMyReactions: Bool = false,
    onDeleteReaction: ((MessageReactionModel) -> Void)? = nil
  ) {
    self.groupedReactions = groupedReactions
    self.selectedEmoji = selectedEmoji
    self.canDeleteMyReactions = canDeleteMyReactions
    self.onDeleteReaction = onDeleteReaction
    _currentEmoji = State(initialValue: selectedEmoji)
  }

  private var totalReactionCount: Int {
    self.groupedReactions.reduce(0) { partialResult, group in
      partialResult + group.reactions.count
    }
  }

  var displayedReactions: [MessageReactionModel] {
    if let emoji = self.currentEmoji {
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
            Button {
              self.currentEmoji = nil
            } label: {
              HStack(spacing: 4) {
                Text("All")
                Text("\(self.totalReactionCount)")
                  .font(.caption)
              }
              .padding(.horizontal, 12)
              .padding(.vertical, 8)
              .background(
                self.currentEmoji == nil
                  ? Color.accentColor.opacity(0.2)
                  : Color.secondary.opacity(0.1)
              )
              .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            ForEach(self.groupedReactions, id: \.emoji) { group in
              Button {
                if self.currentEmoji == group.emoji {
                  self.currentEmoji = nil
                } else {
                  self.currentEmoji = group.emoji
                }
              } label: {
                HStack(spacing: 4) {
                  Text(group.emoji)
                  Text("\(group.reactions.count)")
                    .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                  self.currentEmoji == group.emoji
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
              if self.canDeleteMyReactions {
                Button(role: .destructive) {
                  self.onDeleteReaction?(reaction)
                } label: {
                  Image(systemName: "trash")
                    .font(.caption)
                }
                .buttonStyle(.borderless)
              }
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
    if reaction.isMe { return "You" }
    let sender = try? self.database.read { db in
      try MessageSenderModel.where { $0.id.eq(reaction.senderId) }.fetchOne(db)
    }
    return sender?.codename ?? "Unknown"
  }
}
