//
//  ChatMessageRow.swift
//  iOSExample
//
//  Created by Om More on 28/09/25.
//
import SwiftData
import SwiftUI
struct ChatMessageRow: View {
    let result: ChatMessage
    let isAdmin: Bool
    var onReply: ((ChatMessage) -> Void)?
    var onDM: ((String, Int32, Data, Int) -> Void)?
    var onDelete: ((ChatMessage) -> Void)?
    var onMute: ((Data) -> Void)?
    var onUnmute: ((Data) -> Void)?
    let mutedUsers: [Data]
    let highlightedMessageId: String?
    var onScrollToReply: ((String) -> Void)?
    @Query private var chatReactions: [MessageReaction]
    @Query private var repliedTo: [ChatMessage]
    @Query private var messageSender: [Sender]
    
    private var isHighlighted: Bool {
        highlightedMessageId == result.id
    }
    
    init(result: ChatMessage, isAdmin: Bool = false, onReply: ((ChatMessage) -> Void)? = nil, onDM: ((String, Int32, Data, Int) -> Void)?, onDelete: ((ChatMessage) -> Void)? = nil, onMute: ((Data) -> Void)? = nil, onUnmute: ((Data) -> Void)? = nil, mutedUsers: [Data] = [], highlightedMessageId: String? = nil, onScrollToReply: ((String) -> Void)? = nil) {
        self.result = result
        self.isAdmin = isAdmin
        self.onReply = onReply
        self.onDelete = onDelete
        self.onMute = onMute
        self.onUnmute = onUnmute
        self.mutedUsers = mutedUsers
        self.highlightedMessageId = highlightedMessageId
        self.onScrollToReply = onScrollToReply
        let messageId = result.id
        let replyTo = result.replyTo
        let senderId = result.sender?.id
        _chatReactions = Query(filter: #Predicate<MessageReaction> { r in
            r.targetMessageId == messageId
        })
        self.onDM = onDM
        _repliedTo = Query(filter: #Predicate<ChatMessage> { r in
            if (replyTo != nil) { r.id == replyTo! } else { false }
        })
        _messageSender = Query(filter: #Predicate<Sender> { s in
            if (senderId != nil) { s.id == senderId! } else { false }
        })
    }
    var body: some View {
        HStack(spacing: 0) {
            VStack(
                alignment: result.isIncoming ? .leading : .trailing,
                spacing: 0
            ) {
                MessageItem(
                    text: result.message,
                    isIncoming: result.isIncoming,
                    repliedTo: repliedTo.first?.message,
                    repliedToId: result.replyTo,
                    sender: messageSender.first,
                    onReply: {
                        onReply?(result)
                    },
                    onDM: onDM,
                    onDelete: {
                        onDelete?(result)
                    },
                    onMute: onMute,
                    onUnmute: onUnmute,
                    isSenderMuted: messageSender.first.map { mutedUsers.contains($0.pubkey) } ?? false,
                    timestamp: result.timestamp,
                    isAdmin: isAdmin,
                    onScrollToReply: onScrollToReply,
                    isHighlighted: isHighlighted,
                    chatMessage: result
                )
                Reactions(reactions: chatReactions)
            }
            if result.isIncoming {  // incoming aligns left
                Spacer()
            }
        }
        .id(result.id)
    }
}

