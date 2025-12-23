import Foundation
import SwiftUI

struct MessageItem<T: XXDKP>: View {
    let text: String
    let isIncoming: Bool
    let repliedTo: String?
    let repliedToId: String?
    let sender: MessageSenderModel?
    let isFirstInGroup: Bool
    let isLastInGroup: Bool
    let showTimestamp: Bool
    let timeStamp: String
    let isAdmin: Bool

    // File message properties
    let chatMessage: ChatMessageModel?

    var onReply: (() -> Void)?
    var onDM: ((String, Int32, Data, Int) -> Void)?
    var onDelete: (() -> Void)?
    var onMute: ((Data) -> Void)?
    var onUnmute: ((Data) -> Void)?
    let isSenderMuted: Bool
    var onScrollToReply: ((String) -> Void)?
    let isHighlighted: Bool

    init(text: String, isIncoming: Bool, repliedTo: String?, repliedToId: String? = nil, sender: MessageSenderModel?, isFirstInGroup: Bool = true, isLastInGroup: Bool = true, showTimestamp: Bool = true, onReply: (() -> Void)? = nil, onDM: ((String, Int32, Data, Int) -> Void)? = nil, onDelete: (() -> Void)? = nil, onMute: ((Data) -> Void)? = nil, onUnmute: ((Data) -> Void)? = nil, isSenderMuted: Bool = false, isEmojiSheetPresented: Bool = false, shouldTriggerReply: Bool = false, selectedEmoji: MessageEmoji = .none, timestamp: Date, isAdmin: Bool = false, onScrollToReply: ((String) -> Void)? = nil, isHighlighted: Bool = false, chatMessage: ChatMessageModel? = nil) {
        self.text = text
        self.isIncoming = isIncoming
        self.repliedTo = repliedTo
        self.repliedToId = repliedToId
        self.sender = sender
        self.isFirstInGroup = isFirstInGroup
        self.isLastInGroup = isLastInGroup
        self.showTimestamp = showTimestamp
        self.onReply = onReply
        self.onDM = onDM
        self.onDelete = onDelete
        self.onMute = onMute
        self.onUnmute = onUnmute
        self.isSenderMuted = isSenderMuted
        self.isAdmin = isAdmin
        self.onScrollToReply = onScrollToReply
        self.isHighlighted = isHighlighted
        self.chatMessage = chatMessage
        _isEmojiSheetPresented = State(initialValue: isEmojiSheetPresented)
        _shouldTriggerReply = State(initialValue: shouldTriggerReply)
        _selectedEmoji = State(initialValue: selectedEmoji)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        timeStamp = formatter.string(from: timestamp)
    }

    @State private var isEmojiSheetPresented = false
    @State private var shouldTriggerReply = false
    @State private var selectedEmoji: MessageEmoji = .none

    var body: some View {
        HStack(spacing: 2) {
            ConditionalSpacer(!isIncoming)
            VStack {
                if let repliedTo {
                    HStack {
                        ConditionalSpacer(!isIncoming)
                        MessageReplyPreview(
                            text: repliedTo,
                            isIncoming: isIncoming,
                            onTap: {
                                if let id = repliedToId {
                                    onScrollToReply?(id)
                                }
                            }
                        )
                        ConditionalSpacer(isIncoming)
                    }
                }

                HStack {
                    ConditionalSpacer(!isIncoming)

                    // Check if this is a file message
                    if let msg = chatMessage, msg.hasFile {
                        FileMessageBubble(
                            message: msg,
                            isIncoming: isIncoming,
                            timestamp: timeStamp,
                            showTimestamp: showTimestamp,
                            isHighlighted: isHighlighted
                        )
                    } else {
                        MessageBubble<T>(
                            text: text,
                            isIncoming: isIncoming,
                            sender: sender,
                            isFirstInGroup: isFirstInGroup,
                            isLastInGroup: isLastInGroup,
                            timestamp: timeStamp,
                            showTimestamp: showTimestamp,
                            selectedEmoji: $selectedEmoji,
                            shouldTriggerReply: $shouldTriggerReply,
                            isAdmin: isAdmin,
                            onDM: onDM,
                            onDelete: onDelete,
                            onMute: onMute,
                            onUnmute: onUnmute,
                            isSenderMuted: isSenderMuted,
                            isHighlighted: isHighlighted
                        )
                    }

                    ConditionalSpacer(isIncoming)
                }
            }
            ConditionalSpacer(isIncoming)
        }

        .sheet(isPresented: $isEmojiSheetPresented) {
            EmojiKeyboard { _ in
                // Handle emoji selection
                isEmojiSheetPresented = false
            }
        }
        .onChange(of: selectedEmoji) { _, newValue in
            if newValue == .custom {
                DispatchQueue.main.async {
                    isEmojiSheetPresented = true
                }
                selectedEmoji = .none
            }
        }
        .onChange(of: shouldTriggerReply) { _, newValue in
            if newValue {
                onReply?()
                shouldTriggerReply = false
            }
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 2) {
            // Incoming message with reply
            MessageItem<XXDKMock>(
                text: "<p>Yup here you go</p>",
                isIncoming: true,
                repliedTo:
                "Wow lets go Wow lets go Wow lets go Wow lets go Wow lets go",
                sender: MessageSenderModel(
                    id: "1",
                    pubkey: Data(),
                    codename: "Mayur",
                    dmToken: 123,
                    color: 0x4CAF50
                ),
                onReply: {
                },
                onDM: { name, _, _, _ in
                },
                selectedEmoji: MessageEmoji.none,
                timestamp: Date()
            )

            // Incoming message with link
            MessageItem<XXDKMock>(
                text: """
                <a href="https://www.example.com" rel="noopener noreferrer" target="_blank">
                Check out this link!
                </a>
                """,
                isIncoming: true,
                repliedTo: nil,
                sender: MessageSenderModel(
                    id: "2",
                    pubkey: Data(),
                    codename: "Alex",
                    dmToken: 456,
                    color: 0x2196F3
                ), timestamp: Date()
            )

            // Outgoing message with reply
            MessageItem<XXDKMock>(
                text: "Thanks for sharing!",
                isIncoming: false,
                repliedTo: """
                <a href="https://www.example.com" rel="noopener noreferrer" target="_blank">
                Check out this link!
                </a>
                """,
                sender: nil,
                onReply: {
                }, timestamp: Date()
            )

            // Simple incoming message
            MessageItem<XXDKMock>(
                text: "Hello there 👋",
                isIncoming: true,
                repliedTo: nil,
                sender: MessageSenderModel(
                    id: "3",
                    pubkey: Data(),
                    codename: "Sarah",
                    dmToken: 0,
                    color: 0xFF9800
                ), timestamp: Date()
            )

            // Simple outgoing message
            MessageItem<XXDKMock>(
                text: "Hi! How are you doing?",
                isIncoming: false,
                repliedTo: nil,
                sender: nil, timestamp: Date()
            )

            // Long incoming message
            MessageItem<XXDKMock>(
                text:
                "This is a much longer message to test how the bubble handles multiple lines of text. It should wrap nicely and maintain proper styling throughout.",
                isIncoming: true,
                repliedTo: nil,
                sender: MessageSenderModel(
                    id: "1",
                    pubkey: Data(),
                    codename: "Mayur",
                    dmToken: 123,
                    color: 0xCEF8C5
                ), timestamp: Date()
            )
        }
        .padding()
    }
    .mock()
}
