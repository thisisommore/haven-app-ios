//
//  ChatMessages+CVL.swift
//  iOSExample
//
//  Created by Om More on 07/03/26.
//

import UIKit

enum Align {
    case left
    case right
    case center
}

extension UICollectionView {
    func availableWidth() -> CGFloat {
        bounds.width - (contentInset.left + contentInset.right)
    }
}
protocol ChatMessagesCollectionViewLayoutDelegate {
    func collectionView(
        _ collectionView: UICollectionView, layout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize

    func collectionView(
        _ collectionView: UICollectionView, layout: UICollectionViewLayout,
        alignForItemAt indexPath: IndexPath
    ) -> Align

    func prepareDone()
}

class ChatMessagesCollectionViewLayout: UICollectionViewLayout {
    static let defaultSpaceBetween: CGFloat = 10
    static let groupedSenderSpaceBetween: CGFloat = 1
    var cachedAttributes: [UICollectionViewLayoutAttributes] = []
    var firstPrepare = true
    var height: CGFloat = 0
    var newIndexForBackUpPoint = 0
    var prevIndexForBackUpPoint = 0

    var backupPoint: CGPoint = .zero
    override var collectionViewContentSize: CGSize {
        return CGSize(
            width: collectionView!.availableWidth(), height: height)
    }

    override func prepare() {
        height = 0
        cachedAttributes.removeAll(keepingCapacity: true)
        let delegate = collectionView?.delegate as! ChatMessagesCollectionViewLayoutDelegate
        if collectionView!.numberOfSections < 1 {
            return
        }
        let dataSource = collectionView?.dataSource as! ChatMessagesVC.DataSource
        let noOfItems = dataSource.collectionView(
            collectionView!, numberOfItemsInSection: 0)
        if noOfItems == 0 {
            return
        }
        cachedAttributes.reserveCapacity(noOfItems)
        for index in (0...(noOfItems - 1)) {
            let indexPath = index.idxPath()
            let spacing = spacingBeforeItem(at: indexPath, dataSource: dataSource)
            let size = delegate.collectionView(
                collectionView!, layout: self, sizeForItemAt: indexPath)

            let alignment = delegate.collectionView(
                collectionView!, layout: self, alignForItemAt: indexPath)

            let x =
                switch alignment {
                case .left:
                    CGFloat(0)
                case .right:
                    collectionView!.availableWidth() - size.width
                case .center:
                    (collectionView!.availableWidth() - size.width) / 2
                }
            let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            attributes.frame = CGRect(
                origin: CGPoint(x: x, y: height + spacing), size: size)
            height += (size.height + spacing)
            cachedAttributes.append(attributes)

            let item = dataSource.itemIdentifier(for: index.idxPath())
            if attributes.frame.intersects(collectionView!.bounds),
                case .text = item
            {
                prevIndexForBackUpPoint = index
            }
        }

        if firstPrepare {
            firstPrepare = false
            let last = IndexPath(item: noOfItems - 1, section: 0)
            collectionView!.scrollToItem(at: last, at: .bottom, animated: false)
            delegate.prepareDone()
        }

    }
    private func spacingBeforeItem(
        at indexPath: IndexPath,
        dataSource: ChatMessagesVC.DataSource
    ) -> CGFloat {
        guard case .text(let message)? = dataSource.itemIdentifier(for: indexPath) else {
            return Self.defaultSpaceBetween
        }
        return message.1 == nil ? Self.groupedSenderSpaceBetween : Self.defaultSpaceBetween
    }

    override func layoutAttributesForElements(in rect: CGRect)
        -> [UICollectionViewLayoutAttributes]?
    {
        var attributesArray = [UICollectionViewLayoutAttributes]()

        guard let lastIndex = cachedAttributes.indices.last,
            let firstMatchIndex = binSearch(rect, start: 0, end: lastIndex)
        else { return attributesArray }

        // Walk backwards from match until we're above the rect
        for attributes in cachedAttributes[..<firstMatchIndex].reversed() {
            guard attributes.frame.maxY >= rect.minY else { break }
            attributesArray.append(attributes)
        }

        // Walk forwards from match until we're below the rect
        for attributes in cachedAttributes[firstMatchIndex...] {
            guard attributes.frame.minY <= rect.maxY else { break }
            attributesArray.append(attributes)
        }
        return attributesArray
    }

    private func binSearch(_ rect: CGRect, start: Int, end: Int) -> Int? {
        if end < start { return nil }
        let mid = (start + end) / 2
        let attr = cachedAttributes[mid]

        if attr.frame.intersects(rect) {
            return mid
        } else if attr.frame.maxY <= rect.minY {
            return binSearch(rect, start: mid + 1, end: end)
        } else {
            return binSearch(rect, start: start, end: mid - 1)
        }
    }

    override func layoutAttributesForItem(at indexPath: IndexPath)
        -> UICollectionViewLayoutAttributes?
    {
        return cachedAttributes[indexPath.item]
    }

    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint)
        -> CGPoint
    {
        let relocatedElementAttrs: UICollectionViewLayoutAttributes? = layoutAttributesForItem(
            at: newIndexForBackUpPoint.idxPath())

        guard let relocatedElementAttrs else {
            return super.targetContentOffset(forProposedContentOffset: proposedContentOffset)
        }
        let newY = relocatedElementAttrs.frame.origin.y
        let oldY = backupPoint.y
        let change = newY - oldY
        let correctedY = proposedContentOffset.y + change

        let minX = -collectionView!.adjustedContentInset.left
        let minY = -collectionView!.adjustedContentInset.top
        guard correctedY >= minY && proposedContentOffset.x >= minX else {
            return super.targetContentOffset(forProposedContentOffset: proposedContentOffset)
        }
        return CGPoint(x: proposedContentOffset.x, y: correctedY)
    }
}
