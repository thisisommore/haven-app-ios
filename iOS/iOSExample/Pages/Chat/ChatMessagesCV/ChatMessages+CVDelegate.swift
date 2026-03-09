//
//  ChatMessages+CV.swift
//  iOSExample
//
//  Created by Om More on 07/03/26.
//

import UIKit

extension ChatMessagesVC: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int)
        -> Int
    {
        return messages.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath)
        -> UICollectionViewCell
    {
        let c =
            collectionView.dequeueReusableCell(
                withReuseIdentifier: TextCell.identifier, for: indexPath) as! TextCell
        c.label.text = messages[indexPath.item].message
        return c
    }
}

extension ChatMessagesVC: ChatMessagesCollectionViewLayoutDelegate, UICollectionViewDelegate {
    func collectionView(
        _ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        return TextCell.size(
            text: messages[indexPath.item].message, width: collectionView.bounds.width
        )
    }

    func collectionView(
        _ collectionView: UICollectionView, layout: UICollectionViewLayout,
        alignForItemAt indexPath: IndexPath
    ) -> Align {
        return messages[indexPath.item].isIncoming ? .left : .right
    }
}
