import SwiftUI

struct NewChatMessageTextRow: View {
    let message: ChatMessageModel
    let showSender: Bool

    private var senderDisplayName: String {
        guard let sender = message.sender else { return "" }
        guard let nickname = sender.nickname, !nickname.isEmpty else {
            return sender.codename
        }
        let truncatedNick = nickname.count > 10 ? String(nickname.prefix(10)) + "…" : nickname
        return "\(truncatedNick) aka \(sender.codename)"
    }

    var body: some View {
        HStack(spacing: 0) {
            if message.isIncoming {
                NewChatMessageBubbleText(
                    text: message.message,
                    isIncoming: true,
                    showSender: showSender,
                    senderDisplayName: senderDisplayName,
                    senderColorHex: message.sender?.color
                )
                Spacer(minLength: 44)
            } else {
                Spacer(minLength: 44)
                NewChatMessageBubbleText(
                    text: message.message,
                    isIncoming: false,
                    showSender: false,
                    senderDisplayName: "",
                    senderColorHex: nil
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
    }
}

private struct NewChatMessageBubbleText: View {
    let text: String
    let isIncoming: Bool
    let showSender: Bool
    let senderDisplayName: String
    let senderColorHex: Int?
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
            Text(verbatim: text)
                .font(.system(size: 16))
                .foregroundStyle(isIncoming ? Color.messageText : Color.white)
        }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isIncoming ? Color.messageBubble : Color.haven)
            .clipShape(bubbleShape)
    }
}
