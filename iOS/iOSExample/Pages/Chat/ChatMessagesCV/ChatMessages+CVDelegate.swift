//
//  ChatMessages+CV.swift
//  iOSExample
//
//  Created by Om More on 07/03/26.
//

import UIKit

extension ChatMessagesVC {
    func message(at indexPath: IndexPath) -> String {
        let message = messages[indexPath.item]
        return message.newRenderPlainText ?? message.message
    }
}

extension ChatMessagesVC {
    typealias DataSource = UICollectionViewDiffableDataSource<Section, ChatMessageModel>
    func makeDataSource() -> DataSource {  // reusing typealias
        DataSource(
            collectionView: cv,
            cellProvider: { (collectionView, indexPath, item) -> UICollectionViewCell? in
                let cell =
                    collectionView.dequeueReusableCell(
                        withReuseIdentifier: TextCell.identifier,
                        for: indexPath) as! TextCell
                cell.label.text = self.message(at: indexPath)  // from items
                return cell
            })
    }
}

extension ChatMessagesVC: ChatMessagesCollectionViewLayoutDelegate, UICollectionViewDelegate {
    func collectionView(
        _ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        return TextCell.size(
            text: message(at: indexPath), width: collectionView.bounds.width
        )
    }

    func collectionView(
        _ collectionView: UICollectionView, layout: UICollectionViewLayout,
        alignForItemAt indexPath: IndexPath
    ) -> Align {
        return messages[indexPath.item].isIncoming ? .left : .right
    }
}
