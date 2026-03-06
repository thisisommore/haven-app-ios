//
//  Controller+CollectionView.swift
//  iOSExample
//
//  Created by Cursor on 06/03/26.
//

import UIKit

extension Controller: UICollectionViewDataSource, UICollectionViewDelegate {
  func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
    numberOfItemsInCollectionView()
  }

  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath)
    -> UICollectionViewCell
  {
    makeCell(for: indexPath, in: collectionView)
  }

  func collectionView(
    _: UICollectionView,
    willDisplay _: UICollectionViewCell,
    forItemAt indexPath: IndexPath
  ) {
    handleWillDisplayCell(at: indexPath)
  }

  func collectionView(
    _ collectionView: UICollectionView,
    contextMenuConfigurationForItemAt indexPath: IndexPath,
    point: CGPoint
  ) -> UIContextMenuConfiguration? {
    makeContextMenuConfiguration(for: indexPath, in: collectionView, point: point)
  }
}
