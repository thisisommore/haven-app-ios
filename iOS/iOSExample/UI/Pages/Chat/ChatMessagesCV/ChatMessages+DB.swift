//
//  ChatMessages+DB.swift
//  iOSExample
//
//  Created by Om More on 10/03/26.
//

import struct GRDB.ValueObservation
import SQLiteData
import UIKit

extension ChatMessagesVC {
  typealias ObservedMessages = [(
    ChatMessageModel,
    MessageSenderModel?,
    TableAlias<ChatMessageModel, ChatMessagesVC.ReplyTo>?.QueryOutput,
    [String]
  )]

  enum ReplyTo: AliasName {}
  func startObservation() {
    cancellable?.cancel()

    // Data obervation and initialization
    let observation = ValueObservation.tracking { db in
      try self.makeObservationPayload(db: db)
    }

    cancellable = observation.start(in: database, scheduling: .immediate) { _ in
      // Handle error
    } onChange: { (_messages: ObservedMessages) in
      self.messages = _messages.reversed().map {
        var strArr = $0.3
        if strArr.count >= 3 {
          strArr[2] = "+"
        }
        return MessageWithSender(
          message: $0.0, sender: $0.1, replyTo: $0.2,
          reactionEmojis: strArr
        )
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
                  reactionEmojis: message.reactionEmojis
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
        if wasNearBottom, !self.cv.isTracking, !self.cv.isDragging, !self.cv.isDecelerating {
          self.withScrollToButtomDisabled { enable in
            // Calculates differences and applies them
            self.dataSource.apply(snapshot, animatingDifferences: false)
            // If user was near bottom, scroll to bottom to show new message
            let numberOfItems = self.cv.numberOfItems(inSection: 0)
            if numberOfItems > 0 {
              self.cv.scrollToItem(
                at: (numberOfItems - 1).idxPath(), at: .bottom, animated: true
              )
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [enable] in
              enable()
            }
          }
        } else {
          self.dataSource.apply(snapshot, animatingDifferences: false)
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
            if let cell = self.cv.cellForItem(at: indexPath) as? MessageBubble {
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

  private func makeObservationPayload(db: Database) throws -> ObservedMessages {
    let whereC = ChatMessageModel
      .where {
        $0.chatId.eq(self.chatId)
          && ($0.status.eq(MessageStatus.unsent)
            || $0.status.eq(MessageStatus.delivered)
            || $0.status.eq(MessageStatus.sent))
      }

    let joinSender = whereC.leftJoin(MessageSenderModel.all) { message, sender in
      message.senderId.eq(sender.id)
    }

    let joinReplyTo = joinSender.leftJoin(ChatMessageModel.as(ReplyTo.self).all) { message, _, reply in
      message.replyTo.eq(reply.externalId)
    }
    return try
      joinReplyTo.select { message, sender, reply in
        let first3UniqueReactions = MessageReactionModel
          .where { $0.targetMessageId.eq(message.externalId) && $0.status.neq(MessageStatus.failed) } // correlated
          .select(\.emoji)
          .distinct()
          .limit(3)

        return (
          message,
          sender,
          reply,
          #sql(
            "coalesce((SELECT json_group_array(emoji) FROM (\(first3UniqueReactions))), '[]')",
            as: [String].JSONRepresentation.self
          )
        )
      }
      .order { message, _, _ in
        message.timestamp.desc()
      }
      .limit(Self.limit * self.page)
      .fetchAll(db)
  }
}
