//
//  Reactions.swift
//  iOSExample
//
//  Created by Om More on 28/09/25.
//

import SQLiteData
import SwiftUI

struct ReactorsSheet: View {
  let targetMessageId: String
  let chatId: UUID
  let selectedEmoji: String?
  var onDeleteReaction: ((MessageReactionModel) -> Void)?
  @FetchAll private var reactions: [MessageReactionModel]
  @State private var currentEmoji: String?
  @State private var canDeleteMyReactions: Bool = false
  @Dependency(\.defaultDatabase) var database

  init(
    targetMessageId: String,
    chatId: UUID,
    selectedEmoji: String?,
    onDeleteReaction: ((MessageReactionModel) -> Void)? = nil
  ) {
    self.targetMessageId = targetMessageId
    self.chatId = chatId
    self.selectedEmoji = selectedEmoji
    self.onDeleteReaction = onDeleteReaction
    _reactions = FetchAll(MessageReactionModel.where { $0.targetMessageId.eq(targetMessageId) })
    _currentEmoji = State(initialValue: selectedEmoji)
  }

  private var groupedReactions: [(emoji: String, reactions: [MessageReactionModel])] {
    Dictionary(grouping: self.reactions, by: \.emoji)
      .map { (emoji: $0.key, reactions: $0.value) }
      .sorted { $0.reactions.count > $1.reactions.count }
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
                  self.deleteReaction(reaction)
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
    .onAppear {
      self.refreshDeletePermission()
      self.ensureCurrentEmojiIsValid()
    }
    .onChange(of: self.reactions) { _, _ in
      self.ensureCurrentEmojiIsValid()
    }
  }

  private func senderCodename(for reaction: MessageReactionModel) -> String {
    if reaction.isMe { return "You" }
    let sender = try? self.database.read { db in
      try MessageSenderModel.where { $0.id.eq(reaction.senderId) }.fetchOne(db)
    }
    return sender?.codename ?? "Unknown"
  }

  private func ensureCurrentEmojiIsValid() {
    if let currentEmoji = self.currentEmoji,
       !self.groupedReactions.contains(where: { $0.emoji == currentEmoji }) {
      self.currentEmoji = nil
    }
  }

  private func refreshDeletePermission() {
    let canDelete = (try? self.database.read { db in
      try ChatModel.where { $0.id.eq(self.chatId) }.fetchOne(db)
    })?.channelId != nil
    self.canDeleteMyReactions = canDelete
  }

  private func deleteReaction(_ reaction: MessageReactionModel) {
    guard self.canDeleteMyReactions else { return }

    do {
      try self.database.write { db in
        try MessageReactionModel.delete(reaction).execute(db)
      }
      self.onDeleteReaction?(reaction)
    } catch {
      AppLogger.chat.error(
        "Failed to delete reaction from sheet: \(error.localizedDescription, privacy: .public)"
      )
    }
  }
}
