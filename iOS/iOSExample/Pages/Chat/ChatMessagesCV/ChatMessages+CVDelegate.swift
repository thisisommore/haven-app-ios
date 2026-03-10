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
                text: text(for: message), width: collectionView.availableWidth()
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

    func collectionView(
        _ collectionView: UICollectionView,
        contextMenuConfigurationForItemsAt indexPaths: [IndexPath],
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard let indexPath = indexPaths.first else { return nil }
        let cell = collectionView.cellForItem(at: indexPath) as? CellWithContextMenu
        return cell?.makeContextMenu()
    }

    func collectionView(
        _ collectionView: UICollectionView,
        contextMenuConfiguration configuration: UIContextMenuConfiguration,
        highlightPreviewForItemAt indexPath: IndexPath
    ) -> UITargetedPreview? {
        return previewForItem(at: indexPath, in: collectionView)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        contextMenuConfiguration configuration: UIContextMenuConfiguration,
        dismissalPreviewForItemAt indexPath: IndexPath
    ) -> UITargetedPreview? {
        return previewForItem(at: indexPath, in: collectionView)
    }

    private func previewForItem(at indexPath: IndexPath, in collectionView: UICollectionView)
        -> UITargetedPreview?
    {
        let cell = collectionView.cellForItem(at: indexPath) as? CellWithContextMenu
        return cell?.makePreview()
    }
}
