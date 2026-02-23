//
//  MessageBubble.swift
//  iOSExample
//
//  Created by Om More on 19/10/25.
//

import SwiftUI

/// The main message bubble containing text and context menu
struct MessageBubble<T: XXDKP>: View {
    let text: String
    let isIncoming: Bool
    let sender: MessageSenderModel?
    let isFirstInGroup: Bool
    let isLastInGroup: Bool
    let timestamp: String
    let showTimestamp: Bool
    let isAdmin: Bool
    @Binding var selectedEmoji: MessageEmoji
    @Binding var shouldTriggerReply: Bool
    var onDM: ((String, Int32, Data, Int) -> Void)?
    var onDelete: (() -> Void)?
    var onMute: ((Data) -> Void)?
    var onUnmute: ((Data) -> Void)?
    let isSenderMuted: Bool
    let isHighlighted: Bool

    @State private var showTextSelection: Bool = false

    // Corner radius values
    private let fullRadius: CGFloat = 16
    private let smallRadius: CGFloat = 4

    init(
        text: String,
        isIncoming: Bool,
        sender: MessageSenderModel?,
        isFirstInGroup: Bool = true,
        isLastInGroup: Bool = true,
        timestamp: String,
        showTimestamp: Bool = true,
        selectedEmoji: Binding<MessageEmoji>,
        shouldTriggerReply: Binding<Bool>,
        isAdmin: Bool = false,
        onDM: ((String, Int32, Data, Int) -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onMute: ((Data) -> Void)? = nil,
        onUnmute: ((Data) -> Void)? = nil,
        isSenderMuted: Bool = false,
        isHighlighted: Bool = false
    ) {
        self.text = text
        self.isIncoming = isIncoming
        self.sender = sender
        self.isFirstInGroup = isFirstInGroup
        self.isLastInGroup = isLastInGroup
        self.timestamp = timestamp
        self.showTimestamp = showTimestamp
        self.isAdmin = isAdmin
        self.onDM = onDM
        self.onDelete = onDelete
        self.onMute = onMute
        self.onUnmute = onUnmute
        self.isSenderMuted = isSenderMuted
        self.isHighlighted = isHighlighted

        // Initialize @Binding properties
        _selectedEmoji = selectedEmoji
        _shouldTriggerReply = shouldTriggerReply
    }

    /// Dynamic corner radii based on group position
    private var bubbleShape: UnevenRoundedRectangle {
        if isIncoming {
            // Incoming: left side changes based on position
            return UnevenRoundedRectangle(
                topLeadingRadius: isFirstInGroup ? fullRadius : smallRadius,
                bottomLeadingRadius: isLastInGroup ? smallRadius : smallRadius,
                bottomTrailingRadius: fullRadius,
                topTrailingRadius: fullRadius
            )
        } else {
            // Outgoing: right side changes based on position
            return UnevenRoundedRectangle(
                topLeadingRadius: fullRadius,
                bottomLeadingRadius: fullRadius,
                bottomTrailingRadius: isLastInGroup ? smallRadius : smallRadius,
                topTrailingRadius: isFirstInGroup ? fullRadius : smallRadius
            )
        }
    }

    @ViewBuilder
    private var regularMessageContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            if isIncoming && isFirstInGroup {
                MessageSender(
                    isIncoming: isIncoming,
                    sender: sender
                )
            }

            if showTimestamp {
                Text(verbatim: text)
                    .font(.system(size: 16))
                    .foregroundColor(isIncoming ? Color.messageText : Color.white)
                    + Text("    \(timestamp)")
                    .font(.system(size: 10))
                    .foregroundColor(.clear)

            } else {
                Text(verbatim: text)
                    .font(.system(size: 16))
                    .foregroundColor(isIncoming ? Color.messageText : Color.white)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .overlay(alignment: .bottomTrailing) {
            if showTimestamp {
                Text(timestamp)
                    .font(.system(size: 10))
                    .foregroundStyle(isIncoming ? Color.messageText : Color.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
            }
        }
        .background(isIncoming ? Color.messageBubble : Color.haven)
        .clipShape(bubbleShape)
    }

    var body: some View {
        regularMessageContent
            .contextMenu {
                MessageContextMenu(
                    text: text,
                    isIncoming: isIncoming,
                    sender: sender,
                    isAdmin: isAdmin,
                    selectedEmoji: $selectedEmoji,
                    shouldTriggerReply: $shouldTriggerReply,
                    onDM: onDM,
                    onSelectText: {
                        showTextSelection = true
                    },
                    onDelete: onDelete,
                    onMute: onMute,
                    onUnmute: onUnmute,
                    isSenderMuted: isSenderMuted
                )
            }
            .id(sender)
            .sheet(isPresented: $showTextSelection) {
                TextSelectionView(text: text)
            }
            .overlay(
                bubbleShape
                    .stroke(Color.haven, lineWidth: isHighlighted ? 2 : 0)
            )
            .shadow(color: Color.haven.opacity(isHighlighted ? 0.5 : 0), radius: 8)
            .animation(.easeInOut(duration: 0.25), value: isHighlighted)
            .padding(.top, isFirstInGroup ? 6 : 2)
    }
}

#Preview {
    let mockSender = MessageSenderModel(
        id: "mock-sender-1",
        pubkey: Data(),
        codename: "PreviewUser",
        dmToken: 123,
        color: 0x0B421F
    )

    ScrollView {
        VStack(spacing: 16) {
            MessageBubble<XXDKMock>(
                text: "Hello, this is a preview message!",
                isIncoming: true,
                sender: mockSender,
                timestamp: "10:00 AM",
                selectedEmoji: .constant(.none),
                shouldTriggerReply: .constant(false)
            )

            MessageBubble<XXDKMock>(
                text: "And this is a reply from me.",
                isIncoming: false,
                sender: nil,
                timestamp: "10:05 AM",
                selectedEmoji: .constant(.none),
                shouldTriggerReply: .constant(false)
            )

            MessageBubble<XXDKMock>(
                text: "Another message from preview user.",
                isIncoming: true,
                sender: mockSender,
                isFirstInGroup: false,
                timestamp: "10:06 AM",
                selectedEmoji: .constant(.none),
                shouldTriggerReply: .constant(false)
            )
        }
        .padding()
    }
    .mock()
}
