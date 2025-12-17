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
struct MessageBubble: View {
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
            ChannelInviteLinkPreview(
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

// #Preview {
//    ScrollView {
//        VStack(spacing: 16) {
//            // Incoming bubble with sender
//            MessageBubble(
//                text: "<p>Hey! How's it going? 👋</p>",
//                isIncoming: true,
//                sender: Sender(
//                    id: "1",
//                    pubkey: Data(),
//                    codename: "Mayur",
//                    dmToken: 123,
//                    color: 0xcef8c5
//                ),
//                timestamp: "6:04pm",
//                selectedEmoji: .constant(.none),
//                shouldTriggerReply: .constant(false),
//                onDM: { name, token, pubkey, color in
//                    print("DM to \(name)")
//                },
//
//            )
//
//            // Outgoing bubble
//            MessageBubble(
//                text: "I'm doing great, thanks for asking!",
//                isIncoming: false,
//                sender: nil,
//                timestamp: "6:04pm",
//                selectedEmoji: .constant(.none),
//                shouldTriggerReply: .constant(false)
//            )
//
//            // Incoming with link
//            MessageBubble(
//                text: """
//                    <p>Hey <a href="https://www.example.com" rel="noopener noreferrer" target="_blank">Check this out!</a></p>
//                    """,
//                isIncoming: true,
//                sender: Sender(
//                    id: "2",
//                    pubkey: Data(),
//                    codename: "Alex",
//                    dmToken: 456,
//                    color: 0x2196F3
//                ),
//                timestamp: "6:04pm",
//                selectedEmoji: .constant(.none),
//                shouldTriggerReply: .constant(false)
//            )
//
//            // Long message incoming
//            MessageBubble(
//                text:
//                    "This is a longer message to demonstrate how the bubble handles multiple lines of text. It should wrap properly and maintain the correct styling throughout the entire message.",
//                isIncoming: true,
//                sender: Sender(
//                    id: "3",
//                    pubkey: Data(),
//                    codename: "Sarah",
//                    dmToken: 0,
//                    color: 0xFF9800
//                ),
//                timestamp: "6:04pm",
//                selectedEmoji: .constant(.none),
//                shouldTriggerReply: .constant(false)
//            )
//
//            // Long message outgoing
//            MessageBubble(
//                text:
//                    "Absolutely! I completely agree with what you're saying. The implementation looks solid and should work well for our use case.",
//                isIncoming: false,
//                sender: nil,
//                timestamp: "6:04pm",
//                selectedEmoji: .constant(.none),
//                shouldTriggerReply: .constant(false)
//            )
//
//            // Short incoming without DM token
//            MessageBubble(
//                text: """
//                <strong>Max Pro</strong></p><p><em>ultra</em></p><p><s>stk</s></p><p><a href="https://x.com/nikitabier/status/1481118406749220868" rel="noopener noreferrer" target="_blank">https://x.com/nikitabier/status/1481118406749220868</a></p><ol><li data-list="ordered"><span class="ql-ui" contenteditable="false"></span>max</li><li data-list="ordered"><span class="ql-ui" contenteditable="false"></span>pro</li></ol><p><br></p><ol><li data-list="true"><span class="ql-ui" contenteditable="false"></span>tetetwer</li><li data-list="true"><span class="ql-ui" contenteditable="false"></span><br></li></ol><blockquote>do it hehe</blockquote><p><br></p><p><code>print "hehe"</code></p><p><br></p><p>print nada
//                """,
//                isIncoming: true,
//                sender: Sender(
//                    id: "4",
//                    pubkey: Data(),
//                    codename: "Guest",
//                    dmToken: 0,
//                    color: 0x9E9E9E
//                ),
//                timestamp: "6:04pm",
//                selectedEmoji: .constant(.none),
//                shouldTriggerReply: .constant(false)
//            )
//        }
//        .padding()
//    }
// }
