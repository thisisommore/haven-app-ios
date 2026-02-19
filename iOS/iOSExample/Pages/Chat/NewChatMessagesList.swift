import Foundation
import SwiftUI
import UIKit

struct NewChatMessagesList: UIViewControllerRepresentable {
    let messages: [ChatMessageModel]
    let isLoadingOlderMessages: Bool
    let isAdmin: Bool
    let mutedUsers: Set<Data>
    var onReachedTop: (() -> Void)?
    var onReplyMessage: ((ChatMessageModel) -> Void)?
    var onDMMessage: ((String, Int32, Data, Int) -> Void)?
    var onDeleteMessage: ((ChatMessageModel) -> Void)?
    var onMuteUser: ((Data) -> Void)?
    var onUnmuteUser: ((Data) -> Void)?
    var onScrollActivityChanged: ((Bool) -> Void)?

    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ uiViewController: Controller, context: Context) {
        uiViewController.update(from: self)
    }

    final class Controller: UIViewController, UITableViewDataSource, UITableViewDelegate {
        private struct AnchorSnapshot {
            let messageId: String
            let offsetFromRowTop: CGFloat
        }

        private let tableView = UITableView(frame: .zero, style: .plain)
        private let loadingIndicator = UIActivityIndicatorView(style: .medium)
        private let cellReuseId = "chat-message-cell"
        private let nearBottomThreshold: CGFloat = 24
        private let topTriggerThreshold: CGFloat = 8

        private var hasInitialScroll = false
        private var isUserScrolling = false
        private var pendingMessages: [ChatMessageModel]?
        private var messages: [ChatMessageModel] = []
        private var lastTopTriggerMessageId: String?
        private var shouldLockBottomOnNextLayoutPass = false

        private var isLoadingOlderMessages = false
        private var isAdmin = false
        private var mutedUsers: Set<Data> = []
        private var onReachedTop: (() -> Void)?
        private var onReplyMessage: ((ChatMessageModel) -> Void)?
        private var onDMMessage: ((String, Int32, Data, Int) -> Void)?
        private var onDeleteMessage: ((ChatMessageModel) -> Void)?
        private var onMuteUser: ((Data) -> Void)?
        private var onUnmuteUser: ((Data) -> Void)?
        private var onScrollActivityChanged: ((Bool) -> Void)?

        override func viewDidLoad() {
            super.viewDidLoad()

            tableView.translatesAutoresizingMaskIntoConstraints = false
            tableView.dataSource = self
            tableView.delegate = self
            tableView.separatorStyle = .none
            tableView.showsVerticalScrollIndicator = true
            tableView.backgroundColor = .clear
            tableView.rowHeight = UITableView.automaticDimension
            tableView.estimatedRowHeight = 56
            tableView.keyboardDismissMode = .interactive
            tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellReuseId)

            view.addSubview(tableView)

            loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
            loadingIndicator.hidesWhenStopped = true
            view.addSubview(loadingIndicator)

            NSLayoutConstraint.activate([
                tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                tableView.topAnchor.constraint(equalTo: view.topAnchor),
                tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                loadingIndicator.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
                loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            ])
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            setUserScrolling(false)
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            guard shouldLockBottomOnNextLayoutPass, !isUserScrolling else { return }
            shouldLockBottomOnNextLayoutPass = false
            scrollToBottom()
        }

        func update(from config: NewChatMessagesList) {
            let oldIds = messages.map(\.id)
            let newIds = config.messages.map(\.id)
            let configChanged = isAdmin != config.isAdmin || mutedUsers != config.mutedUsers

            isLoadingOlderMessages = config.isLoadingOlderMessages
            isAdmin = config.isAdmin
            mutedUsers = config.mutedUsers
            onReachedTop = config.onReachedTop
            onReplyMessage = config.onReplyMessage
            onDMMessage = config.onDMMessage
            onDeleteMessage = config.onDeleteMessage
            onMuteUser = config.onMuteUser
            onUnmuteUser = config.onUnmuteUser
            onScrollActivityChanged = config.onScrollActivityChanged
            updateLoadingIndicator()

            if isUserScrolling {
                pendingMessages = config.messages
                return
            }

            if oldIds == newIds {
                if configChanged {
                    reloadDataWithoutAnimation()
                }
                return
            }

            applyMessages(config.messages)
        }

        private func applyMessages(_ newMessages: [ChatMessageModel]) {
            let oldIds = messages.map(\.id)
            let newIds = newMessages.map(\.id)
            let wasNearBottom = isNearBottom()
            let anchor = captureAnchorSnapshot()
            let didAppendAtBottom =
                newIds.count >= oldIds.count &&
                oldIds.first == newIds.first &&
                oldIds.last != newIds.last

            messages = newMessages
            reloadDataWithoutAnimation()

            guard !messages.isEmpty else { return }
            if !hasInitialScroll {
                hasInitialScroll = true
                scrollToBottomStabilized()
                return
            }
            if didAppendAtBottom, wasNearBottom {
                scrollToBottomStabilized()
                return
            }
            restoreAnchorSnapshot(anchor)
            maybeTriggerReachedTopIfNeeded()
        }

        private func reloadDataWithoutAnimation() {
            UIView.performWithoutAnimation {
                tableView.reloadData()
                tableView.layoutIfNeeded()
            }
        }

        private func scrollToBottom() {
            if !messages.isEmpty {
                let lastRow = messages.count - 1
                if tableView.numberOfSections > 0,
                   tableView.numberOfRows(inSection: 0) > lastRow
                {
                    tableView.scrollToRow(at: IndexPath(row: lastRow, section: 0), at: .bottom, animated: false)
                }
            }
            let minOffset = -tableView.adjustedContentInset.top
            let maxOffset = max(
                minOffset,
                tableView.contentSize.height - tableView.bounds.height + tableView.adjustedContentInset.bottom
            )
            tableView.setContentOffset(CGPoint(x: 0, y: maxOffset), animated: false)
        }

        private func scrollToBottomStabilized() {
            scrollToBottom()
            shouldLockBottomOnNextLayoutPass = true
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.isUserScrolling else { return }
                self.scrollToBottom()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                guard let self, !self.isUserScrolling else { return }
                self.scrollToBottom()
            }
        }

        private func isNearBottom() -> Bool {
            let visibleBottom = tableView.contentOffset.y + tableView.bounds.height - tableView.adjustedContentInset.bottom
            return tableView.contentSize.height - visibleBottom <= nearBottomThreshold
        }

        private func captureAnchorSnapshot() -> AnchorSnapshot? {
            guard let firstVisible = tableView.indexPathsForVisibleRows?.sorted().first,
                  firstVisible.row < messages.count
            else { return nil }

            let rowRect = tableView.rectForRow(at: firstVisible)
            let offsetFromRowTop = tableView.contentOffset.y - rowRect.minY
            return AnchorSnapshot(messageId: messages[firstVisible.row].id, offsetFromRowTop: offsetFromRowTop)
        }

        private func restoreAnchorSnapshot(_ snapshot: AnchorSnapshot?) {
            guard let snapshot,
                  let index = messages.firstIndex(where: { $0.id == snapshot.messageId })
            else { return }

            let rowRect = tableView.rectForRow(at: IndexPath(row: index, section: 0))
            let target = rowRect.minY + snapshot.offsetFromRowTop
            let minOffset = -tableView.adjustedContentInset.top
            let maxOffset = max(
                minOffset,
                tableView.contentSize.height - tableView.bounds.height + tableView.adjustedContentInset.bottom
            )
            let clampedTarget = min(max(target, minOffset), maxOffset)
            tableView.setContentOffset(CGPoint(x: 0, y: clampedTarget), animated: false)
        }

        private func setUserScrolling(_ isScrolling: Bool) {
            guard isUserScrolling != isScrolling else { return }
            isUserScrolling = isScrolling
            onScrollActivityChanged?(isScrolling)
            if !isScrolling {
                applyPendingMessagesIfNeeded()
            }
        }

        private func applyPendingMessagesIfNeeded() {
            guard let pendingMessages else { return }
            self.pendingMessages = nil
            applyMessages(pendingMessages)
        }

        private func maybeTriggerReachedTopIfNeeded() {
            guard !isLoadingOlderMessages, !messages.isEmpty else { return }
            let minOffset = -tableView.adjustedContentInset.top
            let isAtTop = tableView.contentOffset.y <= minOffset + topTriggerThreshold
            guard isAtTop, let firstId = messages.first?.id else { return }
            guard lastTopTriggerMessageId != firstId else { return }
            lastTopTriggerMessageId = firstId
            onReachedTop?()
        }

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

        private func updateLoadingIndicator() {
            if isLoadingOlderMessages {
                loadingIndicator.startAnimating()
            } else {
                loadingIndicator.stopAnimating()
            }
        }

        // MARK: UITableViewDataSource

        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            messages.count
        }

        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseId, for: indexPath)
            let message = messages[indexPath.row]
            let isSenderMuted = message.sender.map { mutedUsers.contains($0.pubkey) } ?? false

            cell.selectionStyle = .none
            cell.backgroundColor = .clear
            cell.contentConfiguration = UIHostingConfiguration {
                NewChatMessageTextRow(
                    message: message,
                    showSender: shouldShowSender(for: indexPath.row),
                    isAdmin: isAdmin,
                    isSenderMuted: isSenderMuted,
                    onReply: onReplyMessage,
                    onDM: onDMMessage,
                    onDelete: onDeleteMessage,
                    onMute: onMuteUser,
                    onUnmute: onUnmuteUser
                )
            }
            .margins(.all, 0)
            return cell
        }

        // MARK: UIScrollViewDelegate

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            setUserScrolling(true)
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            maybeTriggerReachedTopIfNeeded()
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                setUserScrolling(false)
            }
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            setUserScrolling(false)
        }
    }
}
