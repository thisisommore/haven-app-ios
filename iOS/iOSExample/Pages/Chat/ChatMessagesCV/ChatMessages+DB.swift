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
            try ChatMessageModel.where { $0.chatId.eq(self.chatId) }.order {
                $0.timestamp.desc()
            }
            .limit(Self.limit * self.page).fetchAll(db)
        }

        cancellable = observation.start(in: self.database, scheduling: .immediate) { error in
            // Handle error
        } onChange: { (_messages: [ChatMessageModel]) in
            self.messages = _messages.reversed()
            var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
            snapshot.appendSections([0])

            snapshot.appendItems(self.messages.map { Message.text($0) })
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
                        return m.internalId == message.internalId
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
