import Foundation
import SwiftUI
import UIKit

struct NewChatMessagesList: UIViewControllerRepresentable {
    let messages: [ChatMessageModel]
    let isLoadingOlderMessages: Bool
    let isAdmin: Bool
    let mutedUsers: Set<Data>
    var onReachedTop: (() -> Void)?
    var onTopVisibleMessageChanged: ((String?) -> Void)?
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
            let rowId: String
            let offsetFromRowTop: CGFloat
        }

        private struct MessageRowMeta {
            let showSender: Bool
            let showTimestamp: Bool
        }

        private enum DisplayRow {
            case dateSeparator(id: String, date: Date, isFirst: Bool)
            case message(id: String, messageIndex: Int)

            var id: String {
                switch self {
                case let .dateSeparator(id, _, _):
                    return id
                case let .message(id, _):
                    return id
                }
            }
        }

        private let tableView = UITableView(frame: .zero, style: .plain)
        private let loadingIndicator = UIActivityIndicatorView(style: .medium)
        private let messageCellReuseId = "chat-message-cell"
        private let dateSeparatorCellReuseId = "chat-date-separator-cell"
        private let nearBottomThreshold: CGFloat = 24
        private let topTriggerThreshold: CGFloat = 8

        private var hasInitialScroll = false
        private var isUserScrolling = false
        private var pendingMessages: [ChatMessageModel]?
        private var messages: [ChatMessageModel] = []
        private var displayRows: [DisplayRow] = []
        private var messageRowMeta: [MessageRowMeta] = []
        private var lastTopTriggerMessageId: String?
        private var shouldLockBottomOnNextLayoutPass = false
        private var lastReportedTopVisibleMessageId: String?

        private var isLoadingOlderMessages = false
        private var isAdmin = false
        private var mutedUsers: Set<Data> = []
        private var onReachedTop: (() -> Void)?
        private var onTopVisibleMessageChanged: ((String?) -> Void)?
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
            tableView.register(UITableViewCell.self, forCellReuseIdentifier: messageCellReuseId)
            tableView.register(UITableViewCell.self, forCellReuseIdentifier: dateSeparatorCellReuseId)

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
            onTopVisibleMessageChanged = config.onTopVisibleMessageChanged
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
            displayRows = buildDisplayRows(from: newMessages)
            messageRowMeta = buildMessageRowMeta(from: newMessages)
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
            if !displayRows.isEmpty {
                let lastRow = displayRows.count - 1
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
                  firstVisible.row < displayRows.count
            else { return nil }

            let rowRect = tableView.rectForRow(at: firstVisible)
            let offsetFromRowTop = tableView.contentOffset.y - rowRect.minY
            return AnchorSnapshot(rowId: displayRows[firstVisible.row].id, offsetFromRowTop: offsetFromRowTop)
        }

        private func restoreAnchorSnapshot(_ snapshot: AnchorSnapshot?) {
            guard let snapshot,
                  let index = displayRows.firstIndex(where: { $0.id == snapshot.rowId })
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

        private func reportTopVisibleMessageIfNeeded() {
            guard let topMessageId = topVisibleMessageId() else { return }
            guard lastReportedTopVisibleMessageId != topMessageId else { return }
            lastReportedTopVisibleMessageId = topMessageId
            onTopVisibleMessageChanged?(topMessageId)
        }

        private func topVisibleMessageId() -> String? {
            guard let visibleRows = tableView.indexPathsForVisibleRows?.sorted() else { return nil }
            for indexPath in visibleRows {
                guard indexPath.row < displayRows.count else { continue }
                if case let .message(id, _) = displayRows[indexPath.row] {
                    return id
                }
            }
            return nil
        }

        private func shouldShowSender(for index: Int) -> Bool {
            guard index >= 0, index < messageRowMeta.count else { return false }
            return messageRowMeta[index].showSender
        }

        private func shouldShowTimestamp(for index: Int) -> Bool {
            guard index >= 0, index < messageRowMeta.count else { return false }
            return messageRowMeta[index].showTimestamp
        }

        private func shouldShowDateSeparator(for index: Int) -> Bool {
            guard index < messages.count else { return false }
            guard index > 0 else { return true }
            let calendar = Calendar.current
            return !calendar.isDate(messages[index].timestamp, inSameDayAs: messages[index - 1].timestamp)
        }

        private func buildDisplayRows(from messages: [ChatMessageModel]) -> [DisplayRow] {
            guard !messages.isEmpty else { return [] }
            let calendar = Calendar.current
            var rows: [DisplayRow] = []
            for (index, message) in messages.enumerated() {
                if shouldShowDateSeparator(for: index) {
                    let dayDate = calendar.startOfDay(for: message.timestamp)
                    let separatorId = "date-\(Int(dayDate.timeIntervalSince1970))-\(index)"
                    rows.append(.dateSeparator(id: separatorId, date: dayDate, isFirst: index == 0))
                }
                rows.append(.message(id: message.id, messageIndex: index))
            }
            return rows
        }

        private func buildMessageRowMeta(from messages: [ChatMessageModel]) -> [MessageRowMeta] {
            guard !messages.isEmpty else { return [] }
            let calendar = Calendar.current
            let count = messages.count

            return messages.enumerated().map { index, message in
                let showSender: Bool = {
                    guard message.isIncoming, let senderId = message.sender?.id else {
                        return false
                    }
                    guard index > 0 else { return true }
                    let previous = messages[index - 1]
                    if !previous.isIncoming {
                        return true
                    }
                    return previous.sender?.id != senderId
                }()

                let showTimestamp: Bool = {
                    guard index < count - 1 else { return true }
                    let next = messages[index + 1]

                    if !calendar.isDate(message.timestamp, inSameDayAs: next.timestamp) {
                        return true
                    }
                    if message.isIncoming != next.isIncoming {
                        return true
                    }
                    if message.sender?.id != next.sender?.id {
                        return true
                    }
                    return !calendar.isDate(
                        message.timestamp,
                        equalTo: next.timestamp,
                        toGranularity: .minute
                    )
                }()

                return MessageRowMeta(showSender: showSender, showTimestamp: showTimestamp)
            }
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
            displayRows.count
        }

        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let row = displayRows[indexPath.row]
            let reuseIdentifier: String = {
                switch row {
                case .dateSeparator:
                    return dateSeparatorCellReuseId
                case .message:
                    return messageCellReuseId
                }
            }()
            let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)

            cell.selectionStyle = .none
            cell.backgroundColor = .clear
            switch row {
            case let .dateSeparator(_, date, isFirst):
                cell.contentConfiguration = UIHostingConfiguration {
                    DateSeparatorBadge(
                        date: date,
                        isFirst: isFirst
                    )
                }
                .margins(.all, 0)

            case let .message(_, messageIndex):
                let message = messages[messageIndex]
                let isSenderMuted = message.sender.map { mutedUsers.contains($0.pubkey) } ?? false
                cell.contentConfiguration = UIHostingConfiguration {
                    NewChatMessageTextRow(
                        message: message,
                        showSender: shouldShowSender(for: messageIndex),
                        showTimestamp: shouldShowTimestamp(for: messageIndex),
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
            }
            return cell
        }

        // MARK: UIScrollViewDelegate

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            setUserScrolling(true)
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            maybeTriggerReachedTopIfNeeded()
            reportTopVisibleMessageIfNeeded()
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
