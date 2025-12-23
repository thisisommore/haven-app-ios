//
//  MessageBubble.swift
//  iOSExample
//
//  Created by Om More on 19/10/25.
//

import SwiftHTMLtoMarkdown
import SwiftUI
import UniformTypeIdentifiers

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
    @State private var markdown: String = ""
    @State private var parsedChannelLink: ParsedChannelLink?
    @State private var isLinkExpanded: Bool = false
    @State private var showTextSelection: Bool = false
    var onDM: ((String, Int32, Data, Int) -> Void)?
    var onDelete: (() -> Void)?
    var onMute: ((Data) -> Void)?
    var onUnmute: ((Data) -> Void)?
    let isSenderMuted: Bool
    let isHighlighted: Bool
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

        // Compute markdown from HTML and initialize @State
        var document = BasicHTML(rawHTML: text)
        // Parse and convert to markdown safely; fall back to raw text on failure
        do {
            try document.parse()
            let md = try document.asMarkdown()
            _markdown = State(initialValue: md)
        } catch {
            _markdown = State(initialValue: text)
        }

        // Parse channel link if present
        _parsedChannelLink = State(initialValue: ParsedChannelLink.parse(from: text))
    }

    private var underlinedMarkdown: AttributedString {
        var attributed = (try? AttributedString(markdown: markdown)) ?? AttributedString(markdown)
        for run in attributed.runs {
            if run.link != nil {
                attributed[run.range].underlineStyle = .single
            }
        }
        return attributed
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
    private func channelLinkContent(link: ParsedChannelLink) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Orange/colored section with message
            VStack(alignment: .leading, spacing: 4) {
                if isIncoming && isFirstInGroup {
                    MessageSender(
                        isIncoming: isIncoming,
                        sender: sender
                    )
                }

                HStack(alignment: .top, spacing: 4) {
                    Text(underlinedMarkdown)
                        .font(.system(size: 16))
                        .foregroundStyle(isIncoming ? Color.messageText : Color.white)
                        .tint(isIncoming ? .blue : .white)
                        .lineLimit(isLinkExpanded ? nil : 1)

                    if !isLinkExpanded {
                        Button {
                            withAnimation { isLinkExpanded = true }
                        } label: {
                            Text("expand")
                                .font(.system(size: 14))
                                .foregroundStyle(isIncoming ? Color.messageText.opacity(0.7) : Color.white.opacity(0.7))
                                .underline()
                        }
                        .buttonStyle(.plain)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation { isLinkExpanded.toggle() }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: isIncoming ? .leading : .trailing)
            .background(isIncoming ? Color.messageBubble : Color.haven)

            // White section with channel preview (includes timestamp)
            ChannelInviteLinkPreview<T>(
                link: link,
                isIncoming: isIncoming,
                timestamp: showTimestamp ? timestamp : ""
            )
        }
        .clipShape(bubbleShape)
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
                (
                    Text(underlinedMarkdown)
                        .font(.system(size: 16))
                        .foregroundColor(isIncoming ? Color.messageText : Color.white)
                        + Text("    \(timestamp)")
                        .font(.system(size: 10))
                        .foregroundColor(.clear)
                )
                .tint(isIncoming ? .blue : .white)
            } else {
                Text(underlinedMarkdown)
                    .font(.system(size: 16))
                    .foregroundColor(isIncoming ? Color.messageText : Color.white)
                    .tint(isIncoming ? .blue : .white)
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
        Group {
            if let link = parsedChannelLink {
                channelLinkContent(link: link)
            } else {
                regularMessageContent
            }
        }
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
            if let attributed = try? AttributedString(markdown: markdown) {
                TextSelectionView(text: String(attributed.characters))
            } else {
                TextSelectionView(text: text)
            }
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
