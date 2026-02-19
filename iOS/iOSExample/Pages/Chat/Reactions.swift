//
//  Reactions.swift
//  iOSExample
//
//  Created by Om More on 28/09/25.
//

import SwiftData
import SwiftUI

struct Reactions: View {
    let reactions: [MessageReactionModel]
    var onRequestShowAll: (() -> Void)? = nil
    @State private var showReactors = false
    @State private var selectedEmoji: String?

    /// Groups reactions by emoji
    private var groupedReactions: [(emoji: String, reactions: [MessageReactionModel])] {
        Dictionary(grouping: reactions, by: { $0.emoji })
            .map { (emoji: $0.key, reactions: $0.value) }
            .sorted { $0.reactions.count > $1.reactions.count }
    }

    var body: some View {
        if !reactions.isEmpty {
            HStack(spacing: 4) {
                ForEach(Array(groupedReactions.prefix(3)), id: \.emoji) { group in
                    Button {
                        if let onRequestShowAll {
                            onRequestShowAll()
                        } else {
                            // Match old behavior: tapping any chip opens all reactors for this message.
                            selectedEmoji = nil
                            showReactors = true
                        }
                    } label: {
                        HStack(spacing: 2) {
                            Text(group.emoji)
                            if group.reactions.count > 1 {
                                Text("\(group.reactions.count)")
                                    .font(.system(size: 10))
                            }
                        }
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                if groupedReactions.count > 3 {
                    Button {
                        if let onRequestShowAll {
                            onRequestShowAll()
                        } else {
                            selectedEmoji = nil
                            showReactors = true
                        }
                    } label: {
                        Text("+\(groupedReactions.count - 3)")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .sheet(isPresented: $showReactors) {
                ReactorsSheet(
                    groupedReactions: groupedReactions,
                    selectedEmoji: selectedEmoji
                )
                .presentationDetents([.medium, .large])
            }
        }
    }
}

struct ReactorsSheet: View {
    let groupedReactions: [(emoji: String, reactions: [MessageReactionModel])]
    let selectedEmoji: String?
    @State private var currentEmoji: String?

    var displayedReactions: [MessageReactionModel] {
        if let emoji = currentEmoji ?? selectedEmoji {
            return groupedReactions.first { $0.emoji == emoji }?.reactions ?? []
        }
        return groupedReactions.flatMap { $0.reactions }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Emoji tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(groupedReactions, id: \.emoji) { group in
                            Button {
                                currentEmoji = group.emoji
                            } label: {
                                HStack(spacing: 4) {
                                    Text(group.emoji)
                                    Text("\(group.reactions.count)")
                                        .font(.caption)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    (currentEmoji ?? selectedEmoji) == group.emoji
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
                List(displayedReactions, id: \.id) { reaction in
                    HStack {
                        Text(reaction.emoji)
                            .font(.title2)
                        Text(reaction.sender?.codename ?? (reaction.isMe ? "You" : "Unknown"))
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
}
