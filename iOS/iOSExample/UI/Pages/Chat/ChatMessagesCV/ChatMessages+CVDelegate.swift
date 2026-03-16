//
//  ChatMessages+CVDelegate.swift
//  iOSExample
//
//  Created by Om More on 07/03/26.
//

import SQLiteData
import UIKit

extension ChatMessagesVC {
  private func text(for message: MessageWithSender) -> NSAttributedString {
    return self.text(for: message.message)
  }

  private func text(for message: ChatMessageModel) -> NSAttributedString {
    if !message.isPlain {
      return message.message.html
    }

    return stripParagraphTags(message.message).attr
  }

  private func replyText(for message: MessageWithSender) -> String? {
    guard let replyTo = message.replyTo else { return nil }
    return self.text(for: replyTo).string
  }

  private func time(for message: MessageWithSender) -> String {
    return message.message.timestamp.formatted(date: .omitted, time: .shortened)
  }

  private func sender(for message: MessageWithSender) -> String? {
    return message.sender
  }

  private func bubbleShape(for message: MessageWithSender, at indexPath: IndexPath)
    -> TextCell.BubbleShape {
    let nextMessage = dataSource.itemIdentifier(for: indexPath.next())
    let hasSenderNext: Bool = {
      guard let nextMessage, case let .text(nextTextMessage) = nextMessage
      else {
        return false
      }
      return nextTextMessage.sender != nil
    }()

    let hasSender = message.sender != nil
    if hasSender {
      return hasSenderNext ? .single : .firstInGroup
    }
    return .middleInGroup
  }
}

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
              withReuseIdentifier: TextCell.identifier,
              for: indexPath
            ) as! TextCell
          cell.label.attributedText = self.text(for: message) // from items
          cell.timeLabel.text = self.time(for: message) // from items
          cell.setSenderName(message.sender, colorHex: message.colorHex)

          cell.setReplyPreview(self.replyText(for: message))
          cell.setBubbleShape(
            self.bubbleShape(for: message, at: indexPath),
            isIncoming: message.message.isIncoming
          )
          cell.onReply = { [weak self] in
            self?.onReply(message.message)
          }
          cell.onReplyPreviewClick = { [weak self] in
            self?.scrollToMessage(message.replyTo)
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
      return TextCell.size(
        text: self.text(for: message),
        sender: self.sender(for: message),
        replyPreview: self.replyText(for: message),
        width: collectionView.availableWidth()
      )
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
      if let textCell = cell as? TextCell {
        textCell.highlight()
      }
      highlightMessageId = nil
    }
  }
}
