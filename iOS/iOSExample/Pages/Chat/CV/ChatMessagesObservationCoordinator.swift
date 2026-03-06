//
//  ChatMessagesObservationCoordinator.swift
//  iOSExample
//
//  Created by Cursor on 06/03/26.
//

import Foundation
import GRDB

final class ChatMessagesObservationCoordinator {
  struct Update {
    let session: Int
    let observedLimit: Int
    let latest: [ChatMessageModel]
    let latestTextRowMeta: [Int64: TextRowMeta]
    let hasOlderMessages: Bool
    let beforeObserved: [ChatMessageModel]
    let diff: MessageBatchDiff
    let hasAnyChange: Bool
    let detectedFalseDelete: Bool
    let deleteDebugLog: String?
    let isInitialSnapshot: Bool
  }

  private struct ObservedMessagesPage {
    let messages: [ChatMessageModel]
    let hasOlderMessages: Bool
  }

  private var chatId: String
  private var pageSize: Int
  private var chatStore: ChatStore
  private let loadMorePageSize: Int
  private let observedLimitLock = NSLock()
  private var currentObservedLimit: Int
  private(set) var canLoadMore = true
  private(set) var isLoadingMore = false
  private let updateWorkQueue = DispatchQueue(
    label: "cv.messages.update-work", qos: .userInitiated)
  private var observationSession = 0
  private var cancelMessagesObservation: (() -> Void)?
  private var didReceiveInitialMessagesSnapshot = false
  private var lastObservedMessages: [ChatMessageModel]
  private let snapshotBuilder: ChatDisplaySnapshotBuilder
  private let collectionWidthProvider: () -> CGFloat
  private var onUpdate: ((Update) -> Void)?

  init(
    chatId: String,
    pageSize: Int,
    chatStore: ChatStore,
    snapshotBuilder: ChatDisplaySnapshotBuilder,
    loadMorePageSize: Int = 60,
    collectionWidthProvider: @escaping () -> CGFloat
  ) {
    self.chatId = chatId
    self.pageSize = pageSize
    self.chatStore = chatStore
    self.snapshotBuilder = snapshotBuilder
    self.loadMorePageSize = loadMorePageSize
    currentObservedLimit = pageSize
    lastObservedMessages = []
    self.collectionWidthProvider = collectionWidthProvider
  }

  func updateConfiguration(chatId: String, pageSize: Int, chatStore: ChatStore) {
    self.chatId = chatId
    self.pageSize = pageSize
    self.chatStore = chatStore
  }

  func start(onUpdate: @escaping (Update) -> Void) {
    cancelMessagesObservation?()
    cancelMessagesObservation = nil
    observationSession += 1
    let session = observationSession
    self.onUpdate = onUpdate

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

  func stop() {
    cancelMessagesObservation?()
    cancelMessagesObservation = nil
  }

  func requestLoadMoreIfNeeded(messages: Messages) {
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

  func requestObservedLimit(atLeast requiredObservedLimit: Int) {
    guard requiredObservedLimit > getCurrentObservedLimit() else { return }
    setCurrentObservedLimit(requiredObservedLimit)
    isLoadingMore = true
    processMessagesObservationChange(
      session: observationSession,
      observedChatId: chatId,
      observedLimit: requiredObservedLimit,
      dbQueue: chatStore.dbQueue
    )
  }

  func getObservedLimit() -> Int {
    getCurrentObservedLimit()
  }

  func finishMainThreadUpdate(session: Int, hasOlderMessages: Bool) -> Bool? {
    guard observationSession == session else { return nil }
    let didLoadMoreAvailabilityChange = canLoadMore != hasOlderMessages
    canLoadMore = hasOlderMessages
    isLoadingMore = false
    return didLoadMoreAvailabilityChange
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
      let latestTextRowMeta = self.snapshotBuilder.buildTextRowMeta(
        messages: latest,
        senders: latestSenders,
        messageById: replyTargetMessagesById
      )
      let latestReplyPreviewTexts = self.snapshotBuilder.buildReplyPreviewTexts(
        messages: latest,
        rowMetaByInternalId: latestTextRowMeta
      )
      ReplyPreviewRegistry.replace(with: latestReplyPreviewTexts)
      let hasOlderMessages = latestPage.hasOlderMessages

      let width = self.collectionWidthProvider()
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

      guard self.observationSession == session else { return }

      guard self.didReceiveInitialMessagesSnapshot else {
        self.didReceiveInitialMessagesSnapshot = true
        self.lastObservedMessages = latest
        let update = Update(
          session: session,
          observedLimit: observedLimit,
          latest: latest,
          latestTextRowMeta: latestTextRowMeta,
          hasOlderMessages: hasOlderMessages,
          beforeObserved: [],
          diff: MessageBatchDiff(inserts: [], deletes: [], updates: []),
          hasAnyChange: false,
          detectedFalseDelete: false,
          deleteDebugLog: nil,
          isInitialSnapshot: true
        )
        DispatchQueue.main.async { [weak self] in
          guard let self else { return }
          self.onUpdate?(update)
        }
        return
      }

      let beforeObserved = self.lastObservedMessages
      self.lastObservedMessages = latest

      let diff = self.snapshotBuilder.buildBatchDiff(from: beforeObserved, to: latest)
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

      let update = Update(
        session: session,
        observedLimit: observedLimit,
        latest: latest,
        latestTextRowMeta: latestTextRowMeta,
        hasOlderMessages: hasOlderMessages,
        beforeObserved: beforeObserved,
        diff: diff,
        hasAnyChange: hasAnyChange,
        detectedFalseDelete: detectedFalseDelete,
        deleteDebugLog: deleteDebugLog,
        isInitialSnapshot: false
      )
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        self.onUpdate?(update)
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
        "CL: fetch messages failed: \(error.localizedDescription, privacy: .public)"
      )
      return ObservedMessagesPage(messages: [], hasOlderMessages: false)
    }
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
}
