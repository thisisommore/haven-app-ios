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
