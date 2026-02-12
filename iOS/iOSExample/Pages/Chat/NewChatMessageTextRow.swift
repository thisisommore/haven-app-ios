import SwiftUI

struct NewChatMessageTextRow: View {
    let message: ChatMessageModel

    var body: some View {
        HStack(spacing: 0) {
            if message.isIncoming {
                NewChatMessageBubbleText(
                    text: message.message,
                    isIncoming: true
                )
                Spacer(minLength: 44)
            } else {
                Spacer(minLength: 44)
                NewChatMessageBubbleText(
                    text: message.message,
                    isIncoming: false
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
        Text(verbatim: text)
            .font(.system(size: 16))
            .foregroundStyle(isIncoming ? Color.messageText : Color.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isIncoming ? Color.messageBubble : Color.haven)
            .clipShape(bubbleShape)
    }
}
