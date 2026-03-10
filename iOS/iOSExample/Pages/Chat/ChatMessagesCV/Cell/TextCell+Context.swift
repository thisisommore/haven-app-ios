//
//  TextCell+Context.swift
//  iOSExample
//
//  Created by Om More on 10/03/26.
//
import UIKit

extension TextCell: CellWithContextMenu {
    func makePreview() -> UITargetedPreview {
        let params = UIPreviewParameters()
        params.backgroundColor = container.backgroundColor

        // Match the contentView's layer cornerRadius exactly
        let radius = container.layer.cornerRadius
        params.visiblePath = UIBezierPath(
            roundedRect: contentView.bounds,
            cornerRadius: radius
        )

        return UITargetedPreview(view: contentView, parameters: params)
    }

    func makeContextMenu() -> UIContextMenuConfiguration {
        return UIContextMenuConfiguration(actionProvider: { _ in
            UIMenu(children: [
                UIAction(title: "Reply", image: UIImage(systemName: "arrowshape.turn.up.left")) {
                    _ in
                    // handle reply
                }
            ])
        })
    }

}
