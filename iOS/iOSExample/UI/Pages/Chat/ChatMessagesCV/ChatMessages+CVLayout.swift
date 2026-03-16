//
//  ChatMessages+CVLayout.swift
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

protocol ChatMessagesCollectionViewLayoutDelegate: AnyObject {
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

final class ChatMessagesCollectionViewLayout: UICollectionViewLayout {
  static let defaultSpaceBetween: CGFloat = 10
  static let groupedSenderSpaceBetween: CGFloat = 4
  private var cachedAttributes: [UICollectionViewLayoutAttributes] = []
  private var firstPrepare = true
  private var height: CGFloat = 0
  var newIndexForBackUpPoint = 0
  private(set) var prevIndexForBackUpPoint = 0

  var backupPoint: CGPoint = .zero
  override var collectionViewContentSize: CGSize {
    return CGSize(
      width: collectionView!.availableWidth(), height: self.height
    )
  }

  override func prepare() {
    self.height = 0
    self.cachedAttributes.removeAll(keepingCapacity: true)
    let delegate = collectionView?.delegate as! ChatMessagesCollectionViewLayoutDelegate
    if collectionView!.numberOfSections < 1 {
      return
    }
    let dataSource = collectionView?.dataSource as! ChatMessagesVC.DataSource
    let noOfItems = dataSource.collectionView(
      collectionView!, numberOfItemsInSection: 0
    )
    if noOfItems == 0 {
      return
    }
    self.cachedAttributes.reserveCapacity(noOfItems)
    for index in 0 ... (noOfItems - 1) {
      let indexPath = index.idxPath()
      let spacing = self.spacingBeforeItem(at: indexPath, dataSource: dataSource)
      let size = delegate.collectionView(
        collectionView!, layout: self, sizeForItemAt: indexPath
      )

      let alignment = delegate.collectionView(
        collectionView!, layout: self, alignForItemAt: indexPath
      )

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
        origin: CGPoint(x: x, y: self.height + spacing), size: size
      )
      self.height += (size.height + spacing)
      self.cachedAttributes.append(attributes)

      let item = dataSource.itemIdentifier(for: index.idxPath())
      if attributes.frame.intersects(collectionView!.bounds),
         case .text = item {
        self.prevIndexForBackUpPoint = index
      }
    }

    if self.firstPrepare {
      self.firstPrepare = false
      let last = (noOfItems - 1).idxPath()
      collectionView!.scrollToItem(at: last, at: .bottom, animated: false)
    }
    delegate.prepareDone()
  }

  private func spacingBeforeItem(
    at indexPath: IndexPath,
    dataSource: ChatMessagesVC.DataSource
  ) -> CGFloat {
    guard case let .text(message)? = dataSource.itemIdentifier(for: indexPath)
    else {
      return Self.defaultSpaceBetween
    }
    return message.sender == nil ? Self.groupedSenderSpaceBetween : Self.defaultSpaceBetween
  }

  override func layoutAttributesForElements(in rect: CGRect)
    -> [UICollectionViewLayoutAttributes]? {
    var attributesArray = [UICollectionViewLayoutAttributes]()

    guard let lastIndex = cachedAttributes.indices.last,
          let firstMatchIndex = binSearch(rect, start: 0, end: lastIndex)
    else { return attributesArray }

    // Walk backwards from match until we're above the rect
    for attributes in self.cachedAttributes[..<firstMatchIndex].reversed() {
      guard attributes.frame.maxY >= rect.minY else { break }
      attributesArray.append(attributes)
    }

    // Walk forwards from match until we're below the rect
    for attributes in self.cachedAttributes[firstMatchIndex...] {
      guard attributes.frame.minY <= rect.maxY else { break }
      attributesArray.append(attributes)
    }
    return attributesArray
  }

  private func binSearch(_ rect: CGRect, start: Int, end: Int) -> Int? {
    if end < start { return nil }
    let mid = (start + end) / 2
    let attr = self.cachedAttributes[mid]

    if attr.frame.intersects(rect) {
      return mid
    } else if attr.frame.maxY <= rect.minY {
      return self.binSearch(rect, start: mid + 1, end: end)
    } else {
      return self.binSearch(rect, start: start, end: mid - 1)
    }
  }

  override func layoutAttributesForItem(at indexPath: IndexPath)
    -> UICollectionViewLayoutAttributes? {
    guard indexPath.item < self.cachedAttributes.count else { return nil }
    return self.cachedAttributes[indexPath.item]
  }

  override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint)
    -> CGPoint {
    let relocatedElementAttrs: UICollectionViewLayoutAttributes? = self.layoutAttributesForItem(
      at: self.newIndexForBackUpPoint.idxPath()
    )

    guard let relocatedElementAttrs
    else {
      return super.targetContentOffset(forProposedContentOffset: proposedContentOffset)
    }
    let newY = relocatedElementAttrs.frame.origin.y
    let oldY = self.backupPoint.y
    let change = newY - oldY
    let correctedY = proposedContentOffset.y + change

    let minX = -collectionView!.adjustedContentInset.left
    let minY = -collectionView!.adjustedContentInset.top
    guard correctedY >= minY && proposedContentOffset.x >= minX
    else {
      return super.targetContentOffset(forProposedContentOffset: proposedContentOffset)
    }
    return CGPoint(x: proposedContentOffset.x, y: correctedY)
  }
}
