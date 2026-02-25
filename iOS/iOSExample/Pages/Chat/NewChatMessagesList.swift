import Foundation
import SwiftUI
import UIKit

struct NewChatMessagesList: UIViewControllerRepresentable {
    let messages: [ChatMessageModel]
    let reactionsByMessageId: [String: [MessageReactionModel]]
    let isLoadingOlderMessages: Bool
    let isAdmin: Bool
    let mutedUsers: Set<Data>
    var targetScrollMessageId: String? = nil

    // Callbacks
    var onReachedTop: (() -> Void)?
    var onTopVisibleMessageChanged: ((String?) -> Void)?
    var onReplyMessage: ((ChatMessageModel) -> Void)?
    var onDMMessage: ((String, Int32, Data, Int) -> Void)?
    var onDeleteMessage: ((ChatMessageModel) -> Void)?
    var onMuteUser: ((Data) -> Void)?
    var onUnmuteUser: ((Data) -> Void)?
    var onShowReactions: ((String) -> Void)?
    var onScrollToReply: ((String) -> Void)?
    var onScrollActivityChanged: ((Bool) -> Void)?

    // View Builders
    var renderChannelPreview: ((ParsedChannelLink, Bool, String) -> AnyView)?
    var renderDMPreview: ((ParsedDMLink, Bool, String) -> AnyView)?

    func makeUIViewController(context _: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ uiViewController: Controller, context _: Context) {
        uiViewController.update(from: self)
    }

    // MARK: - UIViewController Controller

    final class Controller: UIViewController {
        // MARK: - Types

        private enum Section {
            case main
        }

        /// Represents a unique, hashable row in the Diffable Data Source.
        /// The `renderHash` ensures that if a message's content/metadata changes,
        /// the DiffableDataSource knows to reload that specific cell.
        private enum DisplayRow: Hashable {
            case dateSeparator(id: String, date: Date, isFirst: Bool)
            case message(id: String, renderHash: Int)
        }

        private struct AnchorSnapshot {
            let rowId: String
            let offsetFromRowTop: CGFloat
        }

        private struct MessageRowMeta: Equatable {
            let showSender: Bool
            let showTimestamp: Bool
            let isFirstInGroup: Bool
        }

        // MARK: - UI Components

        private let tableView = UITableView(frame: .zero, style: .plain)
        private let loadingIndicator = UIActivityIndicatorView(style: .medium)
        private let dateSeparatorCellReuseId = "chat-date-separator-cell"
        private let messageCellReuseId = "chat-message-cell"

        // MARK: - State & Data

        private var dataSource: UITableViewDiffableDataSource<Section, DisplayRow>!
        private var messageMap: [String: ChatMessageModel] = [:]
        private var metaMap: [String: MessageRowMeta] = [:]

        // Scroll & Pagination Constants
        private let nearBottomThreshold: CGFloat = 24
        private let topTriggerThreshold: CGFloat = 8

        // Interaction State
        private var hasInitialScroll = false
        private var isUserScrolling = false
        private var isContextMenuActive = false
        private var pendingMessages: [ChatMessageModel]?

        private var lastTopTriggerMessageId: String?
        private var shouldLockBottomOnNextLayoutPass = false
        private var lastReportedTopVisibleMessageId: String?

        // Configuration State
        private var reactionsByMessageId: [String: [MessageReactionModel]] = [:]
        private var isLoadingOlderMessages = false
        private var isAdmin = false
        private var mutedUsers: Set<Data> = []
        private var targetScrollMessageId: String?

        // Closures
        var onReachedTop: (() -> Void)?
        var onTopVisibleMessageChanged: ((String?) -> Void)?
        var onReplyMessage: ((ChatMessageModel) -> Void)?
        var onDMMessage: ((String, Int32, Data, Int) -> Void)?
        var onDeleteMessage: ((ChatMessageModel) -> Void)?
        var onMuteUser: ((Data) -> Void)?
        var onUnmuteUser: ((Data) -> Void)?
        var onShowReactions: ((String) -> Void)?
        var onScrollToReply: ((String) -> Void)?
        var onScrollActivityChanged: ((Bool) -> Void)?
        var renderChannelPreview: ((ParsedChannelLink, Bool, String) -> AnyView)?
        var renderDMPreview: ((ParsedDMLink, Bool, String) -> AnyView)?

        // MARK: - Lifecycle

        override func viewDidLoad() {
            super.viewDidLoad()
            setupTableView()
            setupLoadingIndicator()
            configureDataSource()
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            setUserScrolling(false)
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            applyPendingMessagesIfNeeded()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            guard shouldLockBottomOnNextLayoutPass, !isUserScrolling else { return }
            shouldLockBottomOnNextLayoutPass = false
            scrollToBottom()
        }

        // MARK: - Setup

        private func setupTableView() {
            tableView.translatesAutoresizingMaskIntoConstraints = false
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
            NSLayoutConstraint.activate([
                tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                tableView.topAnchor.constraint(equalTo: view.topAnchor),
                tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
        }

        private func setupLoadingIndicator() {
            loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
            loadingIndicator.hidesWhenStopped = true
            view.addSubview(loadingIndicator)

            NSLayoutConstraint.activate([
                loadingIndicator.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
                loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            ])
        }

        // MARK: - Diffable Data Source Configuration

        private func configureDataSource() {
            dataSource = UITableViewDiffableDataSource<Section, DisplayRow>(tableView: tableView) { [weak self] tableView, indexPath, rowItem in
                guard let self = self else { return UITableViewCell() }

                switch rowItem {
                case let .dateSeparator(_, date, isFirst):
                    let cell = tableView.dequeueReusableCell(withIdentifier: self.dateSeparatorCellReuseId, for: indexPath)
                    cell.selectionStyle = .none
                    cell.backgroundColor = .clear
                    cell.contentConfiguration = UIHostingConfiguration {
                        DateSeparatorBadge(date: date, isFirst: isFirst)
                    }.margins(.all, 0)
                    return cell

                case let .message(id, _):
                    let cell = tableView.dequeueReusableCell(withIdentifier: self.messageCellReuseId, for: indexPath)
                    cell.selectionStyle = .none
                    cell.backgroundColor = .clear

                    guard let message = self.messageMap[id],
                          let meta = self.metaMap[id] else { return cell }

                    let isSenderMuted = message.sender.map { self.mutedUsers.contains($0.pubkey) } ?? false
                    let reactions = self.reactionsByMessageId[message.id] ?? []
                    let repliedToMessage = message.replyTo.flatMap { self.messageMap[$0]?.message }

                    // Utilize iOS 16+ UIHostingConfiguration to embed SwiftUI cleanly
                    cell.contentConfiguration = UIHostingConfiguration {
                        NewChatMessageTextRow(
                            message: message,
                            reactions: reactions,
                            showSender: meta.showSender,
                            showTimestamp: meta.showTimestamp,
                            isFirstInGroup: meta.isFirstInGroup,
                            repliedToMessage: repliedToMessage,
                            isAdmin: self.isAdmin,
                            isSenderMuted: isSenderMuted,
                            onReply: self.onReplyMessage,
                            onDM: self.onDMMessage,
                            onDelete: self.onDeleteMessage,
                            onMute: self.onMuteUser,
                            onUnmute: self.onUnmuteUser,
                            onShowReactions: { [weak self] id in self?.onShowReactions?(id) },
                            onScrollToReply: { [weak self] id in self?.onScrollToReply?(id) },
                            isHighlighted: self.targetScrollMessageId == message.id,
                            renderChannelPreview: self.renderChannelPreview,
                            renderDMPreview: self.renderDMPreview
                        )
                    }.margins(.all, 0)

                    // Highlight targeted message
                    if self.targetScrollMessageId == message.id {
                        cell.backgroundColor = UIColor(named: "haven")?.withAlphaComponent(0.2) ?? .clear
                        UIView.animate(withDuration: 1.0, delay: 0.5, options: .curveEaseOut) {
                            cell.backgroundColor = .clear
                        }
                    }
                    return cell
                }
            }
        }

        // MARK: - State Updates

        func update(from config: NewChatMessagesList) {
            reactionsByMessageId = config.reactionsByMessageId
            isLoadingOlderMessages = config.isLoadingOlderMessages
            isAdmin = config.isAdmin
            mutedUsers = config.mutedUsers

            // Assign Callbacks
            onReachedTop = config.onReachedTop
            onTopVisibleMessageChanged = config.onTopVisibleMessageChanged
            onReplyMessage = config.onReplyMessage
            onDMMessage = config.onDMMessage
            onDeleteMessage = config.onDeleteMessage
            onMuteUser = config.onMuteUser
            onUnmuteUser = config.onUnmuteUser
            onShowReactions = config.onShowReactions
            onScrollToReply = config.onScrollToReply
            onScrollActivityChanged = config.onScrollActivityChanged
            targetScrollMessageId = config.targetScrollMessageId
            renderChannelPreview = config.renderChannelPreview
            renderDMPreview = config.renderDMPreview

            updateLoadingIndicator()

            if let targetId = config.targetScrollMessageId {
                DispatchQueue.main.async { [weak self] in
                    self?.scrollToMessage(id: targetId)
                }
            }

            // Pause updates if user is actively interacting to prevent jumpy scrolling
            if isUserScrolling || isContextMenuActive || tableView.window == nil {
                pendingMessages = config.messages
                return
            }

            applyMessages(config.messages)
        }

        private func applyMessages(_ newMessages: [ChatMessageModel]) {
            let wasNearBottom = isNearBottom()
            let anchor = captureAnchorSnapshot()

            // Rebuild View Models
            let rows = buildDisplayRows(from: newMessages)

            // Generate Diffable Snapshot
            var snapshot = NSDiffableDataSourceSnapshot<Section, DisplayRow>()
            snapshot.appendSections([.main])
            snapshot.appendItems(rows, toSection: .main)

            // Apply updates without animation for chat-like instant rendering
            dataSource.apply(snapshot, animatingDifferences: false) { [weak self] in
                guard let self = self else { return }

                if !self.hasInitialScroll {
                    self.hasInitialScroll = true
                    self.scrollToBottomStabilized()
                    return
                }

                // If the user was already at the bottom, lock them to the bottom
                if wasNearBottom {
                    self.scrollToBottomStabilized()
                } else {
                    // Otherwise, maintain their exact scroll position (e.g. when paginating upwards)
                    self.restoreAnchorSnapshot(anchor)
                    self.maybeTriggerReachedTopIfNeeded()
                }
            }
        }

        // MARK: - Data Transformation

        private func buildDisplayRows(from messages: [ChatMessageModel]) -> [DisplayRow] {
            guard !messages.isEmpty else { return [] }
            let calendar = Calendar.current
            var rows: [DisplayRow] = []

            messageMap.removeAll(keepingCapacity: true)
            metaMap.removeAll(keepingCapacity: true)

            for (index, message) in messages.enumerated() {
                messageMap[message.id] = message

                // 1. Date Separators
                if shouldShowDateSeparator(for: index, in: messages) {
                    let dayDate = calendar.startOfDay(for: message.timestamp)
                    let separatorId = "date-\(Int(dayDate.timeIntervalSince1970))-\(index)"
                    rows.append(.dateSeparator(id: separatorId, date: dayDate, isFirst: index == 0))
                }

                // 2. Message Metadata
                let meta = calculateMetadata(for: message, at: index, in: messages)
                metaMap[message.id] = meta

                // 3. Render Hash (Combining message data + meta data to ensure Diffable DataSource notices changes)
                var hasher = Hasher()
                hasher.combine(message.id)
                hasher.combine(message.message)
                hasher.combine(reactionsByMessageId[message.id]?.count ?? 0)
                hasher.combine(meta.showSender)
                hasher.combine(meta.showTimestamp)

                rows.append(.message(id: message.id, renderHash: hasher.finalize()))
            }
            return rows
        }

        private func calculateMetadata(for message: ChatMessageModel, at index: Int, in messages: [ChatMessageModel]) -> MessageRowMeta {
            let calendar = Calendar.current

            let isFirstInGroup: Bool = {
                guard index > 0 else { return true }
                let previous = messages[index - 1]
                if !calendar.isDate(message.timestamp, inSameDayAs: previous.timestamp) { return true }
                return message.isIncoming != previous.isIncoming || message.sender?.id != previous.sender?.id
            }()

            let showSender: Bool = {
                guard message.isIncoming, let senderId = message.sender?.id else { return false }
                guard index > 0 else { return true }
                let previous = messages[index - 1]
                return !previous.isIncoming || previous.sender?.id != senderId
            }()

            let showTimestamp: Bool = {
                guard index < messages.count - 1 else { return true }
                let next = messages[index + 1]
                if !calendar.isDate(message.timestamp, inSameDayAs: next.timestamp) { return true }
                if message.isIncoming != next.isIncoming || message.sender?.id != next.sender?.id { return true }
                return !calendar.isDate(message.timestamp, equalTo: next.timestamp, toGranularity: .minute)
            }()

            return MessageRowMeta(showSender: showSender, showTimestamp: showTimestamp, isFirstInGroup: isFirstInGroup)
        }

        private func shouldShowDateSeparator(for index: Int, in messages: [ChatMessageModel]) -> Bool {
            guard index > 0 else { return true }
            return !Calendar.current.isDate(messages[index].timestamp, inSameDayAs: messages[index - 1].timestamp)
        }

        // MARK: - Scroll Anchoring & Navigation

        private func scrollToMessage(id: String) {
            guard let indexPath = dataSource.indexPath(for: .message(id: id, renderHash: 0)) else { return } // Hash ignored in Diffable lookup if properly equated
            tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
        }

        private func scrollToBottom() {
            let snapshot = dataSource.snapshot()
            guard snapshot.numberOfItems > 0 else { return }

            let lastIndexPath = IndexPath(row: snapshot.numberOfItems - 1, section: 0)
            tableView.scrollToRow(at: lastIndexPath, at: .bottom, animated: false)
        }

        private func scrollToBottomStabilized() {
            scrollToBottom()
            shouldLockBottomOnNextLayoutPass = true
            DispatchQueue.main.async { [weak self] in
                guard let self = self, !self.isUserScrolling else { return }
                self.scrollToBottom()
            }
        }

        private func isNearBottom() -> Bool {
            let visibleBottom = tableView.contentOffset.y + tableView.bounds.height - tableView.adjustedContentInset.bottom
            return tableView.contentSize.height - visibleBottom <= nearBottomThreshold
        }

        private func captureAnchorSnapshot() -> AnchorSnapshot? {
            guard let firstVisible = tableView.indexPathsForVisibleRows?.sorted().first,
                  let item = dataSource.itemIdentifier(for: firstVisible) else { return nil }

            let rowRect = tableView.rectForRow(at: firstVisible)
            let offsetFromRowTop = tableView.contentOffset.y - rowRect.minY

            let rowId: String
            switch item {
            case let .dateSeparator(id, _, _): rowId = id
            case let .message(id, _): rowId = id
            }

            return AnchorSnapshot(rowId: rowId, offsetFromRowTop: offsetFromRowTop)
        }

        private func restoreAnchorSnapshot(_ snapshot: AnchorSnapshot?) {
            guard let snapshot = snapshot else { return }

            // Find the item by its ID
            let items = dataSource.snapshot().itemIdentifiers
            guard let matchedItem = items.first(where: {
                switch $0 {
                case let .dateSeparator(id, _, _): return id == snapshot.rowId
                case let .message(id, _): return id == snapshot.rowId
                }
            }), let indexPath = dataSource.indexPath(for: matchedItem) else { return }

            let rowRect = tableView.rectForRow(at: indexPath)
            let target = rowRect.minY + snapshot.offsetFromRowTop
            let minOffset = -tableView.adjustedContentInset.top
            let maxOffset = max(minOffset, tableView.contentSize.height - tableView.bounds.height + tableView.adjustedContentInset.bottom)

            tableView.setContentOffset(CGPoint(x: 0, y: min(max(target, minOffset), maxOffset)), animated: false)
        }

        // MARK: - Utilities

        private func setUserScrolling(_ isScrolling: Bool) {
            guard isUserScrolling != isScrolling else { return }
            isUserScrolling = isScrolling
            onScrollActivityChanged?(isScrolling)
            if !isScrolling {
                applyPendingMessagesIfNeeded()
            }
        }

        private func applyPendingMessagesIfNeeded() {
            guard let pending = pendingMessages else { return }
            pendingMessages = nil
            applyMessages(pending)
        }

        private func updateLoadingIndicator() {
            isLoadingOlderMessages ? loadingIndicator.startAnimating() : loadingIndicator.stopAnimating()
        }

        private func maybeTriggerReachedTopIfNeeded() {
            guard !isLoadingOlderMessages else { return }
            let isAtTop = tableView.contentOffset.y <= -tableView.adjustedContentInset.top + topTriggerThreshold

            // Fetch the first message item safely
            guard isAtTop,
                  let firstItem = dataSource.snapshot().itemIdentifiers.first(where: {
                      if case .message = $0 { return true }
                      return false
                  }),
                  case let .message(firstId, _) = firstItem,
                  lastTopTriggerMessageId != firstId else { return }

            lastTopTriggerMessageId = firstId
            onReachedTop?()
        }
    }
}

// MARK: - UIScrollViewDelegate

extension NewChatMessagesList.Controller: UIScrollViewDelegate {
    func scrollViewWillBeginDragging(_: UIScrollView) {
        setUserScrolling(true)
    }

    func scrollViewDidScroll(_: UIScrollView) {
        maybeTriggerReachedTopIfNeeded()

        // Report top visible message
        if let topRow = tableView.indexPathsForVisibleRows?.sorted().first,
           let item = dataSource.itemIdentifier(for: topRow),
           case let .message(id, _) = item,
           lastReportedTopVisibleMessageId != id
        {
            lastReportedTopVisibleMessageId = id
            onTopVisibleMessageChanged?(id)
        }
    }

    func scrollViewDidEndDragging(_: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { setUserScrolling(false) }
    }

    func scrollViewDidEndDecelerating(_: UIScrollView) {
        setUserScrolling(false)
    }
}

// MARK: - UITableViewDelegate (Context Menu)

extension NewChatMessagesList.Controller: UITableViewDelegate {
    func tableView(_: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point _: CGPoint) -> UIContextMenuConfiguration? {
        guard let item = dataSource.itemIdentifier(for: indexPath),
              case let .message(id, _) = item,
              let message = messageMap[id] else { return nil }

        isContextMenuActive = true
        let displayText = message.newRenderPlainText ?? message.message // Assuming stripParagraphTags logic is applied elsewhere or via extension

        return UIContextMenuConfiguration(identifier: id as NSString, previewProvider: nil) { [weak self] _ in
            self?.makeContextMenu(for: message, displayText: displayText)
        }
    }

    func tableView(_: UITableView, willEndContextMenuInteraction _: UIContextMenuConfiguration, animator: UIContextMenuInteractionAnimating?) {
        let finish = { [weak self] in
            self?.isContextMenuActive = false
            self?.applyPendingMessagesIfNeeded() // Restores UI stream processing
        }
        animator?.addCompletion(finish) ?? finish()
    }

    private func makeContextMenu(for message: ChatMessageModel, displayText: String) -> UIMenu {
        let isSenderMuted = message.sender.map { mutedUsers.contains($0.pubkey) } ?? false
        var actions: [UIAction] = []

        actions.append(UIAction(title: "Reply", image: UIImage(systemName: "arrowshape.turn.up.left")) { [weak self] _ in
            self?.onReplyMessage?(message)
        })

        if message.isIncoming, let sender = message.sender, sender.dmToken != 0 {
            actions.append(UIAction(title: "Send DM", image: UIImage(systemName: "message")) { [weak self] _ in
                self?.onDMMessage?(sender.codename, sender.dmToken, sender.pubkey, sender.color)
            })
        }

        actions.append(UIAction(title: "Copy", image: UIImage(systemName: "doc.on.doc")) { _ in
            UIPasteboard.general.string = displayText
        })

        if isAdmin || !message.isIncoming {
            actions.append(UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                self?.onDeleteMessage?(message)
            })
        }

        if isAdmin, message.isIncoming, let sender = message.sender {
            if isSenderMuted {
                actions.append(UIAction(title: "Unmute User", image: UIImage(systemName: "speaker.wave.2")) { [weak self] _ in
                    self?.onUnmuteUser?(sender.pubkey)
                })
            } else {
                actions.append(UIAction(title: "Mute User", image: UIImage(systemName: "speaker.slash"), attributes: .destructive) { [weak self] _ in
                    self?.onMuteUser?(sender.pubkey)
                })
            }
        }

        return UIMenu(children: actions)
    }
}
