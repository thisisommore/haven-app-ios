//
//  ChatMessages+CV.swift
//  iOSExample
//
//  Created by Om More on 07/03/26.
//

import UIKit

extension ChatMessagesVC {
    func text(for message: ChatMessageModel) -> String {
        return message.newRenderPlainText ?? message.message
    }
}

extension ChatMessagesVC {
    typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>
    func makeDataSource() -> DataSource {  // reusing typealias
        DataSource(
            collectionView: cv,
            cellProvider: { (collectionView, indexPath, item) -> UICollectionViewCell? in
                switch item {
                case .text(let message):
                    let cell =
                        collectionView.dequeueReusableCell(
                            withReuseIdentifier: TextCell.identifier,
                            for: indexPath) as! TextCell
                    cell.label.text = self.text(for: message)  // from items
                    return cell
                }

            })
    }
}

extension ChatMessagesVC: ChatMessagesCollectionViewLayoutDelegate, UICollectionViewDelegate {
    func collectionView(
        _ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let item = dataSource.itemIdentifier(for: indexPath)
        guard let item else {
            fatalError("No item at indexPath: \(indexPath)")
        }
        switch item {
        case .text(let message):
            return TextCell.size(
                text: text(for: message), width: collectionView.bounds.width
            )
        }

    }

    func prepareDone() {
        self.isFetchingNextPage = false
    }

    func collectionView(
        _ collectionView: UICollectionView, layout: UICollectionViewLayout,
        alignForItemAt indexPath: IndexPath
    ) -> Align {
        let item = dataSource.itemIdentifier(for: indexPath)
        guard let item else {
            fatalError("No item at indexPath: \(indexPath)")
        }
        switch item {
        case .text(let message):
            return message.isIncoming ? .left : .right
        }
    }
}
