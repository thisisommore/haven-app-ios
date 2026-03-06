//
//  ReplyNavigationCoordinator.swift
//  iOSExample
//
//  Created by Cursor on 06/03/26.
//

import UIKit

final class ReplyNavigationCoordinator {
  private static let replyHighlightDuration: TimeInterval = 1.6

  private weak var collectionView: UICollectionView?
  private var pendingReplyScrollMessageId: String?
  private var highlightedReplyMessageId: String?
  private var pendingReplyHighlightMessageId: String?
  private var replyHighlightResetWorkItem: DispatchWorkItem?

  init(collectionView: UICollectionView) {
    self.collectionView = collectionView
  }

  func cleanup() {
    replyHighlightResetWorkItem?.cancel()
    replyHighlightResetWorkItem = nil
  }

  func resetPendingReplyState() {
    pendingReplyScrollMessageId = nil
    pendingReplyHighlightMessageId = nil
    highlightedReplyMessageId = nil
    cleanup()
  }

  func isMessageHighlighted(_ messageId: String) -> Bool {
    messageId == highlightedReplyMessageId
  }

  func continuePendingReplyScrollIfNeeded(
    messagesProvider: () -> Messages,
    chatMessage: (Message) -> ChatMessageModel?,
    scrollToReplyMessage: (String) -> Void
  ) {
    guard let pendingReplyScrollMessageId else { return }
    let messages = messagesProvider()
    guard
      messages.contains(where: { message in
        chatMessage(message)?.id == pendingReplyScrollMessageId
      })
    else {
      return
    }

    self.pendingReplyScrollMessageId = nil
    scrollToReplyMessage(pendingReplyScrollMessageId)
  }

  func clearReplyMessageHighlight(
    messagesProvider: () -> Messages,
    chatMessage: (Message) -> ChatMessageModel?,
    animated: Bool
  ) {
    replyHighlightResetWorkItem?.cancel()
    replyHighlightResetWorkItem = nil
    guard highlightedReplyMessageId != nil else { return }
    highlightedReplyMessageId = nil
    updateReplyHighlightStateForVisibleCells(
      messagesProvider: messagesProvider,
      chatMessage: chatMessage,
      animated: animated
    )
  }

  func applyPendingReplyHighlightIfNeeded(
    messagesProvider: @escaping () -> Messages,
    chatMessage: @escaping (Message) -> ChatMessageModel?,
    animated: Bool
  ) {
    guard let pendingReplyHighlightMessageId else { return }
    self.pendingReplyHighlightMessageId = nil
    highlightedReplyMessageId = pendingReplyHighlightMessageId
    updateReplyHighlightStateForVisibleCells(
      messagesProvider: messagesProvider,
      chatMessage: chatMessage,
      animated: animated
    )
    scheduleReplyMessageHighlightReset(
      for: pendingReplyHighlightMessageId,
      messagesProvider: messagesProvider,
      chatMessage: chatMessage
    )
  }

  func scrollToReplyMessage(
    _ replyToMessageId: String,
    messagesProvider: @escaping () -> Messages,
    chatMessage: @escaping (Message) -> ChatMessageModel?,
    chatStore: ChatStore,
    chatId: String,
    currentObservedLimit: () -> Int,
    requestObservedLimit: (Int) -> Void
  ) {
    guard let collectionView else { return }
    let messages = messagesProvider()
    guard
      let itemIndex = messages.firstIndex(where: { message in
        chatMessage(message)?.id == replyToMessageId
      })
    else {
      guard
        let targetMessage = try? chatStore.fetchMessage(id: replyToMessageId),
        targetMessage.chatId == chatId
      else {
        pendingReplyScrollMessageId = nil
        return
      }

      guard
        let newerMessageCount = try? chatStore.countNewerMessages(
          chatId: chatId,
          afterTimestamp: targetMessage.timestamp,
          afterInternalId: targetMessage.internalId
        )
      else {
        pendingReplyScrollMessageId = nil
        return
      }
      let requiredObservedLimit = max(currentObservedLimit(), newerMessageCount + 1)
      pendingReplyScrollMessageId = replyToMessageId

      guard requiredObservedLimit > currentObservedLimit() else { return }
      requestObservedLimit(requiredObservedLimit)
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

    clearReplyMessageHighlight(
      messagesProvider: messagesProvider,
      chatMessage: chatMessage,
      animated: false
    )
    pendingReplyHighlightMessageId = replyToMessageId

    guard abs(currentOffsetY - targetOffsetY) > 1 else {
      applyPendingReplyHighlightIfNeeded(
        messagesProvider: messagesProvider,
        chatMessage: chatMessage,
        animated: true
      )
      return
    }

    collectionView.setContentOffset(
      CGPoint(x: collectionView.contentOffset.x, y: targetOffsetY),
      animated: true
    )
  }

  private func updateReplyHighlightStateForVisibleCells(
    messagesProvider: () -> Messages,
    chatMessage: (Message) -> ChatMessageModel?,
    animated: Bool
  ) {
    guard let collectionView else { return }
    let messages = messagesProvider()
    for indexPath in collectionView.indexPathsForVisibleItems {
      guard messages.indices.contains(indexPath.item) else { continue }
      guard let message = chatMessage(messages[indexPath.item]) else { continue }
      guard let cell = collectionView.cellForItem(at: indexPath) as? ReplyHighlightableCell else {
        continue
      }
      cell.setReplyTargetHighlighted(message.id == highlightedReplyMessageId, animated: animated)
    }
  }

  private func scheduleReplyMessageHighlightReset(
    for messageId: String,
    messagesProvider: @escaping () -> Messages,
    chatMessage: @escaping (Message) -> ChatMessageModel?
  ) {
    replyHighlightResetWorkItem?.cancel()

    let workItem = DispatchWorkItem { [weak self] in
      guard let self, self.highlightedReplyMessageId == messageId else { return }
      self.highlightedReplyMessageId = nil
      self.updateReplyHighlightStateForVisibleCells(
        messagesProvider: messagesProvider,
        chatMessage: chatMessage,
        animated: true
      )
      self.replyHighlightResetWorkItem = nil
    }

    replyHighlightResetWorkItem = workItem
    DispatchQueue.main.asyncAfter(
      deadline: .now() + Self.replyHighlightDuration,
      execute: workItem
    )
  }
}
