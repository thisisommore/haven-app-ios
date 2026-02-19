import SwiftUI
import UIKit

struct NewChatMessageTextRow: View {
    let message: ChatMessageModel
    let showSender: Bool
    let showTimestamp: Bool
    var isAdmin: Bool = false
    var isSenderMuted: Bool = false
    var onReply: ((ChatMessageModel) -> Void)? = nil
    var onDM: ((String, Int32, Data, Int) -> Void)? = nil
    var onDelete: ((ChatMessageModel) -> Void)? = nil
    var onMute: ((Data) -> Void)? = nil
    var onUnmute: ((Data) -> Void)? = nil

    @State private var showTextSelection = false

    private var displayText: String {
        message.newRenderPlainText ?? stripParagraphTags(message.message)
    }

    private var canDelete: Bool {
        (isAdmin || !message.isIncoming) && onDelete != nil
    }

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

    var body: some View {
        HStack(spacing: 0) {
            if message.isIncoming {
                NewChatMessageBubbleText(
                    message: message,
                    isIncoming: true,
                    showSender: showSender,
                    senderDisplayName: senderDisplayName,
                    senderColorHex: message.sender?.color,
                    showTimestamp: showTimestamp,
                    timestampText: timestampText
                )
                Spacer(minLength: 44)
            } else {
                Spacer(minLength: 44)
                NewChatMessageBubbleText(
                    message: message,
                    isIncoming: false,
                    showSender: false,
                    senderDisplayName: "",
                    senderColorHex: nil,
                    showTimestamp: showTimestamp,
                    timestampText: timestampText
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .swipeToReply {
            onReply?(message)
        }
        .contextMenu {
            Button {
                onReply?(message)
            } label: {
                Label("Reply", systemImage: "arrowshape.turn.up.left")
            }

            if message.isIncoming,
               let sender = message.sender,
               sender.dmToken != 0
            {
                Button {
                    onDM?(sender.codename, sender.dmToken, sender.pubkey, sender.color)
                } label: {
                    Label("Send DM", systemImage: "message")
                }
            }

            Button {
                UIPasteboard.general.string = displayText
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }

            Button {
                showTextSelection = true
            } label: {
                Label("Select Text", systemImage: "crop")
            }

            if canDelete {
                Button(role: .destructive) {
                    onDelete?(message)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }

            if isAdmin, message.isIncoming, let sender = message.sender {
                if isSenderMuted {
                    Button {
                        onUnmute?(sender.pubkey)
                    } label: {
                        Label("Unmute User", systemImage: "speaker.wave.2")
                    }
                } else {
                    Button(role: .destructive) {
                        onMute?(sender.pubkey)
                    } label: {
                        Label("Mute User", systemImage: "speaker.slash")
                    }
                }
            }
        }
        .sheet(isPresented: $showTextSelection) {
            TextSelectionView(text: displayText)
        }
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
    @Environment(\.colorScheme) private var colorScheme

    private var bubbleShape: UnevenRoundedRectangle {
        if isIncoming {
            return UnevenRoundedRectangle(
                topLeadingRadius: 16,
                bottomLeadingRadius: 4,
                bottomTrailingRadius: 16,
                topTrailingRadius: 16
            )
        } else {
            return UnevenRoundedRectangle(
                topLeadingRadius: 16,
                bottomLeadingRadius: 16,
                bottomTrailingRadius: 4,
                topTrailingRadius: 16
            )
        }
    }

    var body: some View {
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
            .background(isIncoming ? Color.messageBubble : Color.haven)
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
