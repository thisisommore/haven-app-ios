//
//  ChatMessages+DB.swift
//  iOSExample
//
//  Created by Om More on 10/03/26.
//

import GRDB
import SQLiteData
import UIKit

extension ChatMessagesVC {
  enum ReplyTo: AliasName {}
  func startObservation() {
    cancellable?.cancel()

    // Data obervation and initialization
    let observation = ValueObservation.tracking { db in
      try ChatMessageModel
        .where {
          $0.chatId.eq(self.chatId)
            && ($0.status.eq(MessageStatus.delivered)
              || $0.status.eq(MessageStatus.sent))
        }
        .join(MessageSenderModel.all) { message, sender in
          message.senderId.eq(sender.id)
        }
        .leftJoin(ChatMessageModel.as(ReplyTo.self).all) { message, _, reply in
          message.replyTo.eq(reply.externalId)
        }
        .select { message, sender, reply in
          (message, sender.codename, reply, sender.color) // reply is optional (LEFT JOIN)
        }
        .order { message, _, _ in
          message.timestamp.desc()
        }
        .limit(Self.limit * self.page)
        .fetchAll(db)
    }

    cancellable = observation.start(in: database, scheduling: .immediate) { _ in
      // Handle error
    } onChange: { (_messages: [(ChatMessageModel, String?, ChatMessageModel?, Int?)]) in
      self.messages = _messages.reversed().map {
        MessageWithSender(message: $0.0, sender: $0.1, replyTo: $0.2, colorHex: $0.3)
      }
      var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
      snapshot.appendSections([0])
      snapshot.appendItems(
        self.messages.enumerated()
          .map { index, message -> [Item] in
            let dateChanged =
              index == 0
                || !Calendar.current.isDate(
                  self.messages[index - 1].message.timestamp,
                  inSameDayAs: message.message.timestamp
                )
            let senderChanged =
              index == 0
                || self.messages[index - 1].message.senderId != message.message.senderId
                || self.messages[index - 1].sender != message.sender
            let shouldShowSender = dateChanged || senderChanged
            let messageWithDisplaySender: MessageWithSender =
              shouldShowSender
                ? message
                : MessageWithSender(
                  message: message.message, sender: nil, replyTo: message.replyTo,
                  colorHex: message.colorHex
                )
            if dateChanged {
              return [
                .date(
                  message.message.timestamp.formatted(
                    date: .abbreviated, time: .omitted
                  )
                ),
                .text(messageWithDisplaySender),
              ]
            }
            return [.text(messageWithDisplaySender)]
          }
          .flatMap { $0 }
      )
      if self.initDataDone {
        // Save scroll data so layout can restore it, this prevents scroll jumps when items are added/updated
        let layout = (self.cv.collectionViewLayout as! ChatMessagesCollectionViewLayout)

        // get previously visible element
        // prevIndexForBackUpPoint is last element visible in scroll view
        let item = self.dataSource.itemIdentifier(
          for: layout.prevIndexForBackUpPoint.idxPath()
        )

        if case let .text(message) = item {
          // find new index of same element
          let newIndex = snapshot.itemIdentifiers.firstIndex(where: {
            guard case let .text(m) = $0 else { return false }
            return m.message.id == message.message.id
          })
          let prevEleAttr = layout.layoutAttributesForItem(
            at: layout.prevIndexForBackUpPoint.idxPath()
          )

          // store new index and prev element origin
          if let newIndex, let prevEleAttr {
            layout.newIndexForBackUpPoint = newIndex
            layout.backupPoint =
              prevEleAttr.frame
                .origin
          }
        }

        let wasNearBottom = self.isNearBottom
        // Calculates differences and applies them
        self.dataSource.apply(snapshot, animatingDifferences: false)

        // If user was near bottom, scroll to bottom to show new message
        if wasNearBottom, !self.cv.isTracking, !self.cv.isDragging, !self.cv.isDecelerating {
          let numberOfItems = self.cv.numberOfItems(inSection: 0)
          if numberOfItems > 0 {
            self.cv.scrollToItem(
              at: (numberOfItems - 1).idxPath(), at: .bottom, animated: true
            )
          }
        }
      } else {
        // Faster for init data
        self.dataSource.applySnapshotUsingReloadData(snapshot)
        self.initDataDone = true
      }

      if let targetId = self.targetScrollMessageId,
         let index = snapshot.itemIdentifiers.firstIndex(where: {
           if case let .text(m) = $0 {
             return m.message.id == targetId
           }
           return false
         }) {
        self.highlightMessageId = targetId
        // Use async to ensure layout is updated before scrolling
        DispatchQueue.main.async {
          let indexPath = index.idxPath()
          self.cv.scrollToItem(
            at: indexPath, at: .centeredVertically, animated: true
          )

          DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let cell = self.cv.cellForItem(at: indexPath) as? TextCell {
              if self.highlightMessageId == targetId {
                cell.highlight()
                self.highlightMessageId = nil
              }
            }
          }
        }
        self.targetScrollMessageId = nil
      }
    }
  }

  func nextPage() {
    isFetchingNextPage = true
    page += 1
    self.startObservation()
  }

  func isCurrentPageFull() -> Bool {
    return messages.count >= Self.limit * page
  }
}
