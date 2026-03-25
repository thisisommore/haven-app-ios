import UIKit

extension MessageBubble: CellWithContextMenu {
  func makePreview() -> UITargetedPreview {
    let view = c
    let rectCorners: UIRectCorner = {
      var corners: UIRectCorner = []
      let masked = view.layer.maskedCorners
      if masked.contains(.layerMinXMinYCorner) { corners.insert(.topLeft) }
      if masked.contains(.layerMaxXMinYCorner) { corners.insert(.topRight) }
      if masked.contains(.layerMinXMaxYCorner) { corners.insert(.bottomLeft) }
      if masked.contains(.layerMaxXMaxYCorner) { corners.insert(.bottomRight) }
      return corners
    }()

    let params: UIPreviewParameters = {
      let params = UIPreviewParameters()
      params.backgroundColor = view.backgroundColor

      // Preview only the bubble, excluding the reply preview row.
      let radius = view.layer.cornerRadius
      params.visiblePath = UIBezierPath(
        roundedRect: view.bounds,
        byRoundingCorners: rectCorners,
        cornerRadii: CGSize(width: radius, height: radius)
      )
      return params
    }()

    return UITargetedPreview(view: view, parameters: params)
  }

  func makeContextMenu() -> UIContextMenuConfiguration {
    return UIContextMenuConfiguration(actionProvider: { _ in
      UIMenu(children: [
        UIAction(title: "React", image: UIImage(systemName: "face.smiling")) { [weak self] _ in
          self?.onReact?()
        },
        UIAction(title: "Reply", image: UIImage(systemName: "arrowshape.turn.up.left")) { [weak self] _ in
          self?.onReply?()
        },
        UIAction(title: "Copy", image: UIImage(systemName: "doc.on.doc")) { [weak self] _ in
          if let text = self?.msgLabel.text {
            UIPasteboard.general.string = text
          }
        },
      ])
    })
  }
}
