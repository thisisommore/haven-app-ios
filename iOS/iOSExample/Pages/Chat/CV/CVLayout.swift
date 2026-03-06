//
//  CVLayout.swift
//  iOSExample
//
//  Created by Om More on 06/03/26.
//
import UIKit
class CVLayout: UICollectionViewLayout {
  var topOffset: CGFloat = 0
  var height: CGFloat = 0
  var delegate: Deletage
  var didInitialScrollToBottom = false
  var pendingAnchor: (indexPath: IndexPath, oldMinY: CGFloat)?

  init(delegate: Deletage) {
    self.delegate = delegate
    super.init()
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // 1. Define the overall scroll area (just 5x5)
  override var collectionViewContentSize: CGSize {
    guard let cv = collectionView else { return .zero }
    let w = cv.bounds.width - cv.adjustedContentInset.left - cv.adjustedContentInset.right
    return CGSize(width: w, height: height)
  }

  var cache = [UICollectionViewLayoutAttributes]()
  override func prepare() {
    guard let collectionView else {
      fatalError("collectionView must exist")
    }
    cache.removeAll(keepingCapacity: true)

    // First pass: calculate total content height
    var totalContentHeight: CGFloat = 0
    let w =
      collectionView.bounds.width - collectionView.adjustedContentInset.left
      - collectionView.adjustedContentInset.right
    let numberOfItems = collectionView.numberOfItems(inSection: 0)

    var sizes = [CGSize]()
    sizes.reserveCapacity(numberOfItems)

    for item in 0..<numberOfItems {
      let indexPath = IndexPath(item: item, section: 0)
      let size = delegate.getSize(at: indexPath, width: w)
      let spacingAfter = delegate.spacingAfterItem(at: indexPath)
      sizes.append(size.size)
      totalContentHeight += size.height + spacingAfter
    }

    // Determine starting Y offset to push content to bottom if it's smaller than the view
    let visibleHeight =
      collectionView.bounds.height - collectionView.adjustedContentInset.top
      - collectionView.adjustedContentInset.bottom
    topOffset = max(0, visibleHeight - totalContentHeight)
    height = max(totalContentHeight, visibleHeight)

    // Second pass: create attributes with the adjusted starting offset
    for item in 0..<numberOfItems {
      let indexPath = IndexPath(item: item, section: 0)
      let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
      let size = sizes[item]
      let x = delegate.getXOrigin(at: indexPath, availableWidth: w, cellWidth: size.width)
      attributes.frame = CGRect(x: x, y: topOffset, width: size.width, height: size.height)
      topOffset += size.height + delegate.spacingAfterItem(at: indexPath)
      cache.append(attributes)
    }

    guard collectionView.bounds.width > 0 else { return }

    if !didInitialScrollToBottom {
      collectionView.setContentOffset(
        CGPoint(
          x: collectionView.contentOffset.x,
          y: height - collectionView.bounds.height
            + collectionView.adjustedContentInset.bottom),
        animated: false
      )
      didInitialScrollToBottom = true
      return
    }

  }
  private func scrollToBottom(in collectionView: UICollectionView) {
    let minOffsetY = -collectionView.adjustedContentInset.top
    let maxOffsetY = max(
      minOffsetY,
      collectionView.contentSize.height
        - collectionView.bounds.height
        + collectionView.adjustedContentInset.bottom
    )
    print("CV:setContentOffset:Scrool")
    collectionView.setContentOffset(
      CGPoint(x: collectionView.contentOffset.x, y: maxOffsetY),
      animated: false
    )
  }
  // 2. Generate attributes for a specific item on the fly
  override func layoutAttributesForItem(at indexPath: IndexPath)
    -> UICollectionViewLayoutAttributes?
  {
    if cache.count > indexPath.item {
      return cache[indexPath.item]
    }
    return nil
  }

  // 3. Return attributes for all items in the visible area
  override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]?
  {
    guard !cache.isEmpty else { return [] }

    let startIndex = firstIndexWithMaxY(atLeast: rect.minY)
    guard startIndex < cache.count else { return [] }

    var visibleAttributes: [UICollectionViewLayoutAttributes] = []
    var index = startIndex
    while index < cache.count {
      let attributes = cache[index]
      if attributes.frame.minY > rect.maxY {
        break
      }
      visibleAttributes.append(attributes)
      index += 1
    }
    return visibleAttributes
  }

  private func firstIndexWithMaxY(atLeast minY: CGFloat) -> Int {
    var low = 0
    var high = cache.count

    while low < high {
      let mid = low + (high - low) / 2
      if cache[mid].frame.maxY < minY {
        low = mid + 1
      } else {
        high = mid
      }
    }
    return low
  }

  override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint)
    -> CGPoint
  {
    guard let pendingAnchor = pendingAnchor,
      let attributes = layoutAttributesForItem(at: pendingAnchor.indexPath)
    else {
      return super.targetContentOffset(forProposedContentOffset: proposedContentOffset)
    }

    let newMinY = attributes.frame.minY
    var newOffset = collectionView?.contentOffset ?? proposedContentOffset
    newOffset.y += (newMinY - pendingAnchor.oldMinY)
    guard let collectionView = collectionView else { fatalError("no cv") }
    let minOffsetY = -collectionView.adjustedContentInset.top
    let maxOffsetY = max(
      minOffsetY,
      collectionViewContentSize.height
        - collectionView.bounds.height
        + collectionView.adjustedContentInset.bottom
    )
    newOffset.y = min(max(newOffset.y, minOffsetY), maxOffsetY)

    return newOffset
  }

  override func finalizeCollectionViewUpdates() {
    super.finalizeCollectionViewUpdates()
    pendingAnchor = nil
  }
}
