//
//  MessageBubble.swift
//  iOSExample
//
//  Created by Om More on 19/10/25.
//

import SwiftUI
import UniformTypeIdentifiers
import SwiftHTMLtoMarkdown
/// The main message bubble containing text and context menu
struct MessageBubble: View {
    let text: String
    let isIncoming: Bool
    let sender: Sender?
    let timestamp: String
    let isAdmin: Bool
    @Binding var selectedEmoji: MessageEmoji
    @Binding var shouldTriggerReply: Bool
    @State private var markdown: String = ""
    @State private var parsedChannelLink: ParsedChannelLink?
    var onDM: ((String, Int32, Data, Int) -> Void)?
    var onDelete: (() -> Void)?
    var onMute: ((Data) -> Void)?
    var onUnmute: ((Data) -> Void)?
    let isSenderMuted: Bool
    init(
        text: String,
        isIncoming: Bool,
        sender: Sender?,
        timestamp: String,
        selectedEmoji: Binding<MessageEmoji>,
        shouldTriggerReply: Binding<Bool>,
        isAdmin: Bool = false,
        onDM: ((String, Int32, Data, Int) -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onMute: ((Data) -> Void)? = nil,
        onUnmute: ((Data) -> Void)? = nil,
        isSenderMuted: Bool = false
    ) {
        self.text = text
        self.isIncoming = isIncoming
        self.sender = sender
        self.timestamp = timestamp
        self.isAdmin = isAdmin
        self.onDM = onDM
        self.onDelete = onDelete
        self.onMute = onMute
        self.onUnmute = onUnmute
        self.isSenderMuted = isSenderMuted

        // Initialize @Binding properties
        self._selectedEmoji = selectedEmoji
        self._shouldTriggerReply = shouldTriggerReply

        // Compute markdown from HTML and initialize @State
        var document = BasicHTML(rawHTML: text)
        // Parse and convert to markdown safely; fall back to raw text on failure
        do {
            try document.parse()
            let md = try document.asMarkdown()
            self._markdown = State(initialValue: md)
        } catch {
            self._markdown = State(initialValue: text)
        }
        
        // Parse channel link if present
        self._parsedChannelLink = State(initialValue: ParsedChannelLink.parse(from: text))
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
    
    var body: some View {
        Group {
            if let link = parsedChannelLink {
                // Message with channel preview
                VStack(alignment: .leading, spacing: 0) {
                    // Orange/colored section with message
                    VStack(alignment: isIncoming ? .leading : .trailing, spacing: 4) {
                        if isIncoming {
                            MessageSender(
                                isIncoming: isIncoming,
                                sender: sender
                            )
                        }

                        HStack {
                            Text(underlinedMarkdown)
                            .font(.system(size: 16))
                            .foregroundStyle(isIncoming ? Color.messageText : Color.white)
                            .tint(isIncoming ? .blue : .white)
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
                        timestamp: timestamp
                    )
                }
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 16,
                        bottomLeadingRadius: isIncoming ? 0 : 16,
                        bottomTrailingRadius: isIncoming ? 16 : 0,
                        topTrailingRadius: 16
                    )
                )
            } else {
                // Regular message without preview
                VStack(alignment: isIncoming ? .leading : .trailing, spacing: 4) {
                    if isIncoming {
                        MessageSender(
                            isIncoming: isIncoming,
                            sender: sender
                        )
                    }

                    HStack {
                        Text(underlinedMarkdown)
                        .font(.system(size: 16))
                        .foregroundStyle(isIncoming ? Color.messageText : Color.white)
                        .tint(isIncoming ? .blue : .white)
                    }
                    
                    VStack(alignment: .trailing) {
                        Text(timestamp).font(.system(size: 10)).foregroundStyle(
                            isIncoming ? Color.messageText : Color.white
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .background(isIncoming ? Color.messageBubble : Color.haven)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 16,
                        bottomLeadingRadius: isIncoming ? 0 : 16,
                        bottomTrailingRadius: isIncoming ? 16 : 0,
                        topTrailingRadius: 16
                    )
                )
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
                onDelete: onDelete,
                onMute: onMute,
                onUnmute: onUnmute,
                isSenderMuted: isSenderMuted
            )
        }
        .id(sender)
        .padding(.top, 6)
    }
}
//#Preview {
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
//}

