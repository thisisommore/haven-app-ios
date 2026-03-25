//
//  Cell.swift
//  iOSExample
//
//  Created by Om More on 10/03/26.
//

import UIKit

protocol CellWithContextMenu: UICollectionViewCell {
  func makePreview() -> UITargetedPreview

  func makeContextMenu() -> UIContextMenuConfiguration
}

protocol CVCell: CVView, UICollectionViewCell {
  static var identifier: String { get }
}

protocol CVView {
  associatedtype Data
  static func size(for: Data, width: CGFloat) -> CGSize
  func render(for: Data)
}

extension CGSize {
  static func maxW(_ sizes: CGSize...) -> CGSize {
    CGSize(
      width: sizes.map(\.width).max() ?? 0,
      height: sizes.map(\.height).reduce(0,+)
    )
  }
}
