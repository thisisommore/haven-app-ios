//
//  ChatMessageRow.swift
//  iOSExample
//
//  Created by Om More on 28/09/25.
//
import SwiftData
import SwiftUI

struct ChatMessageRow<T: XXDKP>: View {
    let result: ChatMessageModel
    let isAdmin: Bool
    let isFirstInGroup: Bool
    let isLastInGroup: Bool
    let showTimestamp: Bool
    let repliedToMessage: String?
    let reactions: [MessageReactionModel]
    var onReply: ((ChatMessageModel) -> Void)?
    var onDM: ((String, Int32, Data, Int) -> Void)?
    var onDelete: ((ChatMessageModel) -> Void)?
    var onMute: ((Data) -> Void)?
    var onUnmute: ((Data) -> Void)?
    let mutedUsers: [Data]
    let highlightedMessageId: String?
    var onScrollToReply: ((String) -> Void)?

    private var sender: MessageSenderModel? { result.sender }

    private var isHighlighted: Bool {
        highlightedMessageId == result.id
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(
                alignment: result.isIncoming ? .leading : .trailing,
                spacing: 0
            ) {
                MessageItem<T>(
                    text: result.message,
                    isIncoming: result.isIncoming,
                    repliedTo: repliedToMessage,
                    repliedToId: result.replyTo,
                    sender: sender,
                    isFirstInGroup: isFirstInGroup,
                    isLastInGroup: isLastInGroup,
                    showTimestamp: showTimestamp,
                    onReply: {
                        onReply?(result)
                    },
                    onDM: onDM,
                    onDelete: {
                        onDelete?(result)
                    },
                    onMute: onMute,
                    onUnmute: onUnmute,
                    isSenderMuted: sender.map { mutedUsers.contains($0.pubkey) } ?? false,
                    timestamp: result.timestamp,
                    isAdmin: isAdmin,
                    onScrollToReply: onScrollToReply,
                    isHighlighted: isHighlighted
                )
                Reactions(reactions: reactions)
            }
            if result.isIncoming { // incoming aligns left
                Spacer()
            }
        }
        .id(result.id)
    }
}
