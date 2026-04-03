//
//  ChatMessages+CVDelegate.swift
//  iOSExample
//
//  Created by Om More on 07/03/26.
//

import SQLiteData
import UIKit

extension ChatMessagesVC {
  typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>
  func makeDataSource() -> DataSource { // reusing typealias
    DataSource(
      collectionView: cv,
      cellProvider: { collectionView, indexPath, item -> UICollectionViewCell? in
        switch item {
        case let .text(message):
          let cell =
            collectionView.dequeueReusableCell(
              withReuseIdentifier: MessageBubble.identifier,
              for: indexPath
            ) as! MessageBubble
          cell.render(for: message)
          let canMuteUser = self.chat.isChannel && self.chat.isAdmin && message.message.isIncoming
          cell.canMuteUser = canMuteUser
          cell.onMuteUser = { [weak self] in
            let senderPubKey = message.sender.pubkey
            if
              let self
            { self.onMuteUser(senderPubKey) }
          }

          cell.canDelete = (self.chat.isChannel && self.chat.isAdmin) || !message.message.isIncoming
          cell.onDelete = { [weak self] in
            self?._onDeleteMessage(externalId: message.message.externalId)
          }
          cell.onReplyPreviewClick = { [weak self] in
            self?.scrollToMessage(message.replyTo)
          }

          cell.onReply = { [weak self] in
            self?.onReply(message.message)
          }

          cell.onReact = { [weak self] in
            self?.onReact(message.message)
          }

          cell.onReactionPreviewTap = { [weak self] in
            self?.showReactors(for: message.message)
          }

          cell.onLinkTapped = { [weak self] url in
            let linkString = url.absoluteString
            let linkPreview =
              linkString.count > 100
                ? "\(linkString.prefix(50))..."
                : linkString
            let alert = UIAlertController(
              title: "Leaving Haven",
              message:
              """
              You are about to open an external link. Haven's privacy and security protections do not apply.
              Link \(linkPreview)
              """,
              preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(
              UIAlertAction(title: "Open", style: .destructive) { _ in
                UIApplication.shared.open(url)
              }
            )
            self?.present(alert, animated: true)
          }
          return cell
        case let .date(d):
          let cell =
            collectionView.dequeueReusableCell(
              withReuseIdentifier: DateBadgeCell.identifier,
              for: indexPath
            ) as! DateBadgeCell
          cell.label.text = d
          return cell
        }
      }
    )
  }
}

extension ChatMessagesVC: ChatMessagesCollectionViewLayoutDelegate, UICollectionViewDelegate {
  func collectionView(
    _ collectionView: UICollectionView, layout _: UICollectionViewLayout,
    sizeForItemAt indexPath: IndexPath
  ) -> CGSize {
    let item = dataSource.itemIdentifier(for: indexPath)
    guard let item
    else {
      fatalError("No item at indexPath: \(indexPath)")
    }

    switch item {
    case let .text(message):
      return MessageBubble.size(
        for: message,
        width: collectionView.availableWidth()
      )
    // return TextCell.size(
    //   text: self.text(for: message),
    //   sender: self.sender(for: message),
    //   senderNickname: message.senderNickname,
    //   replyPreview: self.replyText(for: message),
    //   reactionEmojis: message.reactionEmojis,
    //   width: collectionView.bounds.width,
    //   showsClockIcon: message.message.status == .unsent
    // )
    case let .date(d):
      return DateBadgeCell.size(text: d, width: collectionView.availableWidth())
    }
  }

  func prepareDone() {
    isFetchingNextPage = false
  }

  func collectionView(
    _: UICollectionView, layout _: UICollectionViewLayout,
    alignForItemAt indexPath: IndexPath
  ) -> Align {
    let item = dataSource.itemIdentifier(for: indexPath)
    guard let item
    else {
      fatalError("No item at indexPath: \(indexPath)")
    }
    switch item {
    case let .text(message):
      return message.message.isIncoming ? .left : .right
    case .date:
      return .center
    }
  }

  func collectionView(
    _: UICollectionView,
    willEndContextMenuInteraction _: UIContextMenuConfiguration,
    animator: (any UIContextMenuInteractionAnimating)?
  ) {
    let flushPending = { [weak self] in
      guard let self else { return }
      self.shouldWaitForContentMenu = false
      if let pending = self.pendingSnapshot {
        self.pendingSnapshot = nil
        self.applySnapshot(pending)
      }
    }
    if let animator {
      animator.addCompletion(flushPending)
    } else {
      flushPending()
    }
  }

  func collectionView(
    _ collectionView: UICollectionView,
    contextMenuConfigurationForItemsAt indexPaths: [IndexPath],
    point _: CGPoint
  ) -> UIContextMenuConfiguration? {
    guard let indexPath = indexPaths.first else { return nil }
    let cell = collectionView.cellForItem(at: indexPath) as? CellWithContextMenu
    return cell?.makeContextMenu()
  }

  func collectionView(
    _ collectionView: UICollectionView,
    contextMenuConfiguration _: UIContextMenuConfiguration,
    highlightPreviewForItemAt indexPath: IndexPath
  ) -> UITargetedPreview? {
    return self.previewForItem(at: indexPath, in: collectionView)
  }

  func collectionView(
    _ collectionView: UICollectionView,
    contextMenuConfiguration _: UIContextMenuConfiguration,
    dismissalPreviewForItemAt indexPath: IndexPath
  ) -> UITargetedPreview? {
    return self.previewForItem(at: indexPath, in: collectionView)
  }

  private func previewForItem(at indexPath: IndexPath, in collectionView: UICollectionView)
    -> UITargetedPreview? {
    let cell = collectionView.cellForItem(at: indexPath) as? CellWithContextMenu
    return cell?.makePreview()
  }

  func collectionView(
    _: UICollectionView, willDisplay cell: UICollectionViewCell,
    forItemAt indexPath: IndexPath
  ) {
    guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
    if case let .text(message) = item,
       let highlightId = highlightMessageId,
       message.message.id == highlightId {
      if let textCell = cell as? MessageBubble {
        textCell.highlight()
      }
      highlightMessageId = nil
    }
  }
}
