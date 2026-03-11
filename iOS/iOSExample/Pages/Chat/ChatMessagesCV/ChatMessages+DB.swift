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
                .where { $0.chatId.eq(self.chatId) }
                .join(MessageSenderModel.all) { message, sender in
                    message.senderId.eq(sender.id)
                }
                .leftJoin(ChatMessageModel.as(ReplyTo.self).all) { message, _, reply in
                    message.replyTo.eq(reply.id)
                }
                .select { message, sender, reply in
                    (message, sender.codename, reply, sender.color)  // reply is optional (LEFT JOIN)
                }
                .order { message, _, _ in
                    message.timestamp.desc()
                }
                .limit(Self.limit * self.page)
                .fetchAll(db)
        }

        cancellable = observation.start(in: self.database, scheduling: .immediate) { error in
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
                                inSameDayAs: message.message.timestamp)
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
                                colorHex: message.colorHex)
                        if dateChanged {
                            return [
                                .date(
                                    message.message.timestamp.formatted(
                                        date: .abbreviated, time: .omitted)),
                                .text(messageWithDisplaySender),
                            ]
                        }
                        return [.text(messageWithDisplaySender)]
                    }
                    .flatMap { $0 })
            if self.initDataDone {

                // Save scroll data so layout can restore it, this prevents scroll jumps when items are added/updated
                let layout = (self.cv.collectionViewLayout as! ChatMessagesCollectionViewLayout)

                // get previously visible element
                // prevIndexForBackUpPoint is last element visible in scroll view
                let item = self.dataSource.itemIdentifier(
                    for: layout.prevIndexForBackUpPoint.idxPath())

                if case .text(let message) = item {
                    // find new index of same element
                    let newIndex = snapshot.itemIdentifiers.firstIndex(where: {
                        guard case .text(let m) = $0 else { return false }
                        return m.message.internalId == message.message.internalId
                    })
                    let prevEleAttr = layout.layoutAttributesForItem(
                        at: layout.prevIndexForBackUpPoint.idxPath())

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
                if wasNearBottom {
                    let numberOfItems = self.cv.numberOfItems(inSection: 0)
                    if numberOfItems > 0 {
                        self.cv.scrollToItem(
                            at: (numberOfItems - 1).idxPath(), at: .bottom, animated: true)
                    }
                }
            } else {
                // Faster for init data
                self.dataSource.applySnapshotUsingReloadData(snapshot)
                self.initDataDone = true
            }

            if let targetId = self.targetScrollMessageId,
                let index = snapshot.itemIdentifiers.firstIndex(where: {
                    if case .text(let m) = $0 {
                        return m.message.internalId == targetId
                    }
                    return false
                })
            {
                // Use async to ensure layout is updated before scrolling
                DispatchQueue.main.async {
                    self.cv.scrollToItem(
                        at: index.idxPath(), at: .centeredVertically, animated: true)
                }
                self.targetScrollMessageId = nil
            }
        }
    }

    func nextPage() {
        isFetchingNextPage = true
        page += 1
        startObservation()
    }

    func isCurrentPageFull() -> Bool {
        return messages.count >= Self.limit * page
    }
}
