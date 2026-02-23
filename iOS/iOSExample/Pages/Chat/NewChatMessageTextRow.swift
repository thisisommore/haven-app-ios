import SwiftUI
import UIKit

struct NewChatMessageTextRow: View {
    let message: ChatMessageModel
    let reactions: [MessageReactionModel]
    let showSender: Bool
    let showTimestamp: Bool
    var isFirstInGroup: Bool = true
    var repliedToMessage: String? = nil
    var isAdmin: Bool = false
    var isSenderMuted: Bool = false
    var onReply: ((ChatMessageModel) -> Void)? = nil
    var onDM: ((String, Int32, Data, Int) -> Void)? = nil
    var onDelete: ((ChatMessageModel) -> Void)? = nil
    var onMute: ((Data) -> Void)? = nil
    var onUnmute: ((Data) -> Void)? = nil
    var onShowReactions: ((String) -> Void)? = nil
    var onScrollToReply: ((String) -> Void)? = nil
    var isHighlighted: Bool = false
    var renderChannelPreview: ((ParsedChannelLink, Bool, String) -> AnyView)? = nil
    var renderDMPreview: ((ParsedDMLink, Bool, String) -> AnyView)? = nil

    private var senderDisplayName: String {
        guard let sender = message.sender else { return "" }
        guard let nickname = sender.nickname, !nickname.isEmpty else {
            return sender.codename
        }
        let truncatedNick = nickname.count > 10 ? String(nickname.prefix(10)) + "…" : nickname
        return "\(truncatedNick) aka \(sender.codename)"
    }

    private static let shortTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    private var timestampText: String {
        Self.shortTimeFormatter.string(from: message.timestamp)
    }

    @ViewBuilder
    private func messageBubble(
        isIncoming: Bool,
        showSender: Bool,
        senderDisplayName: String,
        senderColorHex: Int?
    ) -> some View {
        NewChatMessageBubbleText(
            message: message,
            isIncoming: isIncoming,
            showSender: showSender,
            senderDisplayName: senderDisplayName,
            senderColorHex: senderColorHex,
            showTimestamp: showTimestamp,
            timestampText: timestampText,
            isHighlighted: isHighlighted,
            isFirstInGroup: isFirstInGroup,
            renderChannelPreview: renderChannelPreview,
            renderDMPreview: renderDMPreview
        )
        .contentShape(Rectangle())
        .swipeToReply {
            onReply?(message)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            if message.isIncoming {
                VStack(alignment: .leading, spacing: 2) {
                    if let repliedToMessage {
                        MessageReplyPreview(
                            text: repliedToMessage,
                            isIncoming: true,
                            onTap: {
                                if let replyTo = message.replyTo {
                                    onScrollToReply?(replyTo)
                                }
                            }
                        )
                        .padding(.leading, 8)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let replyTo = message.replyTo {
                                onScrollToReply?(replyTo)
                            }
                        }
                    }
                    messageBubble(
                        isIncoming: true,
                        showSender: showSender,
                        senderDisplayName: senderDisplayName,
                        senderColorHex: message.sender?.color
                    )
                    if !reactions.isEmpty {
                        Reactions(
                            reactions: reactions,
                            onRequestShowAll: {
                                onShowReactions?(message.id)
                            }
                        )
                    }
                }
                Spacer(minLength: 44)
            } else {
                Spacer(minLength: 44)
                VStack(alignment: .trailing, spacing: 2) {
                    if let repliedToMessage {
                        MessageReplyPreview(
                            text: repliedToMessage,
                            isIncoming: false,
                            onTap: {
                                if let replyTo = message.replyTo {
                                    onScrollToReply?(replyTo)
                                }
                            }
                        )
                        .padding(.trailing, 8)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let replyTo = message.replyTo {
                                onScrollToReply?(replyTo)
                            }
                        }
                    }
                    messageBubble(
                        isIncoming: false,
                        showSender: false,
                        senderDisplayName: "",
                        senderColorHex: nil
                    )
                    if !reactions.isEmpty {
                        Reactions(
                            reactions: reactions,
                            onRequestShowAll: {
                                onShowReactions?(message.id)
                            }
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
    }
}

private struct NewChatMessageBubbleText: View {
    let message: ChatMessageModel
    let isIncoming: Bool
    let showSender: Bool
    let senderDisplayName: String
    let senderColorHex: Int?
    let showTimestamp: Bool
    let timestampText: String
    let isHighlighted: Bool
    let isFirstInGroup: Bool
    let renderChannelPreview: ((ParsedChannelLink, Bool, String) -> AnyView)?
    let renderDMPreview: ((ParsedDMLink, Bool, String) -> AnyView)?
    @Environment(\.colorScheme) private var colorScheme

    @State private var parsedChannelLink: ParsedChannelLink?
    @State private var parsedDMLink: ParsedDMLink?

    private var bubbleShape: UnevenRoundedRectangle {
        if isIncoming {
            return UnevenRoundedRectangle(
                topLeadingRadius: isFirstInGroup ? 16 : 4,
                bottomLeadingRadius: 4,
                bottomTrailingRadius: 16,
                topTrailingRadius: 16
            )
        } else {
            return UnevenRoundedRectangle(
                topLeadingRadius: 16,
                bottomLeadingRadius: 16,
                bottomTrailingRadius: 4,
                topTrailingRadius: isFirstInGroup ? 16 : 4
            )
        }
    }

    var body: some View {
        Group {
            if let link = parsedChannelLink, let renderer = renderChannelPreview {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        if showSender, let senderColorHex {
                            Text(senderDisplayName)
                                .font(.caption.bold())
                                .foregroundStyle(
                                    Color(hexNumber: senderColorHex).adaptive(for: colorScheme)
                                )
                        }
                        NewChatRenderableMessageText(
                            message: message,
                            isIncoming: isIncoming,
                            timestampPlaceholder: nil
                        )
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: isIncoming ? .leading : .trailing)
                    .background(isHighlighted ? Color.haven : (isIncoming ? Color.messageBubble : Color.haven))

                    renderer(link, isIncoming, showTimestamp ? timestampText : "")
                }
                .clipShape(bubbleShape)
                .overlay(
                    bubbleShape.stroke(Color.haven, lineWidth: isHighlighted ? 2 : 0)
                )
            } else if let link = parsedDMLink, let renderer = renderDMPreview {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        if showSender, let senderColorHex {
                            Text(senderDisplayName)
                                .font(.caption.bold())
                                .foregroundStyle(
                                    Color(hexNumber: senderColorHex).adaptive(for: colorScheme)
                                )
                        }
                        NewChatRenderableMessageText(
                            message: message,
                            isIncoming: isIncoming,
                            timestampPlaceholder: nil
                        )
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: isIncoming ? .leading : .trailing)
                    .background(isHighlighted ? Color.haven : (isIncoming ? Color.messageBubble : Color.haven))

                    renderer(link, isIncoming, showTimestamp ? timestampText : "")
                }
                .clipShape(bubbleShape)
                .overlay(
                    bubbleShape.stroke(Color.haven, lineWidth: isHighlighted ? 2 : 0)
                )
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    if showSender, let senderColorHex {
                        Text(senderDisplayName)
                            .font(.caption.bold())
                            .foregroundStyle(
                                Color(hexNumber: senderColorHex).adaptive(for: colorScheme)
                            )
                    }
                    NewChatRenderableMessageText(
                        message: message,
                        isIncoming: isIncoming,
                        timestampPlaceholder: showTimestamp ? timestampText : nil
                    )
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(isHighlighted ? Color.haven : (isIncoming ? Color.messageBubble : Color.haven))
                .clipShape(bubbleShape)
                .overlay(alignment: .bottomTrailing) {
                    if showTimestamp {
                        Text(timestampText)
                            .font(.system(size: 10))
                            .foregroundStyle(isIncoming ? Color.messageText : Color.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                    }
                }
                .overlay(
                    bubbleShape.stroke(Color.haven, lineWidth: isHighlighted ? 2 : 0)
                )
            }
        }
        .onAppear {
            parseLinks(from: message.message)
        }
        .onChange(of: message.message) { _, newValue in
            parseLinks(from: newValue)
        }
    }

    private func parseLinks(from text: String) {
        if let channelLink = ParsedChannelLink.parse(from: text) {
            parsedChannelLink = channelLink
            parsedDMLink = nil
        } else if let dmLink = ParsedDMLink.parse(from: text) {
            parsedChannelLink = nil
            parsedDMLink = dmLink
        } else {
            parsedChannelLink = nil
            parsedDMLink = nil
        }
    }
}

private struct NewChatRenderableMessageText: View {
    let message: ChatMessageModel
    let isIncoming: Bool
    let timestampPlaceholder: String?

    @State private var pendingURL: URL?
    @State private var showOpenLinkWarning = false

    private var linkWarningMessage: String {
        "Opening links may expose metadata and reduce privacy/safety."
    }

    private var renderedText: Text {
        let baseText: Text = {
            switch NewMessageRenderCache.shared.renderedText(for: message) {
            case let .plain(text):
                return Text(verbatim: text)
            case let .rich(attributed):
                return Text(attributed)
            }
        }()
        guard let timestampPlaceholder else {
            return baseText
        }
        return baseText
            + Text("    \(timestampPlaceholder)")
            .font(.system(size: 10))
            .foregroundStyle(.clear)
    }

    var body: some View {
        renderedText
            .font(.system(size: 16))
            .foregroundStyle(isIncoming ? Color.messageText : Color.white)
            .tint(isIncoming ? Color.haven : Color.white)
            .environment(\.openURL, OpenURLAction { url in
                pendingURL = url
                showOpenLinkWarning = true
                return .handled
            })
            .alert("Open External Link?", isPresented: $showOpenLinkWarning, presenting: pendingURL) { url in
                Button("Cancel", role: .cancel) {
                    pendingURL = nil
                }
                Button("Open") {
                    UIApplication.shared.open(url)
                    pendingURL = nil
                }
            } message: { _ in
                Text(linkWarningMessage)
            }
    }
}
