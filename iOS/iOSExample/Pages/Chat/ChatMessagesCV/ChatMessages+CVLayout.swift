//
//  ChatMessages+CVL.swift
//  iOSExample
//
//  Created by Om More on 07/03/26.
//

import UIKit

let SPACE_BETWEEN: CGFloat = 10

enum Align {
    case left
    case right
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
}

class ChatMessagesCollectionViewLayout: UICollectionViewLayout {

    var cachedAttributes: [UICollectionViewLayoutAttributes] = []
    var firstPrepare = true
    var height: CGFloat = 0
    override var collectionViewContentSize: CGSize {
        return CGSize(width: collectionView!.bounds.width, height: height)
    }

    override func prepare() {
        height = 0
        cachedAttributes.removeAll(keepingCapacity: true)
        let delegate = collectionView?.delegate as! ChatMessagesCollectionViewLayoutDelegate
        let noOfItems = collectionView?.dataSource?.collectionView(
            collectionView!, numberOfItemsInSection: 0)
        if noOfItems == 0 {
            return
        }
        cachedAttributes.reserveCapacity(noOfItems!)
        for index in (0...(noOfItems! - 1)).reversed() {
            let indexPath = IndexPath(item: index, section: 0)
            let size = delegate.collectionView(
                collectionView!, layout: self, sizeForItemAt: indexPath)

            let alignment = delegate.collectionView(
                collectionView!, layout: self, alignForItemAt: indexPath)

            let x = alignment == .left ? 0 : collectionView!.bounds.width - size.width
            let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            attributes.frame = CGRect(origin: CGPoint(x: x, y: height + SPACE_BETWEEN), size: size)
            height += (size.height + SPACE_BETWEEN)
            cachedAttributes.append(attributes)
        }

        if firstPrepare {
            firstPrepare = false
            let last = IndexPath(item: noOfItems! - 1, section: 0)
            collectionView!.scrollToItem(at: last, at: .bottom, animated: false)
        }

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
}
