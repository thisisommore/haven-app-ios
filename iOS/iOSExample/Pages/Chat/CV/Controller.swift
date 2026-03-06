//
//  Controller.swift
//  iOSExample
//
//  Created by Om More on 06/03/26.
//

import UIKit
final class Controller: UIViewController, Deletage
{
  private struct VisibleAnchor {
    let messageId: String
    let minY: CGFloat
  }

  private var chatId: String
  private var pageSize: Int
  private let loadMoreTriggerDistanceFromTop: CGFloat = 180
  private var chatStore: ChatStore
  private var messages: Messages
  private var textRowMetaByInternalId: [Int64: TextRowMeta]
  private var currentCollectionWidth: CGFloat = 0
  private let displaySnapshotBuilder = ChatDisplaySnapshotBuilder()
  private lazy var collectionView: UICollectionView = {
    let layout = CVLayout(delegate: self)
    let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
    view.translatesAutoresizingMaskIntoConstraints = false
    view.dataSource = self
    view.delegate = self
    view.bounces = true
    view.alwaysBounceVertical = true

    view.register(TextCell.self, forCellWithReuseIdentifier: TextCell.identifier)
    view.register(ChannelLinkCell.self, forCellWithReuseIdentifier: ChannelLinkCell.identifier)
    view.register(DateCell.self, forCellWithReuseIdentifier: DateCell.identifier)
    view.register(LoadMoreMessages.self, forCellWithReuseIdentifier: LoadMoreMessages.identifier)
    view.backgroundColor = .clear
    view.contentInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
    return view
  }()
  private lazy var swipeReplyCoordinator: SwipeReplyInteractionCoordinator = {
    SwipeReplyInteractionCoordinator(
      collectionView: collectionView,
      gestureDelegate: self,
      messageAtIndexPath: { [weak self] indexPath in
        self?.replyMessage(at: indexPath)
      },
      onReplyMessage: { [weak self] message in
        self?.onReplyMessage?(message)
      }
    )
  }()
  private lazy var replyNavigationCoordinator = ReplyNavigationCoordinator(
    collectionView: collectionView
  )
  private lazy var scrollChromeCoordinator = ScrollChromeCoordinator(
    collectionView: collectionView
  )
  private lazy var observationCoordinator = ChatMessagesObservationCoordinator(
    chatId: chatId,
    pageSize: pageSize,
    chatStore: chatStore,
    snapshotBuilder: displaySnapshotBuilder,
    collectionWidthProvider: { [weak self] in
      self?.currentCollectionWidth ?? 0
    }
  )

  init(chatId: String, pageSize: Int, chatStore: ChatStore) {
    self.chatId = chatId
    self.pageSize = pageSize
    self.chatStore = chatStore
    messages = []
    textRowMetaByInternalId = [:]
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear
    view.addSubview(collectionView)
    NSLayoutConstraint.activate([
      collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      collectionView.topAnchor.constraint(equalTo: view.topAnchor),
      collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
    setupSwipeToReply()
    setupJumpToBottomButton()
    setupFloatingDateBadge()
    startMessagesObservation()
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    endSwipeToReply(triggerReply: false, animated: false)
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    currentCollectionWidth =
      collectionView.bounds.width - collectionView.adjustedContentInset.left
      - collectionView.adjustedContentInset.right
    updateJumpToBottomButtonVisibility(animated: false)
  }

  var onReplyMessage: ((ChatMessageModel) -> Void)?
  var onDMMessage: ((String, Int32, Data, Int) -> Void)?
  var onDeleteMessage: ((ChatMessageModel) -> Void)?
  var onMuteUser: ((Data) -> Void)?
  var onUnmuteUser: ((Data) -> Void)?

  func update(chatId: String, pageSize: Int, chatStore: ChatStore) {
    self.chatId = chatId
    self.pageSize = pageSize
    self.chatStore = chatStore
    observationCoordinator.updateConfiguration(chatId: chatId, pageSize: pageSize, chatStore: chatStore)

    guard isViewLoaded else { return }
  }

  func updateCallbacks(
    onReplyMessage: ((ChatMessageModel) -> Void)?,
    onDMMessage: ((String, Int32, Data, Int) -> Void)?,
    onDeleteMessage: ((ChatMessageModel) -> Void)?,
    onMuteUser: ((Data) -> Void)?,
    onUnmuteUser: ((Data) -> Void)?
  ) {
    self.onReplyMessage = onReplyMessage
    self.onDMMessage = onDMMessage
    self.onDeleteMessage = onDeleteMessage
    self.onMuteUser = onMuteUser
    self.onUnmuteUser = onUnmuteUser
  }

  private func chatMessage(from displayMessage: Message) -> ChatMessageModel? {
    switch displayMessage {
    case .Text(let message), .ChannelLink(let message, _):
      return message
    case .DateSeparator, .LoadMore:
      return nil
    }
  }

  func getSize(at: IndexPath, width: CGFloat) -> CGRect {
    let message = messages[at.item]
    switch message {
    case .Text(let textMessage):
      let rowMeta = textRowMetaByInternalId[textMessage.internalId]
      return TextCell.size(
        width: width,
        message: textMessage,
        senderDisplayName: rowMeta?.senderDisplayName
      )
    case .ChannelLink(let textMessage, let parsedLink):
      let rowMeta = textRowMetaByInternalId[textMessage.internalId]
      return ChannelLinkCell.size(
        width: width,
        message: textMessage,
        link: parsedLink,
        senderDisplayName: rowMeta?.senderDisplayName
      )
    case .DateSeparator(let date, let isFirst):
      return DateCell.size(width: width, date: date, isFirst: isFirst)
    case .LoadMore:
      guard observationCoordinator.canLoadMore else { return .zero }
      return LoadMoreMessages.size(width: width)
    }
  }

  func getXOrigin(at: IndexPath, availableWidth: CGFloat, cellWidth: CGFloat) -> CGFloat {
    guard messages.indices.contains(at.item) else { return 0 }
    switch messages[at.item] {
    case .Text(let textMessage):
      return textMessage.isIncoming ? 0 : max(0, availableWidth - cellWidth)
    case .ChannelLink(let textMessage, _):
      return textMessage.isIncoming ? 0 : max(0, availableWidth - cellWidth)
    case .DateSeparator, .LoadMore:
      return 0
    }
  }

  func spacingAfterItem(at indexPath: IndexPath) -> CGFloat {
    guard indexPath.item >= 0, indexPath.item < messages.count - 1 else { return 8 }
    let current = messages[indexPath.item]
    let next = messages[indexPath.item + 1]
    guard let currentMessage = chatMessage(from: current),
      let nextMessage = chatMessage(from: next)
    else {
      return 8
    }

    let isSameDay = Calendar.current.isDate(
      currentMessage.timestamp, inSameDayAs: nextMessage.timestamp)
    let isSameDirection = currentMessage.isIncoming == nextMessage.isIncoming
    let isSameSender = currentMessage.senderId == nextMessage.senderId

    return (isSameDay && isSameDirection && isSameSender) ? 4 : 12
  }

  private func startMessagesObservation() {
    replyNavigationCoordinator.resetPendingReplyState()
    observationCoordinator.start { [weak self] update in
      self?.applyMessagesObservationUpdate(update)
    }
  }

  private func applyMessagesObservationUpdate(_ update: ChatMessagesObservationCoordinator.Update) {
    guard
      let didLoadMoreAvailabilityChange = observationCoordinator.finishMainThreadUpdate(
        session: update.session,
        hasOlderMessages: update.hasOlderMessages
      )
    else {
      return
    }

    guard !update.isInitialSnapshot else {
      textRowMetaByInternalId = update.latestTextRowMeta
      messages = displaySnapshotBuilder.buildDisplayMessages(from: update.latest)
      if let layout = collectionView.collectionViewLayout as? CVLayout {
        layout.didInitialScrollToBottom = false
      }
      endSwipeToReply(triggerReply: false, animated: false)
      collectionView.reloadData()
      updateJumpToBottomButtonVisibility(animated: false)
      continuePendingReplyScrollIfNeeded()
      return
    }

    let oldTextRowMeta = textRowMetaByInternalId
    guard update.hasAnyChange else {
      textRowMetaByInternalId = update.latestTextRowMeta
      guard didLoadMoreAvailabilityChange, !messages.isEmpty else {
        updateJumpToBottomButtonVisibility(animated: true)
        continuePendingReplyScrollIfNeeded()
        return
      }

      let anchor = captureVisibleAnchor(in: collectionView, messages: messages)
      if let anchor, let layout = collectionView.collectionViewLayout as? CVLayout {
        if let newIndex = messages.firstIndex(where: { message in
          chatMessage(from: message)?.id == anchor.messageId
        }) {
          layout.pendingAnchor = (IndexPath(item: newIndex, section: 0), anchor.minY)
        }
      }

      UIView.performWithoutAnimation {
        collectionView.performBatchUpdates {
          collectionView.reloadItems(at: [IndexPath(item: 0, section: 0)])
        }
      }
      updateJumpToBottomButtonVisibility(animated: true)
      continuePendingReplyScrollIfNeeded()
      return
    }

    let oldMessages = messages
    let wasNearBottom = isNearBottom(in: collectionView)
    let shouldAutoScrollToBottom =
      wasNearBottom
      && didInsertBottomMessage(rawDiff: update.diff, newObservedCount: update.latest.count)
    let newMessages = displaySnapshotBuilder.buildDisplayMessages(from: update.latest)
    let displayDiff = displaySnapshotBuilder.buildDisplayDiff(
      oldObserved: update.beforeObserved,
      newObserved: update.latest,
      oldDisplay: oldMessages,
      newDisplay: newMessages,
      rawDiff: update.diff,
      oldTextRowMeta: oldTextRowMeta,
      newTextRowMeta: update.latestTextRowMeta
    )
    let anchor =
      shouldAutoScrollToBottom
      ? nil
      : captureVisibleAnchor(in: collectionView, messages: oldMessages)
    textRowMetaByInternalId = update.latestTextRowMeta
    messages = newMessages

    if let anchor, let layout = collectionView.collectionViewLayout as? CVLayout {
      if let newIndex = messages.firstIndex(where: { message in
        chatMessage(from: message)?.id == anchor.messageId
      }) {
        layout.pendingAnchor = (IndexPath(item: newIndex, section: 0), anchor.minY)
      }
    }

    endSwipeToReply(triggerReply: false, animated: false)
    UIView.performWithoutAnimation {
      collectionView.performBatchUpdates {
        if !displayDiff.deletes.isEmpty {
          collectionView.deleteItems(at: displayDiff.deletes)
        }
        if !displayDiff.inserts.isEmpty {
          collectionView.insertItems(at: displayDiff.inserts)
        }
        if !displayDiff.updates.isEmpty {
          collectionView.reloadItems(at: displayDiff.updates)
        }
      } completion: { _ in
        if shouldAutoScrollToBottom {
          self.scrollToBottom(in: self.collectionView)
        }
        self.updateJumpToBottomButtonVisibility(animated: true)
        self.continuePendingReplyScrollIfNeeded()
      }
    }

    if let deleteDebugLog = update.deleteDebugLog {
      AppLogger.chat.info("\(deleteDebugLog, privacy: .public)")
    }
    if update.detectedFalseDelete {
      AppLogger.chat.info("CV:False Delete")
    }
  }

  private func requestLoadMoreIfNeeded() {
    observationCoordinator.requestLoadMoreIfNeeded(messages: messages)
  }

  private func continuePendingReplyScrollIfNeeded() {
    replyNavigationCoordinator.continuePendingReplyScrollIfNeeded(
      messagesProvider: { [weak self] in
        self?.messages ?? []
      },
      chatMessage: { [weak self] displayMessage in
        self?.chatMessage(from: displayMessage)
      },
      scrollToReplyMessage: { [weak self] messageId in
        self?.scrollToReplyMessage(messageId)
      }
    )
  }

  private func clearReplyMessageHighlight(animated: Bool) {
    replyNavigationCoordinator.clearReplyMessageHighlight(
      messagesProvider: { [weak self] in
        self?.messages ?? []
      },
      chatMessage: { [weak self] displayMessage in
        self?.chatMessage(from: displayMessage)
      },
      animated: animated
    )
  }

  private func applyPendingReplyHighlightIfNeeded(animated: Bool) {
    replyNavigationCoordinator.applyPendingReplyHighlightIfNeeded(
      messagesProvider: { [weak self] in
        self?.messages ?? []
      },
      chatMessage: { [weak self] displayMessage in
        self?.chatMessage(from: displayMessage)
      },
      animated: animated
    )
  }

  private func scrollToReplyMessage(_ replyToMessageId: String) {
    replyNavigationCoordinator.scrollToReplyMessage(
      replyToMessageId,
      messagesProvider: { [weak self] in
        self?.messages ?? []
      },
      chatMessage: { [weak self] displayMessage in
        self?.chatMessage(from: displayMessage)
      },
      chatStore: chatStore,
      chatId: chatId,
      currentObservedLimit: { [weak self] in
        self?.observationCoordinator.getObservedLimit() ?? 0
      },
      requestObservedLimit: { [weak self] requiredObservedLimit in
        self?.observationCoordinator.requestObservedLimit(atLeast: requiredObservedLimit)
      }
    )
  }

  private func didInsertBottomMessage(rawDiff: MessageBatchDiff, newObservedCount: Int) -> Bool {
    rawDiff.inserts.contains(where: { $0.item == newObservedCount })
  }

  private func isNearBottom(in collectionView: UICollectionView, threshold: CGFloat = 48) -> Bool
  {
    let visibleBottom =
      collectionView.contentOffset.y + collectionView.bounds.height
      - collectionView.adjustedContentInset.bottom
    let remaining = collectionView.contentSize.height - visibleBottom
    return remaining <= threshold
  }

  private func scrollToBottom(in collectionView: UICollectionView, animated: Bool = false) {
    let minOffsetY = -collectionView.adjustedContentInset.top
    let maxOffsetY = max(
      minOffsetY,
      collectionView.contentSize.height
        - collectionView.bounds.height
        + collectionView.adjustedContentInset.bottom
    )
    collectionView.setContentOffset(
      CGPoint(x: collectionView.contentOffset.x, y: maxOffsetY),
      animated: animated
    )
    if !animated {
      updateJumpToBottomButtonVisibility(animated: true)
    }
  }

  deinit {
    observationCoordinator.stop()
    scrollChromeCoordinator.cleanup()
    replyNavigationCoordinator.cleanup()
  }

  private func setupSwipeToReply() {
    swipeReplyCoordinator.setup()
  }

  private func replyMessage(at indexPath: IndexPath) -> ChatMessageModel? {
    guard messages.indices.contains(indexPath.item) else { return nil }
    return chatMessage(from: messages[indexPath.item])
  }

  private func endSwipeToReply(triggerReply: Bool, animated: Bool) {
    swipeReplyCoordinator.endInteraction(triggerReply: triggerReply, animated: animated)
  }

  private func setupJumpToBottomButton() {
    scrollChromeCoordinator.setup(
      in: view,
      onJumpToBottom: { [weak self] in
        guard let self else { return }
        self.scrollToBottom(in: self.collectionView, animated: true)
      },
      isNearBottom: { [weak self] in
        guard let self else { return true }
        return self.isNearBottom(in: self.collectionView)
      }
    )
  }

  private func updateJumpToBottomButtonVisibility(animated: Bool) {
    guard isViewLoaded else { return }
    scrollChromeCoordinator.updateJumpToBottomButtonVisibility(
      isNearBottom: isNearBottom(in: collectionView),
      animated: animated
    )
  }

  private func setupFloatingDateBadge() {
    // Floating date badge is configured in setupJumpToBottomButton()
    // through ScrollChromeCoordinator.setup(...)
  }

  private func updateFloatingDateBadgeDuringScroll() {
    scrollChromeCoordinator.updateFloatingDateBadge(date: currentTopVisibleDate())
  }

  private func currentTopVisibleDate() -> Date? {
    let visible = collectionView.indexPathsForVisibleItems.sorted { lhs, rhs in
      let leftY =
        collectionView.layoutAttributesForItem(at: lhs)?.frame.minY ?? .greatestFiniteMagnitude
      let rightY =
        collectionView.layoutAttributesForItem(at: rhs)?.frame.minY ?? .greatestFiniteMagnitude
      return leftY < rightY
    }

    for indexPath in visible {
      guard messages.indices.contains(indexPath.item) else { continue }
      switch messages[indexPath.item] {
      case .DateSeparator(let date, _):
        return date
      case .Text(let message), .ChannelLink(let message, _):
        return Calendar.current.startOfDay(for: message.timestamp)
      case .LoadMore:
        continue
      }
    }
    return nil
  }

  private func captureVisibleAnchor(
    in collectionView: UICollectionView, messages: Messages
  ) -> VisibleAnchor? {
    let visible = collectionView.indexPathsForVisibleItems
    guard !visible.isEmpty else { return nil }

    let anchorCandidate = visible.compactMap { indexPath -> VisibleAnchor? in
      guard indexPath.item >= 0, indexPath.item < messages.count else { return nil }
      guard let message = chatMessage(from: messages[indexPath.item]) else { return nil }
      let minY = collectionView.layoutAttributesForItem(at: indexPath)?.frame.minY
      guard let minY else { return nil }
      return VisibleAnchor(messageId: message.id, minY: minY)
    }.max(by: { $0.minY < $1.minY })

    guard let anchorCandidate else { return nil }
    return anchorCandidate
  }

  func numberOfItemsInCollectionView() -> Int {
    messages.count
  }

  func makeCell(for indexPath: IndexPath, in collectionView: UICollectionView)
    -> UICollectionViewCell
  {
    let message = messages[indexPath.item]
    switch message {
    case .Text(let textMessage):
      let cell =
        collectionView.dequeueReusableCell(
          withReuseIdentifier: TextCell.identifier, for: indexPath)
        as! TextCell
      cell.contentView.frame.origin.x = 0
      let rowMeta = textRowMetaByInternalId[textMessage.internalId]
      cell.render(
        message: textMessage,
        senderDisplayName: rowMeta?.senderDisplayName,
        senderColor: rowMeta?.senderColor
      )
      cell.setReplyTargetHighlighted(
        replyNavigationCoordinator.isMessageHighlighted(textMessage.id),
        animated: false
      )
      if let replyToMessageId = textMessage.replyTo, rowMeta?.replyPreviewText != nil {
        cell.onReplyPreviewTap = { [weak self] in
          self?.scrollToReplyMessage(replyToMessageId)
        }
      } else {
        cell.onReplyPreviewTap = nil
      }
      return cell
    case .ChannelLink(let textMessage, let parsedLink):
      let cell =
        collectionView.dequeueReusableCell(
          withReuseIdentifier: ChannelLinkCell.identifier, for: indexPath
        )
        as! ChannelLinkCell
      cell.contentView.frame.origin.x = 0
      let rowMeta = textRowMetaByInternalId[textMessage.internalId]
      cell.render(
        message: textMessage,
        link: parsedLink,
        senderDisplayName: rowMeta?.senderDisplayName,
        senderColor: rowMeta?.senderColor
      )
      cell.setReplyTargetHighlighted(
        replyNavigationCoordinator.isMessageHighlighted(textMessage.id),
        animated: false
      )
      if let replyToMessageId = textMessage.replyTo, rowMeta?.replyPreviewText != nil {
        cell.onReplyPreviewTap = { [weak self] in
          self?.scrollToReplyMessage(replyToMessageId)
        }
      } else {
        cell.onReplyPreviewTap = nil
      }
      return cell
    case .DateSeparator(let date, let isFirst):
      let cell =
        collectionView.dequeueReusableCell(
          withReuseIdentifier: DateCell.identifier, for: indexPath)
        as! DateCell
      cell.contentView.frame.origin.x = 0
      cell.render(date: date, isFirst: isFirst)
      return cell
    case .LoadMore:
      let cell =
        collectionView.dequeueReusableCell(
          withReuseIdentifier: LoadMoreMessages.identifier, for: indexPath
        )
        as! LoadMoreMessages
      cell.contentView.frame.origin.x = 0
      cell.isHidden = !observationCoordinator.canLoadMore
      cell.render()
      return cell
    }
  }

  func handleWillDisplayCell(at indexPath: IndexPath) {
    _ = indexPath
  }

  func makeContextMenuConfiguration(
    for indexPath: IndexPath,
    in collectionView: UICollectionView,
    point: CGPoint
  ) -> UIContextMenuConfiguration? {
    _ = collectionView
    _ = point
    guard messages.indices.contains(indexPath.item) else { return nil }
    guard let message = chatMessage(from: messages[indexPath.item]) else { return nil }

    let displayText = message.newRenderPlainText ?? message.message
    let sender = message.senderId.flatMap { try? self.chatStore.fetchSender(id: $0) }
    let isAdmin = (try? self.chatStore.fetchChat(id: self.chatId)?.isAdmin) ?? false
    // For now, muted users logic is not fully wired in CV, but we can assume false or fetch
    let isSenderMuted = false

    return UIContextMenuConfiguration(identifier: message.id as NSString, previewProvider: nil) {
      [weak self] _ in
      var actions: [UIAction] = []

      actions.append(
        UIAction(title: "Reply", image: UIImage(systemName: "arrowshape.turn.up.left")) {
          [weak self] _ in
          self?.onReplyMessage?(message)
        })

      if message.isIncoming, let sender = sender, sender.dmToken != 0 {
        actions.append(
          UIAction(title: "Send DM", image: UIImage(systemName: "message")) { [weak self] _ in
            self?.onDMMessage?(sender.codename, sender.dmToken, sender.pubkey, sender.color)
          })
      }

      actions.append(
        UIAction(title: "Copy", image: UIImage(systemName: "doc.on.doc")) { _ in
          UIPasteboard.general.string = displayText
        })

      if isAdmin || !message.isIncoming {
        actions.append(
          UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive)
          { [weak self] _ in
            self?.onDeleteMessage?(message)
          })
      }

      if isAdmin, message.isIncoming, let sender = sender {
        if isSenderMuted {
          actions.append(
            UIAction(title: "Unmute User", image: UIImage(systemName: "speaker.wave.2")) {
              [weak self] _ in
              self?.onUnmuteUser?(sender.pubkey)
            })
        } else {
          actions.append(
            UIAction(
              title: "Mute User", image: UIImage(systemName: "speaker.slash"),
              attributes: .destructive
            ) { [weak self] _ in
              self?.onMuteUser?(sender.pubkey)
            })
        }
      }

      return UIMenu(children: actions)
    }
  }

  func shouldBeginGestureRecognizer(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    swipeReplyCoordinator.gestureRecognizerShouldBegin(gestureRecognizer)
  }

  func shouldRecognizeSimultaneously(
    _ gestureRecognizer: UIGestureRecognizer,
    with otherGestureRecognizer: UIGestureRecognizer
  ) -> Bool {
    swipeReplyCoordinator.shouldRecognizeSimultaneously(
      gestureRecognizer,
      with: otherGestureRecognizer
    )
  }

  func handleScrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    guard scrollView === collectionView else { return }
    endSwipeToReply(triggerReply: false, animated: false)
    updateFloatingDateBadgeDuringScroll()
    updateJumpToBottomButtonVisibility(animated: true)
  }

  func handleScrollViewDidScroll(_ scrollView: UIScrollView) {
    guard scrollView === collectionView else { return }
    updateJumpToBottomButtonVisibility(animated: true)
    guard scrollView.isDragging || scrollView.isDecelerating else { return }
    updateFloatingDateBadgeDuringScroll()

    let contentHeight = scrollView.contentSize.height
    let visibleHeight = scrollView.bounds.height
    guard contentHeight > visibleHeight else { return }

    let scrollY = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
    if scrollY < loadMoreTriggerDistanceFromTop {
      requestLoadMoreIfNeeded()
    }
  }

  func handleScrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
    guard scrollView === collectionView else { return }
    updateJumpToBottomButtonVisibility(animated: true)
    applyPendingReplyHighlightIfNeeded(animated: true)
  }
}
