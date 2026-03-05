import GRDB
import SwiftData
import SwiftUI
import UIKit

enum Message {
  case Text(ChatMessageModel)
  case LoadMore
}

typealias Messages = [Message]

struct MaxChat: UIViewControllerRepresentable {
  @EnvironmentObject private var chatStore: ChatStore
  let chatId: String
  let pageSize: Int = 50

  init(chatId: String) {
    self.chatId = chatId
  }

  func makeUIViewController(context _: Context) -> Controller {
    Controller(chatId: chatId, pageSize: pageSize, chatStore: chatStore)
  }

  func updateUIViewController(_ uiViewController: Controller, context _: Context) {
    uiViewController.update(chatId: chatId, pageSize: pageSize, chatStore: chatStore)
  }

  final class Controller: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate,
    Deletage
  {
    private struct VisibleAnchor {
      let messageId: String
      let minY: CGFloat
    }

    private struct MessageBatchDiff {
      let inserts: [IndexPath]
      let deletes: [IndexPath]
      let updates: [IndexPath]
    }

    private struct ObservedMessagesPage {
      let messages: [ChatMessageModel]
      let hasOlderMessages: Bool
    }

    private var chatId: String
    private var pageSize: Int
    private let loadMorePageSize = 20
    private let observedLimitLock = NSLock()
    private var currentObservedLimit: Int
    private var canLoadMore = true
    private var isLoadingMore = false
    private var chatStore: ChatStore
    private var messages: Messages
    private var lastObservedMessages: [ChatMessageModel]
    private let updateWorkQueue = DispatchQueue(
      label: "cv.messages.update-work", qos: .userInitiated)
    private var observationSession = 0
    private var cancelMessagesObservation: (() -> Void)?
    private var didReceiveInitialMessagesSnapshot = false
    private var currentCollectionWidth: CGFloat = 0
    private lazy var collectionView: UICollectionView = {
      let layout = CVLayout(delegate: self)
      let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
      view.translatesAutoresizingMaskIntoConstraints = false
      view.dataSource = self
      view.delegate = self
      view.bounces = true
      view.alwaysBounceVertical = true

      view.register(TextCell.self, forCellWithReuseIdentifier: TextCell.identifier)
      view.register(LoadMoreMessages.self, forCellWithReuseIdentifier: LoadMoreMessages.identifier)
      view.backgroundColor = .clear
      view.contentInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
      return view
    }()

    init(chatId: String, pageSize: Int, chatStore: ChatStore) {
      self.chatId = chatId
      self.pageSize = pageSize
      currentObservedLimit = pageSize
      self.chatStore = chatStore
      messages = []
      lastObservedMessages = []
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
      startMessagesObservation()
    }

    override func viewDidLayoutSubviews() {
      super.viewDidLayoutSubviews()
      currentCollectionWidth =
        collectionView.bounds.width - collectionView.adjustedContentInset.left
        - collectionView.adjustedContentInset.right
    }

    func update(chatId: String, pageSize: Int, chatStore: ChatStore) {
      self.chatId = chatId
      self.pageSize = pageSize
      self.chatStore = chatStore

      guard isViewLoaded else { return }
    }

    func getSize(at: IndexPath, width: CGFloat) -> CGRect {
      let message = messages[at.item]
      switch message {
      case .Text(let textMessage):
        return TextCell.size(width: width, message: textMessage)
      case .LoadMore:
        guard canLoadMore else { return .zero }
        return LoadMoreMessages.size(width: width)
      }
    }

    private func startMessagesObservation() {
      cancelMessagesObservation?()
      cancelMessagesObservation = nil
      observationSession += 1
      let session = observationSession
      didReceiveInitialMessagesSnapshot = false
      setCurrentObservedLimit(pageSize)
      canLoadMore = true
      isLoadingMore = false
      lastObservedMessages = messages.compactMap { message in
        guard case .Text(let textMessage) = message else { return nil }
        return textMessage
      }

      let observedChatId = chatId
      let dbQueue = chatStore.dbQueue
      let observer = ChatMessagesTransactionObserver2(
        tableName: ChatMessageModel.databaseTableName,
        onPublishedChanges: { [weak self] in
          guard let self else { return }
          self.processMessagesObservationChange(
            session: session,
            observedChatId: observedChatId,
            observedLimit: self.getCurrentObservedLimit(),
            dbQueue: dbQueue
          )
        }
      )
      dbQueue.add(transactionObserver: observer, extent: .observerLifetime)
      observer.triggerInitialPublish()
      cancelMessagesObservation = {
        dbQueue.remove(transactionObserver: observer)
        observer.stop()
      }
    }

    private func processMessagesObservationChange(
      session: Int,
      observedChatId: String,
      observedLimit: Int,
      dbQueue: DatabaseQueue
    ) {
      updateWorkQueue.async { [weak self] in
        guard let self else { return }
        guard self.observationSession == session else { return }
        guard observedLimit == self.getCurrentObservedLimit() else { return }

        let latestPage = self.fetchLatestObservedMessages(
          chatId: observedChatId,
          limit: observedLimit,
          dbQueue: dbQueue
        )
        let latest = latestPage.messages
        let hasOlderMessages = latestPage.hasOlderMessages

        let width = self.currentCollectionWidth
        if width > 0 {
          for msg in latest {
            _ = TextCell.size(width: width, message: msg)
          }
        }

        guard self.didReceiveInitialMessagesSnapshot else {
          self.didReceiveInitialMessagesSnapshot = true
          self.lastObservedMessages = latest
          DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard self.observationSession == session else { return }
            guard observedLimit == self.getCurrentObservedLimit() else { return }
            self.canLoadMore = hasOlderMessages
            self.isLoadingMore = false
            self.messages = [.LoadMore] + latest.map { .Text($0) }
            if let layout = self.collectionView.collectionViewLayout as? CVLayout {
              layout.didInitialScrollToBottom = false
            }
            self.collectionView.reloadData()
          }
          return
        }

        let beforeObserved = self.lastObservedMessages
        self.lastObservedMessages = latest

        let diff = self.buildBatchDiff(from: beforeObserved, to: latest)
        let hasAnyChange =
          !diff.inserts.isEmpty || !diff.deletes.isEmpty || !diff.updates.isEmpty
        let detectedFalseDelete =
          hasAnyChange
          ? self.detectFalseDeleteWindowShift(
            from: beforeObserved,
            to: latest,
            diff: diff,
            pageLimit: observedLimit
          )
          : false

        var deleteDebugLog: String?
        if hasAnyChange, !diff.deletes.isEmpty {
          let deletedItems = diff.deletes.map(\.item).map(String.init).joined(separator: ",")
          let deletedInternalIds = diff.deletes.compactMap { indexPath -> String? in
            let index = indexPath.item - 1
            guard beforeObserved.indices.contains(index) else { return nil }
            return String(beforeObserved[index].internalId)
          }.joined(separator: ",")
          let beforeSnapshot = self.describeMessagesForDeleteDebug(beforeObserved)
          let afterSnapshot = self.describeMessagesForDeleteDebug(latest)
          deleteDebugLog =
            "CV: GRDB delete-debug chat \(observedChatId) deleteItems[\(deletedItems)] deleteInternalIds[\(deletedInternalIds)] before[\(beforeSnapshot)] after[\(afterSnapshot)]"
        }

        DispatchQueue.main.async { [weak self] in
          guard let self else { return }
          guard self.observationSession == session else { return }
          guard observedLimit == self.getCurrentObservedLimit() else { return }
          let didLoadMoreAvailabilityChange = self.canLoadMore != hasOlderMessages
          self.canLoadMore = hasOlderMessages
          self.isLoadingMore = false
          guard hasAnyChange else {
            guard didLoadMoreAvailabilityChange, !self.messages.isEmpty else { return }

            let anchor = self.captureVisibleAnchor(in: self.collectionView, messages: self.messages)
            if let anchor, let layout = self.collectionView.collectionViewLayout as? CVLayout {
              if let newIndex = self.messages.firstIndex(where: { message in
                guard case .Text(let textMessage) = message else { return false }
                return textMessage.id == anchor.messageId
              }) {
                layout.pendingAnchor = (IndexPath(item: newIndex, section: 0), anchor.minY)
              }
            }

            UIView.performWithoutAnimation {
              self.collectionView.performBatchUpdates {
                self.collectionView.reloadItems(at: [IndexPath(item: 0, section: 0)])
              }
            }
            return
          }

          let oldMessages = self.messages
          let newMessages: Messages = [.LoadMore] + latest.map { .Text($0) }
          let anchor = self.captureVisibleAnchor(in: self.collectionView, messages: oldMessages)
          self.messages = newMessages

          if let anchor, let layout = self.collectionView.collectionViewLayout as? CVLayout {
            if let newIndex = self.messages.firstIndex(where: { message in
              guard case .Text(let textMessage) = message else { return false }
              return textMessage.id == anchor.messageId
            }) {
              layout.pendingAnchor = (IndexPath(item: newIndex, section: 0), anchor.minY)
            }
          }

          UIView.performWithoutAnimation {
            self.collectionView.performBatchUpdates {
              if !diff.deletes.isEmpty {
                self.collectionView.deleteItems(at: diff.deletes)
              }
              if !diff.inserts.isEmpty {
                self.collectionView.insertItems(at: diff.inserts)
              }
              if !diff.updates.isEmpty {
                self.collectionView.reloadItems(at: diff.updates)
              }
            } completion: { _ in
            }
          }

          if let deleteDebugLog {
            AppLogger.chat.info("\(deleteDebugLog, privacy: .public)")
          }
          if detectedFalseDelete {
            AppLogger.chat.info("CV:False Delete")
          }
        }
      }
    }

    private func fetchLatestObservedMessages(
      chatId: String,
      limit: Int,
      dbQueue: DatabaseQueue
    ) -> ObservedMessagesPage {
      do {
        return try dbQueue.read { db in
          let rows =
            try ChatMessageModel
            .filter(Column("chatId") == chatId)
            .order(Column("timestamp").desc, Column("internalId").asc)
            .limit(limit)
            .fetchAll(db)
          let messages = Array(rows.reversed())
          let hasOlderMessages: Bool
          if let oldestMessage = messages.first {
            hasOlderMessages =
              try ChatMessageModel
              .filter(Column("chatId") == chatId)
              .filter(
                Column("timestamp") < oldestMessage.timestamp
                  || (Column("timestamp") == oldestMessage.timestamp
                    && Column("internalId") < oldestMessage.internalId)
              )
              .limit(1)
              .fetchOne(db) != nil
          } else {
            hasOlderMessages = false
          }

          return ObservedMessagesPage(messages: messages, hasOlderMessages: hasOlderMessages)
        }
      } catch {
        AppLogger.chat.error(
          "CV: GRDB messages fetch failed for chat \(chatId, privacy: .public): \(error.localizedDescription, privacy: .public)"
        )
        return ObservedMessagesPage(messages: [], hasOlderMessages: false)
      }
    }

    private func requestLoadMoreIfNeeded() {
      guard canLoadMore else { return }
      guard !isLoadingMore else { return }
      guard observationSession > 0 else { return }
      guard !messages.isEmpty else { return }
      guard case .LoadMore = messages[0] else { return }

      isLoadingMore = true
      let nextLimit = increaseCurrentObservedLimit(by: loadMorePageSize)
      processMessagesObservationChange(
        session: observationSession,
        observedChatId: chatId,
        observedLimit: nextLimit,
        dbQueue: chatStore.dbQueue
      )
    }

    private func getCurrentObservedLimit() -> Int {
      observedLimitLock.lock()
      defer { observedLimitLock.unlock() }
      return currentObservedLimit
    }

    private func setCurrentObservedLimit(_ newValue: Int) {
      observedLimitLock.lock()
      currentObservedLimit = newValue
      observedLimitLock.unlock()
    }

    private func increaseCurrentObservedLimit(by value: Int) -> Int {
      observedLimitLock.lock()
      currentObservedLimit += value
      let updatedValue = currentObservedLimit
      observedLimitLock.unlock()
      return updatedValue
    }

    deinit {
      cancelMessagesObservation?()
      cancelMessagesObservation = nil
    }

    private func buildBatchDiff(from old: [ChatMessageModel], to new: [ChatMessageModel])
      -> MessageBatchDiff
    {
      let oldByInternalId = Dictionary(
        uniqueKeysWithValues: old.enumerated().map { ($1.internalId, ($0, $1)) }
      )
      let newByInternalId = Dictionary(
        uniqueKeysWithValues: new.enumerated().map { ($1.internalId, ($0, $1)) }
      )

      let deletes: [IndexPath] = old.enumerated().compactMap { index, message in
        guard newByInternalId[message.internalId] == nil else { return nil }
        return IndexPath(item: index + 1, section: 0)
      }.sorted { left, right in
        left.item < right.item
      }

      let inserts: [IndexPath] = new.enumerated().compactMap { index, message in
        guard oldByInternalId[message.internalId] == nil else { return nil }
        return IndexPath(item: index + 1, section: 0)
      }.sorted { left, right in
        left.item < right.item
      }

      let updates =
        new
        .enumerated()
        .compactMap { index, message -> IndexPath? in
          guard let (_, oldMessage) = oldByInternalId[message.internalId] else { return nil }
          guard oldMessage.replyTo != message.replyTo else { return nil }
          return IndexPath(item: index + 1, section: 0)
        }
        .sorted(by: { $0.item < $1.item })

      return MessageBatchDiff(inserts: inserts, deletes: deletes, updates: updates)
    }

    private func describeMessagesForDeleteDebug(_ values: [ChatMessageModel]) -> String {
      values.enumerated().map { index, message in
        let replyTo = message.replyTo ?? "nil"
        return
          "#\(index + 1){iid:\(message.internalId),id:\(message.id),replyTo:\(replyTo),status:\(message.statusRaw)}"
      }.joined(separator: ", ")
    }

    private func detectFalseDeleteWindowShift(
      from old: [ChatMessageModel],
      to new: [ChatMessageModel],
      diff: MessageBatchDiff,
      pageLimit: Int
    ) -> Bool {
      guard !diff.deletes.isEmpty, !diff.inserts.isEmpty else { return false }
      guard old.count == pageLimit, new.count == pageLimit else { return false }

      let deletedMessages = diff.deletes.compactMap { indexPath -> ChatMessageModel? in
        let index = indexPath.item - 1
        guard old.indices.contains(index) else { return nil }
        return old[index]
      }
      let insertedMessages = diff.inserts.compactMap { indexPath -> ChatMessageModel? in
        let index = indexPath.item - 1
        guard new.indices.contains(index) else { return nil }
        return new[index]
      }

      guard
        let newestDeletedTimestamp = deletedMessages.map(\.timestamp).max(),
        let newestInsertedTimestamp = insertedMessages.map(\.timestamp).max()
      else { return false }

      return newestDeletedTimestamp > newestInsertedTimestamp
    }

    private func captureVisibleAnchor(
      in collectionView: UICollectionView, messages: Messages
    ) -> VisibleAnchor? {
      let visible = collectionView.indexPathsForVisibleItems
      guard !visible.isEmpty else { return nil }

      let anchorCandidate = visible.compactMap { indexPath -> VisibleAnchor? in
        guard indexPath.item >= 0, indexPath.item < messages.count else { return nil }
        guard case .Text(let message) = messages[indexPath.item] else { return nil }
        let minY = collectionView.layoutAttributesForItem(at: indexPath)?.frame.minY
        guard let minY else { return nil }
        return VisibleAnchor(messageId: message.id, minY: minY)
      }.min(by: { $0.minY < $1.minY })

      guard let anchorCandidate else { return nil }
      return anchorCandidate
    }

    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
      messages.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath)
      -> UICollectionViewCell
    {
      let message = messages[indexPath.item]
      switch message {
      case .Text(let textMessage):
        let cell =
          collectionView.dequeueReusableCell(
            withReuseIdentifier: TextCell.identifier, for: indexPath)
          as! TextCell
        cell.render(message: textMessage)
        return cell
      case .LoadMore:
        let cell =
          collectionView.dequeueReusableCell(
            withReuseIdentifier: LoadMoreMessages.identifier, for: indexPath
          )
          as! LoadMoreMessages
        cell.isHidden = !canLoadMore
        cell.render()
        return cell
      }
    }

    func collectionView(
      _: UICollectionView,
      willDisplay _: UICollectionViewCell,
      forItemAt indexPath: IndexPath
    ) {
      guard indexPath.item == 0 else { return }
      guard indexPath.item < messages.count else { return }
      guard case .LoadMore = messages[indexPath.item] else { return }
      requestLoadMoreIfNeeded()
    }
  }
}

protocol Deletage {
  func getSize(at: IndexPath, width: CGFloat) -> CGRect
}

class CVLayout: UICollectionViewLayout {
  var topOffset: CGFloat = 0
  var height: CGFloat = 0
  var delegate: Deletage
  var didInitialScrollToBottom = false
  var pendingAnchor: (indexPath: IndexPath, oldMinY: CGFloat)?

  init(delegate: Deletage) {
    self.delegate = delegate
    super.init()
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // 1. Define the overall scroll area (just 5x5)
  override var collectionViewContentSize: CGSize {
    guard let cv = collectionView else { return .zero }
    let w = cv.bounds.width - cv.adjustedContentInset.left - cv.adjustedContentInset.right
    return CGSize(width: w, height: height)
  }

  var cache = [UICollectionViewLayoutAttributes]()
  override func prepare() {
    guard let collectionView else {
      fatalError("collectionView must exist")
    }
    cache.removeAll(keepingCapacity: true)

    // First pass: calculate total content height
    var totalContentHeight: CGFloat = 0
    let w =
      collectionView.bounds.width - collectionView.adjustedContentInset.left
      - collectionView.adjustedContentInset.right
    let numberOfItems = collectionView.numberOfItems(inSection: 0)
    let cellSpacing: CGFloat = 8

    var sizes = [CGSize]()
    sizes.reserveCapacity(numberOfItems)

    for item in 0..<numberOfItems {
      let indexPath = IndexPath(item: item, section: 0)
      let size = delegate.getSize(at: indexPath, width: w)
      sizes.append(size.size)
      totalContentHeight += size.height + cellSpacing
    }

    // Determine starting Y offset to push content to bottom if it's smaller than the view
    let visibleHeight =
      collectionView.bounds.height - collectionView.adjustedContentInset.top
      - collectionView.adjustedContentInset.bottom
    topOffset = max(0, visibleHeight - totalContentHeight)
    height = max(totalContentHeight, visibleHeight)

    // Second pass: create attributes with the adjusted starting offset
    for item in 0..<numberOfItems {
      let indexPath = IndexPath(item: item, section: 0)
      let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
      let size = sizes[item]
      attributes.frame = CGRect(x: 0, y: topOffset, width: size.width, height: size.height)
      topOffset += size.height + cellSpacing
      cache.append(attributes)
    }

    guard collectionView.bounds.width > 0 else { return }

    if !didInitialScrollToBottom {
      collectionView.setContentOffset(
        CGPoint(
          x: collectionView.contentOffset.x,
          y: height - collectionView.bounds.height
            + collectionView.adjustedContentInset.bottom),
        animated: false
      )
      didInitialScrollToBottom = true
      return
    }

  }
  private func scrollToBottom(in collectionView: UICollectionView) {
    let minOffsetY = -collectionView.adjustedContentInset.top
    let maxOffsetY = max(
      minOffsetY,
      collectionView.contentSize.height
        - collectionView.bounds.height
        + collectionView.adjustedContentInset.bottom
    )
    print("CV:setContentOffset:Scrool")
    collectionView.setContentOffset(
      CGPoint(x: collectionView.contentOffset.x, y: maxOffsetY),
      animated: false
    )
  }
  // 2. Generate attributes for a specific item on the fly
  override func layoutAttributesForItem(at indexPath: IndexPath)
    -> UICollectionViewLayoutAttributes?
  {
    if cache.count > indexPath.item {
      return cache[indexPath.item]
    }
    return nil
  }

  // 3. Return attributes for all items in the visible area
  override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]?
  {
    guard !cache.isEmpty else { return [] }

    let startIndex = firstIndexWithMaxY(atLeast: rect.minY)
    guard startIndex < cache.count else { return [] }

    var visibleAttributes: [UICollectionViewLayoutAttributes] = []
    var index = startIndex
    while index < cache.count {
      let attributes = cache[index]
      if attributes.frame.minY > rect.maxY {
        break
      }
      visibleAttributes.append(attributes)
      index += 1
    }
    return visibleAttributes
  }

  private func firstIndexWithMaxY(atLeast minY: CGFloat) -> Int {
    var low = 0
    var high = cache.count

    while low < high {
      let mid = low + (high - low) / 2
      if cache[mid].frame.maxY < minY {
        low = mid + 1
      } else {
        high = mid
      }
    }
    return low
  }

  override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint)
    -> CGPoint
  {
    guard let pendingAnchor = pendingAnchor,
      let attributes = layoutAttributesForItem(at: pendingAnchor.indexPath)
    else {
      return super.targetContentOffset(forProposedContentOffset: proposedContentOffset)
    }

    let newMinY = attributes.frame.minY
    var newOffset = collectionView?.contentOffset ?? proposedContentOffset
    newOffset.y += (newMinY - pendingAnchor.oldMinY)
    guard let collectionView = collectionView else { fatalError("no cv") }
    let minOffsetY = -collectionView.adjustedContentInset.top
    let maxOffsetY = max(
      minOffsetY,
      collectionViewContentSize.height
        - collectionView.bounds.height
        + collectionView.adjustedContentInset.bottom
    )
    newOffset.y = min(max(newOffset.y, minOffsetY), maxOffsetY)

    return newOffset
  }

  override func finalizeCollectionViewUpdates() {
    super.finalizeCollectionViewUpdates()
    pendingAnchor = nil
  }
}
