//
//  TextCell+Context.swift
//  iOSExample
//
//  Created by Om More on 10/03/26.
//
import UIKit

extension UIView {
    var rectCorners: UIRectCorner {
        var corners: UIRectCorner = []
        let masked = layer.maskedCorners
        if masked.contains(.layerMinXMinYCorner) { corners.insert(.topLeft) }
        if masked.contains(.layerMaxXMinYCorner) { corners.insert(.topRight) }
        if masked.contains(.layerMinXMaxYCorner) { corners.insert(.bottomLeft) }
        if masked.contains(.layerMaxXMaxYCorner) { corners.insert(.bottomRight) }
        return corners
    }
}
extension TextCell: CellWithContextMenu {
    func makePreview() -> UITargetedPreview {
        let params = UIPreviewParameters()
        params.backgroundColor = container.backgroundColor

        // Preview only the bubble, excluding the reply preview row.
        let radius = container.layer.cornerRadius
        params.visiblePath = UIBezierPath(
            roundedRect: container.bounds,
            byRoundingCorners: container.rectCorners,
            cornerRadii: CGSize(width: radius, height: radius),
        )

        return UITargetedPreview(view: container, parameters: params)
    }

    func makeContextMenu() -> UIContextMenuConfiguration {
        return UIContextMenuConfiguration(actionProvider: { _ in
            UIMenu(children: [
                UIAction(title: "Reply", image: UIImage(systemName: "arrowshape.turn.up.left")) {
                    [weak self] _ in
                    self?.onReply?()
                },
                UIAction(title: "Copy", image: UIImage(systemName: "doc.on.doc")) {
                    [weak self] _ in
                    if let text = self?.label.text {
                        UIPasteboard.general.string = text
                    }
                }
            ])
        })
    }

}
