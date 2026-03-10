//
//  ChatMessages+DB.swift
//  iOSExample
//
//  Created by Om More on 10/03/26.
//

import GRDB
import UIKit

extension ChatMessagesVC {
    func startObservation() {
        cancellable?.cancel()

        // Data obervation and initialization
        let observation = ValueObservation.tracking { db in
            let whereC = ChatMessageModel.where { $0.chatId.eq(self.chatId) }
            let joinC =
                whereC.join(
                    MessageSenderModel.all,
                    on: { message, sender in
                        message.senderId.eq(sender.id)
                    }
                ).select { message, sender in
                    (message, sender.codename)
                }
            return try joinC.order { message, sender in
                message.timestamp.desc()
            }
            .limit(Self.limit * self.page).fetchAll(db)
        }

        cancellable = observation.start(in: self.database, scheduling: .immediate) { error in
            // Handle error
        } onChange: { (_messages: [(ChatMessageModel, String)]) in
            self.messages = _messages.reversed()
            var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
            snapshot.appendSections([0])
            snapshot.appendItems(
                self.messages.enumerated()
                    .map { index, message -> [Item] in
                        let dateChanged =
                            index == 0
                            || !Calendar.current.isDate(
                                self.messages[index - 1].0.timestamp,
                                inSameDayAs: message.0.timestamp)
                        if dateChanged {
                            return [
                                .date(
                                    message.0.timestamp.formatted(
                                        date: .abbreviated, time: .omitted)),
                                .text(message),
                            ]
                        }
                        return [.text(message)]
                    }
                    .flatMap { $0 })
            if self.initDataDone {

                // Save scroll data so layout can restore it, this prevents scroll jumps when items are added/updated
                let layout = (self.cv.collectionViewLayout as! ChatMessagesCollectionViewLayout)

                // get previously visible element
                // prevIndexForBackUpPoint is last element visible in scroll view
                let item = self.dataSource.itemIdentifier(
                    for: IndexPath(item: layout.prevIndexForBackUpPoint, section: 0))

                if case .text(let message) = item {
                    // find new index of same element
                    let newIndex = snapshot.itemIdentifiers.firstIndex(where: {
                        guard case .text(let m) = $0 else { return false }
                        return m.0.internalId == message.0.internalId
                    })
                    let prevEleAttr = layout.layoutAttributesForItem(
                        at: IndexPath(item: layout.prevIndexForBackUpPoint, section: 0))

                    // store new index and prev element origin
                    if let newIndex, let prevEleAttr {
                        layout.newIndexForBackUpPoint = newIndex
                        layout.backupPoint =
                            prevEleAttr.frame
                            .origin
                    }
                }

                // Calculates differences and applies them
                self.dataSource.apply(snapshot, animatingDifferences: false)
            } else {
                // Faster for init data
                self.dataSource.applySnapshotUsingReloadData(snapshot)
                self.initDataDone = true
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
