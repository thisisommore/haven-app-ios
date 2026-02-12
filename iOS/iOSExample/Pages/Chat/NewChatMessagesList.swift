import SwiftUI

struct NewChatMessagesList: View {
    let messages: [ChatMessageModel]
    let isLoadingOlderMessages: Bool
    var onReachedTop: (() -> Void)?
    var onReplyMessage: ((ChatMessageModel) -> Void)?
    @State private var topVisibleMessageId: String?
    @State private var lastTopTriggerMessageId: String?
    private let bottomAnchorId = "new-chat-bottom-anchor"

    private func shouldShowSender(for index: Int) -> Bool {
        guard index < messages.count else { return false }
        let message = messages[index]
        guard message.isIncoming, let senderId = message.sender?.id else {
            return false
        }
        guard index > 0 else { return true }
        let previous = messages[index - 1]
        if !previous.isIncoming {
            return true
        }
        return previous.sender?.id != senderId
    }

    private var messageIds: [String] {
        messages.map(\.id)
    }

    private var lastMessageId: String? {
        messages.last?.id
    }

    private var firstMessageId: String? {
        messages.first?.id
    }

    private func scrollToBottom(_ scrollProxy: ScrollViewProxy) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            scrollProxy.scrollTo(bottomAnchorId, anchor: .bottom)
        }
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if isLoadingOlderMessages {
                        HStack {
                            Spacer()
                            ProgressView()
                                .scaleEffect(0.85)
                            Spacer()
                        }
                        .padding(.vertical, 6)
                    }

                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        NewChatMessageTextRow(
                            message: message,
                            showSender: shouldShowSender(for: index),
                            onReply: onReplyMessage
                        )
                            .id(message.id)
                    }
                    Color.clear
                        .frame(height: 1)
                        .id(bottomAnchorId)
                }
                .scrollTargetLayout()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollPosition(id: $topVisibleMessageId, anchor: .top)
            .onChange(of: topVisibleMessageId) { _, newTopVisibleId in
                guard let firstMessageId, firstMessageId == newTopVisibleId else { return }
                guard lastTopTriggerMessageId != newTopVisibleId else { return }
                lastTopTriggerMessageId = newTopVisibleId
                onReachedTop?()
            }
            .task(id: lastMessageId) {
                guard lastMessageId != nil else { return }
                Task { @MainActor in
                    await Task.yield()
                    scrollToBottom(scrollProxy)
                    try? await Task.sleep(for: .milliseconds(80))
                    scrollToBottom(scrollProxy)
                }
            }
            .onChange(of: messageIds) { oldIds, newIds in
                guard let lastMessageId = newIds.last else { return }
                let didPrependAtTop =
                    newIds.count >= oldIds.count &&
                    oldIds.last == newIds.last &&
                    oldIds.first != newIds.first

                guard didPrependAtTop,
                      let anchorId = topVisibleMessageId,
                      oldIds.contains(anchorId),
                      newIds.contains(anchorId)
                else { return }

                DispatchQueue.main.async {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        scrollProxy.scrollTo(anchorId, anchor: .top)
                    }
                }
            }
        }
    }
}
