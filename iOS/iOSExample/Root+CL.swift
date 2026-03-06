import GRDB
import SwiftData
import SwiftUI
import UIKit

enum Message {
  case Text(ChatMessageModel)
  case ChannelLink(ChatMessageModel, ParsedChannelLink)
  case DateSeparator(Date, isFirst: Bool)
  case LoadMore
}

typealias Messages = [Message]

struct MaxChat: UIViewControllerRepresentable {
  @EnvironmentObject private var chatStore: ChatStore
  let chatId: String
  let pageSize: Int = 50

  var onReplyMessage: ((ChatMessageModel) -> Void)? = nil
  var onDMMessage: ((String, Int32, Data, Int) -> Void)? = nil
  var onDeleteMessage: ((ChatMessageModel) -> Void)? = nil
  var onMuteUser: ((Data) -> Void)? = nil
  var onUnmuteUser: ((Data) -> Void)? = nil

  init(
    chatId: String,
    onReplyMessage: ((ChatMessageModel) -> Void)? = nil,
    onDMMessage: ((String, Int32, Data, Int) -> Void)? = nil,
    onDeleteMessage: ((ChatMessageModel) -> Void)? = nil,
    onMuteUser: ((Data) -> Void)? = nil,
    onUnmuteUser: ((Data) -> Void)? = nil
  ) {
    self.chatId = chatId
    self.onReplyMessage = onReplyMessage
    self.onDMMessage = onDMMessage
    self.onDeleteMessage = onDeleteMessage
    self.onMuteUser = onMuteUser
    self.onUnmuteUser = onUnmuteUser
  }

  func makeUIViewController(context _: Context) -> Controller {
    let controller = Controller(chatId: chatId, pageSize: pageSize, chatStore: chatStore)
    controller.updateCallbacks(
      onReplyMessage: onReplyMessage,
      onDMMessage: onDMMessage,
      onDeleteMessage: onDeleteMessage,
      onMuteUser: onMuteUser,
      onUnmuteUser: onUnmuteUser
    )
    return controller
  }

  func updateUIViewController(_ uiViewController: Controller, context _: Context) {
    uiViewController.update(chatId: chatId, pageSize: pageSize, chatStore: chatStore)
    uiViewController.updateCallbacks(
      onReplyMessage: onReplyMessage,
      onDMMessage: onDMMessage,
      onDeleteMessage: onDeleteMessage,
      onMuteUser: onMuteUser,
      onUnmuteUser: onUnmuteUser
    )
  }

  final class Controller: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate,
    UIGestureRecognizerDelegate, Deletage
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

    private struct TextRowMeta: Equatable {
      let senderDisplayName: String?
      let senderColor: Int?
      let replyPreviewText: String?
    }

    private var chatId: String
    private var pageSize: Int
    private let loadMorePageSize = 60
    private let loadMoreTriggerDistanceFromTop: CGFloat = 180
    private let observedLimitLock = NSLock()
    private var currentObservedLimit: Int
    private var canLoadMore = true
    private var isLoadingMore = false
    private var chatStore: ChatStore
    private var messages: Messages
    private var textRowMetaByInternalId: [Int64: TextRowMeta]
    private var lastObservedMessages: [ChatMessageModel]
    private let updateWorkQueue = DispatchQueue(
      label: "cv.messages.update-work", qos: .userInitiated)
    private var observationSession = 0
    private var cancelMessagesObservation: (() -> Void)?
    private var didReceiveInitialMessagesSnapshot = false
    private var currentCollectionWidth: CGFloat = 0
    private static let floatingDateCurrentYearFormatter: DateFormatter = {
      let formatter = DateFormatter()
      formatter.dateFormat = "EEE d MMM"
      return formatter
    }()
    private static let floatingDateWithYearFormatter: DateFormatter = {
      let formatter = DateFormatter()
      formatter.dateFormat = "EEE d MMM yyyy"
      return formatter
    }()
    private static let swipeReplyTriggerThreshold: CGFloat = 60
    private static let swipeReplyMaxDrag: CGFloat = 100
    private static let swipeReplyIndicatorSize: CGFloat = 36
    private static let swipeReplyIndicatorIconSize: CGFloat = 16
    private static let swipeReplyIndicatorInset: CGFloat = 8
    private static let jumpButtonBottomSpacing: CGFloat = 16
    private static let jumpButtonTrailingSpacing: CGFloat = 16
    private let floatingDateBadge = UIView()
    private let floatingDateLabel = UILabel()
    private var floatingDateHideWorkItem: DispatchWorkItem?
    private var floatingDateValue: String?
    private let swipeReplyIndicatorView = UIView()
    private let swipeReplyIndicatorImageView = UIImageView()
    private let swipeReplyHaptic = UIImpactFeedbackGenerator(style: .medium)
    private weak var activeSwipeCell: UICollectionViewCell?
    private var activeSwipeMessage: ChatMessageModel?
    private var hasTriggeredSwipeReplyHaptic = false
    private var swipeReplyIndicatorIsArmed = false
    private lazy var swipeReplyPanGesture: UIPanGestureRecognizer = {
      let recognizer = UIPanGestureRecognizer(
        target: self, action: #selector(handleSwipeToReplyPan(_:)))
      recognizer.delegate = self
      recognizer.cancelsTouchesInView = false
      return recognizer
    }()
    private let jumpToBottomButton = UIButton(type: .system)
    private var isJumpToBottomButtonVisible = false
    private var pendingReplyScrollMessageId: String?
    private var highlightedReplyMessageId: String?
    private var pendingReplyHighlightMessageId: String?
    private var replyHighlightResetWorkItem: DispatchWorkItem?
    private static let replyHighlightDuration: TimeInterval = 1.6
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

    init(chatId: String, pageSize: Int, chatStore: ChatStore) {
      self.chatId = chatId
      self.pageSize = pageSize
      currentObservedLimit = pageSize
      self.chatStore = chatStore
      messages = []
      textRowMetaByInternalId = [:]
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
        guard canLoadMore else { return .zero }
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
      cancelMessagesObservation?()
      cancelMessagesObservation = nil
      observationSession += 1
      let session = observationSession
      pendingReplyScrollMessageId = nil
      
      // Reset state on the background queue to prevent data races
      // with ongoing diff calculations from previous observations.
      updateWorkQueue.async { [weak self] in
        guard let self else { return }
        if self.observationSession == session {
          self.didReceiveInitialMessagesSnapshot = false
          self.lastObservedMessages = []
        }
      }
      
      setCurrentObservedLimit(pageSize)
      canLoadMore = true
      isLoadingMore = false

      let observedChatId = chatId
      let dbQueue = chatStore.dbQueue
      let observation = DatabaseRegionObservation(
        tracking: ChatMessageModel.filter(Column("chatId") == observedChatId)
      )
      let cancellable = observation.start(
        in: dbQueue,
        onError: { error in
          AppLogger.chat.error(
            "CL: observation error: \(error.localizedDescription, privacy: .public)"
          )
        },
        onChange: { [weak self] _ in
          guard let self else { return }
          self.processMessagesObservationChange(
            session: session,
            observedChatId: observedChatId,
            observedLimit: self.getCurrentObservedLimit(),
            dbQueue: dbQueue
          )
        }
      )
      processMessagesObservationChange(
        session: session,
        observedChatId: observedChatId,
        observedLimit: getCurrentObservedLimit(),
        dbQueue: dbQueue
      )
      cancelMessagesObservation = {
        cancellable.cancel()
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
        let latestSenders = self.fetchSendersForMessages(latest)
        let replyTargetMessagesById = self.fetchReplyTargetMessagesById(
          for: latest,
          chatId: observedChatId
        )
        let latestTextRowMeta = self.buildTextRowMeta(
          messages: latest,
          senders: latestSenders,
          messageById: replyTargetMessagesById
        )
        let latestReplyPreviewTexts = self.buildReplyPreviewTexts(
          messages: latest,
          rowMetaByInternalId: latestTextRowMeta
        )
        ReplyPreviewRegistry.replace(with: latestReplyPreviewTexts)
        let hasOlderMessages = latestPage.hasOlderMessages

        let width = self.currentCollectionWidth
        if width > 0 {
          for msg in latest {
            guard ParsedChannelLink.parse(from: msg.message) == nil else { continue }
            let rowMeta = latestTextRowMeta[msg.internalId]
            _ = TextCell.size(
              width: width,
              message: msg,
              senderDisplayName: rowMeta?.senderDisplayName
            )
          }
        }

        // Ensure this session wasn't cancelled while we were fetching/sizing.
        // If an old session updates lastObservedMessages, it corrupts the diffing state.
        guard self.observationSession == session else { return }

        guard self.didReceiveInitialMessagesSnapshot else {
          self.didReceiveInitialMessagesSnapshot = true
          self.lastObservedMessages = latest
          DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard self.observationSession == session else { return }
            self.canLoadMore = hasOlderMessages
            self.isLoadingMore = false
            self.textRowMetaByInternalId = latestTextRowMeta
            self.messages = self.buildDisplayMessages(from: latest)
            if let layout = self.collectionView.collectionViewLayout as? CVLayout {
              layout.didInitialScrollToBottom = false
            }
            self.endSwipeToReply(triggerReply: false, animated: false)
            self.collectionView.reloadData()
            self.updateJumpToBottomButtonVisibility(animated: false)
            self.continuePendingReplyScrollIfNeeded()
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
          
          // CRITICAL: We must NOT skip this update (e.g., by checking if observedLimit changed).
          // Every update computed on the background queue MUST be applied to self.messages.
          // Otherwise, self.messages (UI state) gets out of sync with lastObservedMessages (background state),
          // causing the next diff's index math to be wrong and crashing the UICollectionView.
          let oldTextRowMeta = self.textRowMetaByInternalId
          let didLoadMoreAvailabilityChange = self.canLoadMore != hasOlderMessages
          self.canLoadMore = hasOlderMessages
          self.isLoadingMore = false
          guard hasAnyChange else {
            self.textRowMetaByInternalId = latestTextRowMeta
            guard didLoadMoreAvailabilityChange, !self.messages.isEmpty else {
              self.updateJumpToBottomButtonVisibility(animated: true)
              self.continuePendingReplyScrollIfNeeded()
              return
            }

            let anchor = self.captureVisibleAnchor(in: self.collectionView, messages: self.messages)
            if let anchor, let layout = self.collectionView.collectionViewLayout as? CVLayout {
              if let newIndex = self.messages.firstIndex(where: { message in
                self.chatMessage(from: message)?.id == anchor.messageId
              }) {
                layout.pendingAnchor = (IndexPath(item: newIndex, section: 0), anchor.minY)
              }
            }

            UIView.performWithoutAnimation {
              self.collectionView.performBatchUpdates {
                self.collectionView.reloadItems(at: [IndexPath(item: 0, section: 0)])
              }
            }
            self.updateJumpToBottomButtonVisibility(animated: true)
            self.continuePendingReplyScrollIfNeeded()
            return
          }

          let oldMessages = self.messages
          let wasNearBottom = self.isNearBottom(in: self.collectionView)
          let shouldAutoScrollToBottom =
            wasNearBottom
            && self.didInsertBottomMessage(rawDiff: diff, newObservedCount: latest.count)
          let newMessages = self.buildDisplayMessages(from: latest)
          let displayDiff = self.buildDisplayDiff(
            oldObserved: beforeObserved,
            newObserved: latest,
            oldDisplay: oldMessages,
            newDisplay: newMessages,
            rawDiff: diff,
            oldTextRowMeta: oldTextRowMeta,
            newTextRowMeta: latestTextRowMeta
          )
          let anchor =
            shouldAutoScrollToBottom
            ? nil
            : self.captureVisibleAnchor(in: self.collectionView, messages: oldMessages)
          self.textRowMetaByInternalId = latestTextRowMeta
          self.messages = newMessages

          if let anchor, let layout = self.collectionView.collectionViewLayout as? CVLayout {
            if let newIndex = self.messages.firstIndex(where: { message in
              self.chatMessage(from: message)?.id == anchor.messageId
            }) {
              layout.pendingAnchor = (IndexPath(item: newIndex, section: 0), anchor.minY)
            }
          }

          self.endSwipeToReply(triggerReply: false, animated: false)
          UIView.performWithoutAnimation {
            self.collectionView.performBatchUpdates {
              if !displayDiff.deletes.isEmpty {
                self.collectionView.deleteItems(at: displayDiff.deletes)
              }
              if !displayDiff.inserts.isEmpty {
                self.collectionView.insertItems(at: displayDiff.inserts)
              }
              if !displayDiff.updates.isEmpty {
                self.collectionView.reloadItems(at: displayDiff.updates)
              }
            } completion: { _ in
              if shouldAutoScrollToBottom {
                self.scrollToBottom(in: self.collectionView)
              }
              self.updateJumpToBottomButtonVisibility(animated: true)
              self.continuePendingReplyScrollIfNeeded()
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

    private func fetchSendersForMessages(_ messages: [ChatMessageModel]) -> [String:
      MessageSenderModel]
    {
      let senderIds = Array(Set(messages.compactMap(\.senderId)))
      guard !senderIds.isEmpty else { return [:] }
      return (try? chatStore.fetchSenders(ids: senderIds)) ?? [:]
    }

    private func fetchReplyTargetMessagesById(
      for messages: [ChatMessageModel],
      chatId: String
    ) -> [String: ChatMessageModel] {
      var messageById = Dictionary(uniqueKeysWithValues: messages.map { ($0.id, $0) })
      let missingReplyTargetIds = Array(
        Set(messages.compactMap(\.replyTo)).subtracting(messageById.keys)
      )
      guard !missingReplyTargetIds.isEmpty else { return messageById }

      let fetchedReplyTargets = (try? chatStore.fetchMessages(ids: missingReplyTargetIds)) ?? []
      for replyTarget in fetchedReplyTargets where replyTarget.chatId == chatId {
        messageById[replyTarget.id] = replyTarget
      }

      return messageById
    }

    private func buildTextRowMeta(
      messages: [ChatMessageModel],
      senders: [String: MessageSenderModel],
      messageById: [String: ChatMessageModel]
    ) -> [Int64: TextRowMeta] {
      guard !messages.isEmpty else { return [:] }
      let calendar = Calendar.current
      var rowMetaByInternalId: [Int64: TextRowMeta] = [:]
      rowMetaByInternalId.reserveCapacity(messages.count)

      var senderDisplayNameById: [String: String] = [:]
      senderDisplayNameById.reserveCapacity(senders.count)
      for (id, sender) in senders {
        senderDisplayNameById[id] = senderDisplayName(for: sender)
      }

      var replyPreviewByMessageId: [String: String?] = [:]
      replyPreviewByMessageId.reserveCapacity(messages.count)

      for (index, message) in messages.enumerated() {
        let replyPreviewText = replyPreviewText(
          for: message.replyTo,
          messageById: messageById,
          cache: &replyPreviewByMessageId
        )

        guard message.isIncoming else {
          rowMetaByInternalId[message.internalId] = TextRowMeta(
            senderDisplayName: nil,
            senderColor: nil,
            replyPreviewText: replyPreviewText
          )
          continue
        }

        let startsNewDay =
          index == 0
          || !calendar.isDate(message.timestamp, inSameDayAs: messages[index - 1].timestamp)

        let shouldShowSender: Bool
        if startsNewDay {
          shouldShowSender = true
        } else {
          let previous = messages[index - 1]
          shouldShowSender = !(previous.isIncoming && previous.senderId == message.senderId)
        }

        if !shouldShowSender {
          rowMetaByInternalId[message.internalId] = TextRowMeta(
            senderDisplayName: nil,
            senderColor: nil,
            replyPreviewText: replyPreviewText
          )
          continue
        }

        if let senderId = message.senderId, let sender = senders[senderId] {
          rowMetaByInternalId[message.internalId] = TextRowMeta(
            senderDisplayName: senderDisplayNameById[senderId] ?? senderDisplayName(for: sender),
            senderColor: sender.color,
            replyPreviewText: replyPreviewText
          )
        } else {
          rowMetaByInternalId[message.internalId] = TextRowMeta(
            senderDisplayName: "Unknown",
            senderColor: nil,
            replyPreviewText: replyPreviewText
          )
        }
      }

      return rowMetaByInternalId
    }

    private func senderDisplayName(for sender: MessageSenderModel?) -> String {
      guard let sender else { return "Unknown" }
      guard let nickname = sender.nickname, !nickname.isEmpty else {
        return sender.codename
      }
      let truncatedNickname = nickname.count > 10 ? String(nickname.prefix(10)) + "…" : nickname
      return "\(truncatedNickname) aka \(sender.codename)"
    }

    private func buildReplyPreviewTexts(
      messages: [ChatMessageModel],
      rowMetaByInternalId: [Int64: TextRowMeta]
    ) -> [Int64: String] {
      var previewsByMessageInternalId: [Int64: String] = [:]
      previewsByMessageInternalId.reserveCapacity(messages.count)

      for message in messages {
        if let replyPreviewText = rowMetaByInternalId[message.internalId]?.replyPreviewText {
          previewsByMessageInternalId[message.internalId] = replyPreviewText
        }
      }

      return previewsByMessageInternalId
    }

    private func continuePendingReplyScrollIfNeeded() {
      guard let pendingReplyScrollMessageId else { return }
      guard messages.contains(where: { message in
        chatMessage(from: message)?.id == pendingReplyScrollMessageId
      }) else {
        return
      }

      self.pendingReplyScrollMessageId = nil
      scrollToReplyMessage(pendingReplyScrollMessageId)
    }

    private func updateReplyHighlightStateForVisibleCells(animated: Bool) {
      for indexPath in collectionView.indexPathsForVisibleItems {
        guard messages.indices.contains(indexPath.item) else { continue }
        guard let message = chatMessage(from: messages[indexPath.item]) else { continue }
        guard let cell = collectionView.cellForItem(at: indexPath) as? ReplyHighlightableCell else {
          continue
        }
        cell.setReplyTargetHighlighted(message.id == highlightedReplyMessageId, animated: animated)
      }
    }

    private func clearReplyMessageHighlight(animated: Bool) {
      replyHighlightResetWorkItem?.cancel()
      replyHighlightResetWorkItem = nil
      guard highlightedReplyMessageId != nil else { return }
      highlightedReplyMessageId = nil
      updateReplyHighlightStateForVisibleCells(animated: animated)
    }

    private func scheduleReplyMessageHighlightReset(for messageId: String) {
      replyHighlightResetWorkItem?.cancel()

      let workItem = DispatchWorkItem { [weak self] in
        guard let self, self.highlightedReplyMessageId == messageId else { return }
        self.highlightedReplyMessageId = nil
        self.updateReplyHighlightStateForVisibleCells(animated: true)
        self.replyHighlightResetWorkItem = nil
      }

      replyHighlightResetWorkItem = workItem
      DispatchQueue.main.asyncAfter(
        deadline: .now() + Self.replyHighlightDuration,
        execute: workItem
      )
    }

    private func applyPendingReplyHighlightIfNeeded(animated: Bool) {
      guard let pendingReplyHighlightMessageId else { return }
      self.pendingReplyHighlightMessageId = nil
      highlightedReplyMessageId = pendingReplyHighlightMessageId
      updateReplyHighlightStateForVisibleCells(animated: animated)
      scheduleReplyMessageHighlightReset(for: pendingReplyHighlightMessageId)
    }

    private func scrollToReplyMessage(_ replyToMessageId: String) {
      guard let itemIndex = messages.firstIndex(where: { message in
        chatMessage(from: message)?.id == replyToMessageId
      }) else {
        guard
          let targetMessage = try? chatStore.fetchMessage(id: replyToMessageId),
          targetMessage.chatId == chatId
        else {
          pendingReplyScrollMessageId = nil
          return
        }

        guard let newerMessageCount = try? chatStore.countNewerMessages(
          chatId: chatId,
          afterTimestamp: targetMessage.timestamp,
          afterInternalId: targetMessage.internalId
        ) else {
          pendingReplyScrollMessageId = nil
          return
        }
        let requiredObservedLimit = max(getCurrentObservedLimit(), newerMessageCount + 1)
        pendingReplyScrollMessageId = replyToMessageId

        guard requiredObservedLimit > getCurrentObservedLimit() else { return }

        setCurrentObservedLimit(requiredObservedLimit)
        isLoadingMore = true
        processMessagesObservationChange(
          session: observationSession,
          observedChatId: chatId,
          observedLimit: requiredObservedLimit,
          dbQueue: chatStore.dbQueue
        )
        return
      }

      collectionView.layoutIfNeeded()
      let indexPath = IndexPath(item: itemIndex, section: 0)
      guard let attributes = collectionView.layoutAttributesForItem(at: indexPath) else {
        return
      }

      let visibleHeight =
        collectionView.bounds.height - collectionView.adjustedContentInset.top
        - collectionView.adjustedContentInset.bottom
      let minOffsetY = -collectionView.adjustedContentInset.top
      let maxOffsetY = max(
        minOffsetY,
        collectionView.contentSize.height
          - collectionView.bounds.height
          + collectionView.adjustedContentInset.bottom
      )
      let desiredOffsetY =
        attributes.frame.midY - visibleHeight / 2 - collectionView.adjustedContentInset.top
      let targetOffsetY = min(max(desiredOffsetY, minOffsetY), maxOffsetY)
      let currentOffsetY = collectionView.contentOffset.y

      clearReplyMessageHighlight(animated: false)
      pendingReplyHighlightMessageId = replyToMessageId

      guard abs(currentOffsetY - targetOffsetY) > 1 else {
        applyPendingReplyHighlightIfNeeded(animated: true)
        return
      }

      collectionView.setContentOffset(
        CGPoint(x: collectionView.contentOffset.x, y: targetOffsetY),
        animated: true
      )
    }

    private func replyPreviewText(
      for replyToMessageId: String?,
      messageById: [String: ChatMessageModel],
      cache: inout [String: String?]
    ) -> String? {
      guard let replyToMessageId else { return nil }
      if let cached = cache[replyToMessageId] {
        return cached
      }

      let previewText = messageById[replyToMessageId].flatMap { message in
        normalizedReplyPreviewText(for: message)
      }
      cache[replyToMessageId] = previewText
      return previewText
    }

    private func normalizedReplyPreviewText(for message: ChatMessageModel) -> String? {
      let renderKind = NewMessageRenderKind(rawValue: message.newRenderKindRaw) ?? .unknown
      let plainText: String
      if
        message.newRenderVersion == NewMessageRenderVersion.current,
        renderKind != .unknown,
        let storedPlainText = message.newRenderPlainText
      {
        plainText = storedPlainText
      } else {
        plainText = NewMessageHTMLPrecomputer.precompute(rawHTML: message.message).plainText
      }
      let trimmed = plainText.trimmingCharacters(in: .whitespacesAndNewlines)
      return trimmed.isEmpty ? nil : trimmed
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
      floatingDateHideWorkItem?.cancel()
      replyHighlightResetWorkItem?.cancel()
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

    private func buildDisplayMessages(from observed: [ChatMessageModel]) -> Messages {
      var display: Messages = [.LoadMore]
      guard !observed.isEmpty else { return display }
      let calendar = Calendar.current

      for (index, message) in observed.enumerated() {
        if index == 0
          || !calendar.isDate(message.timestamp, inSameDayAs: observed[index - 1].timestamp)
        {
          let dayDate = calendar.startOfDay(for: message.timestamp)
          display.append(.DateSeparator(dayDate, isFirst: index == 0))
        }
        if let parsedLink = ParsedChannelLink.parse(from: message.message) {
          display.append(.ChannelLink(message, parsedLink))
        } else {
          display.append(.Text(message))
        }
      }

      return display
    }

    private func buildDisplayDiff(
      oldObserved: [ChatMessageModel],
      newObserved: [ChatMessageModel],
      oldDisplay: Messages,
      newDisplay: Messages,
      rawDiff: MessageBatchDiff,
      oldTextRowMeta: [Int64: TextRowMeta],
      newTextRowMeta: [Int64: TextRowMeta]
    ) -> MessageBatchDiff {
      var deleteItems = Set<Int>()
      var insertItems = Set<Int>()
      var updateItems = Set<Int>()

      let oldTextIndices = displayTextIndicesByInternalId(in: oldDisplay)
      let newTextIndices = displayTextIndicesByInternalId(in: newDisplay)

      for indexPath in rawDiff.deletes {
        let rawIndex = indexPath.item - 1
        guard oldObserved.indices.contains(rawIndex) else { continue }
        let key = String(describing: oldObserved[rawIndex].internalId)
        if let item = oldTextIndices[key] {
          deleteItems.insert(item)
        }
      }

      for indexPath in rawDiff.inserts {
        let rawIndex = indexPath.item - 1
        guard newObserved.indices.contains(rawIndex) else { continue }
        let key = String(describing: newObserved[rawIndex].internalId)
        if let item = newTextIndices[key] {
          insertItems.insert(item)
        }
      }

      for indexPath in rawDiff.updates {
        let rawIndex = indexPath.item - 1
        guard newObserved.indices.contains(rawIndex) else { continue }
        let key = String(describing: newObserved[rawIndex].internalId)
        if let item = newTextIndices[key] {
          updateItems.insert(item)
        }
      }

      for message in newObserved {
        guard let oldMeta = oldTextRowMeta[message.internalId],
          let newMeta = newTextRowMeta[message.internalId],
          oldMeta != newMeta
        else {
          continue
        }
        let key = String(describing: message.internalId)
        if let item = newTextIndices[key] {
          updateItems.insert(item)
        }
      }

      let oldDateRows = displayDateRows(in: oldDisplay)
      let newDateRows = displayDateRows(in: newDisplay)

      for (key, oldRow) in oldDateRows where newDateRows[key] == nil {
        deleteItems.insert(oldRow.index)
      }
      for (key, newRow) in newDateRows where oldDateRows[key] == nil {
        insertItems.insert(newRow.index)
      }
      for (key, oldRow) in oldDateRows {
        guard let newRow = newDateRows[key] else { continue }
        if oldRow.isFirst != newRow.isFirst {
          updateItems.insert(newRow.index)
        }
      }

      updateItems.subtract(insertItems)

      return MessageBatchDiff(
        inserts: insertItems.sorted().map { IndexPath(item: $0, section: 0) },
        deletes: deleteItems.sorted().map { IndexPath(item: $0, section: 0) },
        updates: updateItems.sorted().map { IndexPath(item: $0, section: 0) }
      )
    }

    private func displayTextIndicesByInternalId(in messages: Messages) -> [String: Int] {
      var map: [String: Int] = [:]
      for (index, message) in messages.enumerated() {
        switch message {
        case .Text(let textMessage), .ChannelLink(let textMessage, _):
          map[String(describing: textMessage.internalId)] = index
        case .DateSeparator, .LoadMore:
          continue
        }
      }
      return map
    }

    private func displayDateRows(in messages: Messages) -> [String: (index: Int, isFirst: Bool)] {
      var map: [String: (index: Int, isFirst: Bool)] = [:]
      for (index, message) in messages.enumerated() {
        guard case .DateSeparator(let date, let isFirst) = message else { continue }
        map[dateSeparatorKey(for: date)] = (index: index, isFirst: isFirst)
      }
      return map
    }

    private func dateSeparatorKey(for date: Date) -> String {
      String(Int(Calendar.current.startOfDay(for: date).timeIntervalSince1970))
    }

    private func setupSwipeToReply() {
      let havenColor = UIColor(named: "Haven") ?? UIColor(Color.haven)
      swipeReplyIndicatorView.translatesAutoresizingMaskIntoConstraints = false
      swipeReplyIndicatorView.isUserInteractionEnabled = false
      swipeReplyIndicatorView.alpha = 0
      swipeReplyIndicatorView.backgroundColor = havenColor.withAlphaComponent(0.12)
      swipeReplyIndicatorView.layer.cornerRadius = Self.swipeReplyIndicatorSize / 2
      swipeReplyIndicatorView.layer.masksToBounds = true
      swipeReplyIndicatorView.layer.borderWidth = 1
      swipeReplyIndicatorView.layer.borderColor = havenColor.withAlphaComponent(0.25).cgColor

      swipeReplyIndicatorImageView.translatesAutoresizingMaskIntoConstraints = false
      swipeReplyIndicatorImageView.contentMode = .scaleAspectFit
      swipeReplyIndicatorImageView.tintColor = havenColor
      swipeReplyIndicatorImageView.image = UIImage(systemName: "arrowshape.turn.up.left.fill")

      swipeReplyIndicatorView.addSubview(swipeReplyIndicatorImageView)
      NSLayoutConstraint.activate([
        swipeReplyIndicatorImageView.centerXAnchor.constraint(
          equalTo: swipeReplyIndicatorView.centerXAnchor),
        swipeReplyIndicatorImageView.centerYAnchor.constraint(
          equalTo: swipeReplyIndicatorView.centerYAnchor),
        swipeReplyIndicatorImageView.widthAnchor.constraint(
          equalToConstant: Self.swipeReplyIndicatorIconSize),
        swipeReplyIndicatorImageView.heightAnchor.constraint(
          equalToConstant: Self.swipeReplyIndicatorIconSize),
      ])

      // Use absolute positioning instead of constraints for the indicator view itself
      // so we can freely move it around in updateSwipeToReply
      swipeReplyIndicatorView.translatesAutoresizingMaskIntoConstraints = true
      collectionView.addSubview(swipeReplyIndicatorView)
      collectionView.sendSubviewToBack(swipeReplyIndicatorView)
      collectionView.addGestureRecognizer(swipeReplyPanGesture)
    }

    private func replyMessage(at indexPath: IndexPath) -> ChatMessageModel? {
      guard messages.indices.contains(indexPath.item) else { return nil }
      return chatMessage(from: messages[indexPath.item])
    }

    private func beginSwipeToReply(at location: CGPoint) -> Bool {
      guard let indexPath = collectionView.indexPathForItem(at: location),
        let message = replyMessage(at: indexPath),
        let cell = collectionView.cellForItem(at: indexPath)
      else {
        return false
      }

      activeSwipeCell = cell
      activeSwipeMessage = message
      hasTriggeredSwipeReplyHaptic = false
      setSwipeReplyIndicatorArmed(false)
      swipeReplyHaptic.prepare()
      updateSwipeToReply(translationX: 0)
      return true
    }

    private func setSwipeReplyIndicatorArmed(_ isArmed: Bool) {
      guard swipeReplyIndicatorIsArmed != isArmed else { return }
      swipeReplyIndicatorIsArmed = isArmed

      let havenColor = UIColor(named: "Haven") ?? UIColor(Color.haven)
      swipeReplyIndicatorView.backgroundColor = havenColor.withAlphaComponent(isArmed ? 0.22 : 0.12)
      swipeReplyIndicatorView.layer.borderColor =
        havenColor.withAlphaComponent(isArmed ? 0.55 : 0.25).cgColor
    }

    private func updateSwipeToReply(translationX: CGFloat) {
      guard let cell = activeSwipeCell else { return }

      var alpha = max(translationX, 0)
      let threshold = Self.swipeReplyTriggerThreshold

      if alpha > threshold {
        let overflow = alpha - threshold
        alpha = threshold + overflow / 4
      }

      let fastOffset = alpha
      let slowOffset = alpha / 8

      // Direct frame manipulation (no transform, no layout pass)
      cell.contentView.frame.origin.x = fastOffset

      let indicatorSize = Self.swipeReplyIndicatorSize

      // Start the indicator just to the left of the cell's starting position
      // and move it right at 1/8th speed
      let cellCurrentX = cell.frame.minX + fastOffset
      let indicatorX = cellCurrentX - indicatorSize - 8 + slowOffset

      // Ensure the indicator is visible and properly positioned in the collection view's coordinate space
      swipeReplyIndicatorView.frame = CGRect(
        x: indicatorX,
        y: cell.frame.minY + (cell.frame.height - indicatorSize) / 2,
        width: indicatorSize,
        height: indicatorSize
      )
      swipeReplyIndicatorView.alpha = min(alpha / (threshold * 0.5), 1.0)

      // Bring it to front so it's not hidden behind cells
      collectionView.bringSubviewToFront(swipeReplyIndicatorView)

      let isPastThreshold = translationX >= threshold
      setSwipeReplyIndicatorArmed(isPastThreshold)
      if isPastThreshold, !hasTriggeredSwipeReplyHaptic {
        hasTriggeredSwipeReplyHaptic = true
        swipeReplyHaptic.impactOccurred()

        UIView.animate(
          withDuration: 0.2, delay: 0,
          usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8,
          options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
          self.swipeReplyIndicatorImageView.transform = CGAffineTransform(scaleX: 1.16, y: 1.16)
        }
      } else if !isPastThreshold, hasTriggeredSwipeReplyHaptic {
        hasTriggeredSwipeReplyHaptic = false
        UIView.animate(
          withDuration: 0.2, delay: 0,
          usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8,
          options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
          self.swipeReplyIndicatorImageView.transform = .identity
        }
      }
    }

    private func endSwipeToReply(triggerReply: Bool, animated: Bool) {
      let message = activeSwipeMessage
      let cell = activeSwipeCell

      let cleanup = { [weak self] in
        guard let self else { return }
        self.activeSwipeCell = nil
        self.activeSwipeMessage = nil
        self.hasTriggeredSwipeReplyHaptic = false
        self.setSwipeReplyIndicatorArmed(false)
        self.swipeReplyIndicatorImageView.transform = .identity
        if triggerReply, let message {
          self.onReplyMessage?(message)
        }
      }

      if animated {
        UIView.animate(
          withDuration: 0.25,
          delay: 0,
          usingSpringWithDamping: 0.75,
          initialSpringVelocity: 0,
          options: [.allowUserInteraction, .beginFromCurrentState],
          animations: {
            cell?.contentView.frame.origin.x = 0
            self.swipeReplyIndicatorView.alpha = 0
            if let cell = cell {
              let indicatorSize = Self.swipeReplyIndicatorSize
              let indicatorX = cell.frame.minX - indicatorSize - 8
              self.swipeReplyIndicatorView.frame.origin.x = indicatorX
            }
          }
        ) { _ in
          // Push it back behind cells when done
          self.collectionView.sendSubviewToBack(self.swipeReplyIndicatorView)
          cleanup()
        }
      } else {
        cell?.contentView.frame.origin.x = 0
        self.swipeReplyIndicatorView.alpha = 0
        self.collectionView.sendSubviewToBack(self.swipeReplyIndicatorView)
        cleanup()
      }
    }

    @objc
    private func handleSwipeToReplyPan(_ gesture: UIPanGestureRecognizer) {
      let translationX = max(gesture.translation(in: collectionView).x, 0)

      switch gesture.state {
      case .began:
        _ = beginSwipeToReply(at: gesture.location(in: collectionView))
      case .changed:
        updateSwipeToReply(translationX: translationX)
      case .ended:
        let shouldReply = translationX >= Self.swipeReplyTriggerThreshold
        endSwipeToReply(triggerReply: shouldReply, animated: true)
      case .cancelled, .failed:
        endSwipeToReply(triggerReply: false, animated: true)
      default:
        break
      }
    }

    private func setupJumpToBottomButton() {
      jumpToBottomButton.translatesAutoresizingMaskIntoConstraints = false
      jumpToBottomButton.isHidden = true
      jumpToBottomButton.alpha = 0
      jumpToBottomButton.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
      jumpToBottomButton.tintColor = .white
      jumpToBottomButton.backgroundColor = UIColor(named: "Haven") ?? UIColor(Color.haven)
      jumpToBottomButton.layer.cornerRadius = 20
      jumpToBottomButton.layer.masksToBounds = true
      jumpToBottomButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
      jumpToBottomButton.setImage(UIImage(systemName: "arrow.down"), for: .normal)
      jumpToBottomButton.addTarget(self, action: #selector(didTapJumpToBottom), for: .touchUpInside)

      view.addSubview(jumpToBottomButton)
      NSLayoutConstraint.activate([
        jumpToBottomButton.trailingAnchor.constraint(
          equalTo: view.safeAreaLayoutGuide.trailingAnchor,
          constant: -Self.jumpButtonTrailingSpacing
        ),
        jumpToBottomButton.bottomAnchor.constraint(
          equalTo: view.safeAreaLayoutGuide.bottomAnchor,
          constant: -Self.jumpButtonBottomSpacing
        ),
      ])
    }

    @objc
    private func didTapJumpToBottom() {
      scrollToBottom(in: collectionView, animated: true)
      updateJumpToBottomButtonVisibility(animated: true)
    }

    private func updateJumpToBottomButtonVisibility(animated: Bool) {
      guard isViewLoaded else { return }
      let visibleHeight =
        collectionView.bounds.height - collectionView.adjustedContentInset.top
        - collectionView.adjustedContentInset.bottom
      let isScrollable = collectionView.contentSize.height > max(visibleHeight, 0) + 1
      let shouldShow = isScrollable && !isNearBottom(in: collectionView)

      guard shouldShow != isJumpToBottomButtonVisible else { return }
      isJumpToBottomButtonVisible = shouldShow

      if shouldShow {
        jumpToBottomButton.isHidden = false
      }

      let animations = {
        self.jumpToBottomButton.alpha = shouldShow ? 1 : 0
        self.jumpToBottomButton.transform =
          shouldShow ? .identity : CGAffineTransform(scaleX: 0.92, y: 0.92)
      }

      let completion: (Bool) -> Void = { _ in
        if !shouldShow {
          self.jumpToBottomButton.isHidden = true
        }
      }

      if animated {
        UIView.animate(withDuration: 0.2, animations: animations, completion: completion)
      } else {
        animations()
        completion(true)
      }
    }

    private func setupFloatingDateBadge() {
      floatingDateBadge.translatesAutoresizingMaskIntoConstraints = false
      floatingDateBadge.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.9)
      floatingDateBadge.layer.cornerRadius = 14
      floatingDateBadge.layer.masksToBounds = true
      floatingDateBadge.alpha = 0

      floatingDateLabel.translatesAutoresizingMaskIntoConstraints = false
      floatingDateLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
      floatingDateLabel.textColor = UIColor.secondaryLabel
      floatingDateLabel.numberOfLines = 1

      floatingDateBadge.addSubview(floatingDateLabel)
      view.addSubview(floatingDateBadge)

      NSLayoutConstraint.activate([
        floatingDateBadge.topAnchor.constraint(
          equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
        floatingDateBadge.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        floatingDateLabel.topAnchor.constraint(equalTo: floatingDateBadge.topAnchor, constant: 6),
        floatingDateLabel.bottomAnchor.constraint(
          equalTo: floatingDateBadge.bottomAnchor, constant: -6),
        floatingDateLabel.leadingAnchor.constraint(
          equalTo: floatingDateBadge.leadingAnchor, constant: 12),
        floatingDateLabel.trailingAnchor.constraint(
          equalTo: floatingDateBadge.trailingAnchor, constant: -12),
      ])
    }

    private func updateFloatingDateBadgeDuringScroll() {
      guard let date = currentTopVisibleDate() else { return }
      let dateKey = dateSeparatorKey(for: date)
      if floatingDateValue != dateKey {
        floatingDateLabel.text = floatingDateText(for: date)
        floatingDateValue = dateKey
      }

      if floatingDateBadge.alpha < 1 {
        UIView.animate(withDuration: 0.15) {
          self.floatingDateBadge.alpha = 1
        }
      }

      floatingDateHideWorkItem?.cancel()
      let hideWorkItem = DispatchWorkItem { [weak self] in
        self?.hideFloatingDateBadge()
      }
      floatingDateHideWorkItem = hideWorkItem
      DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: hideWorkItem)
    }

    private func hideFloatingDateBadge() {
      UIView.animate(withDuration: 0.2) {
        self.floatingDateBadge.alpha = 0
      }
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

    private func floatingDateText(for date: Date) -> String {
      let calendar = Calendar.current
      if calendar.isDateInToday(date) {
        return "Today"
      }
      if calendar.isDateInYesterday(date) {
        return "Yesterday"
      }
      if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
        return Self.floatingDateCurrentYearFormatter.string(from: date)
      }
      return Self.floatingDateWithYearFormatter.string(from: date)
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
        guard let message = chatMessage(from: messages[indexPath.item]) else { return nil }
        let minY = collectionView.layoutAttributesForItem(at: indexPath)?.frame.minY
        guard let minY else { return nil }
        return VisibleAnchor(messageId: message.id, minY: minY)
      }.max(by: { $0.minY < $1.minY })

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
        cell.contentView.frame.origin.x = 0
        let rowMeta = textRowMetaByInternalId[textMessage.internalId]
        cell.render(
          message: textMessage,
          senderDisplayName: rowMeta?.senderDisplayName,
          senderColor: rowMeta?.senderColor
        )
        cell.setReplyTargetHighlighted(textMessage.id == highlightedReplyMessageId, animated: false)
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
        cell.setReplyTargetHighlighted(textMessage.id == highlightedReplyMessageId, animated: false)
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
    }

    func collectionView(
      _ collectionView: UICollectionView,
      contextMenuConfigurationForItemAt indexPath: IndexPath,
      point: CGPoint
    ) -> UIContextMenuConfiguration? {
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

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
      guard gestureRecognizer === swipeReplyPanGesture,
        let pan = gestureRecognizer as? UIPanGestureRecognizer
      else {
        return true
      }

      let velocity = pan.velocity(in: collectionView)
      let shouldBeginHorizontalSwipe: Bool
      if velocity == .zero {
        let translation = pan.translation(in: collectionView)
        shouldBeginHorizontalSwipe =
          translation.x > 0 && abs(translation.x) > abs(translation.y) * 1.1
      } else {
        shouldBeginHorizontalSwipe = velocity.x > 0 && abs(velocity.x) > abs(velocity.y) * 1.1
      }
      guard shouldBeginHorizontalSwipe else { return false }

      let location = pan.location(in: collectionView)
      guard let indexPath = collectionView.indexPathForItem(at: location),
        replyMessage(at: indexPath) != nil
      else {
        return false
      }
      return true
    }

    func gestureRecognizer(
      _ gestureRecognizer: UIGestureRecognizer,
      shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
      return false
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
      guard scrollView === collectionView else { return }
      endSwipeToReply(triggerReply: false, animated: false)
      updateFloatingDateBadgeDuringScroll()
      updateJumpToBottomButtonVisibility(animated: true)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
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

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
      guard scrollView === collectionView else { return }
      updateJumpToBottomButtonVisibility(animated: true)
      applyPendingReplyHighlightIfNeeded(animated: true)
    }
  }
}

protocol Deletage {
  func getSize(at: IndexPath, width: CGFloat) -> CGRect
  func getXOrigin(at: IndexPath, availableWidth: CGFloat, cellWidth: CGFloat) -> CGFloat
  func spacingAfterItem(at: IndexPath) -> CGFloat
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

    var sizes = [CGSize]()
    sizes.reserveCapacity(numberOfItems)

    for item in 0..<numberOfItems {
      let indexPath = IndexPath(item: item, section: 0)
      let size = delegate.getSize(at: indexPath, width: w)
      let spacingAfter = delegate.spacingAfterItem(at: indexPath)
      sizes.append(size.size)
      totalContentHeight += size.height + spacingAfter
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
      let x = delegate.getXOrigin(at: indexPath, availableWidth: w, cellWidth: size.width)
      attributes.frame = CGRect(x: x, y: topOffset, width: size.width, height: size.height)
      topOffset += size.height + delegate.spacingAfterItem(at: indexPath)
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
