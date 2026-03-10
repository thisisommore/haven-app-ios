//
//  TextCell.swift
//  iOSExample
//
//  Created by Om More on 07/03/26.
//

import SwiftUI
import UIKit

class TextCell: UICollectionViewCell {
    static let identifier = String(describing: TextCell.self)
    let label = UILabel()
    let replyImage = UIImageView(image: UIImage(systemName: "arrowshape.turn.up.left.circle.fill"))
    let container = UIView()
    var hasCrossedReplyThreshold = false
    let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    static let paddingY: CGFloat = 4
    static let paddingX: CGFloat = 8
    static let paddingYCal = paddingY * 2
    static let paddingXCal = paddingX * 2
    override init(frame: CGRect) {
        super.init(frame: frame)
        makeUI()
        setupGesture()
    }

    lazy var panGesture = UIPanGestureRecognizer(
        target: self, action: #selector(handlePan(_:)))

    private var originalCenter: CGPoint = .zero

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static let textAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 17)
    ]

    static func size(text: String, width: CGFloat) -> CGSize {
        let r = text.boundingRect(
            with: CGSize(width: width - paddingXCal, height: .greatestFiniteMagnitude),
            options: .usesLineFragmentOrigin,
            attributes: Self.textAttributes,
            context: nil
        )

        // ceil to provide extra space since it might remove all the decimals which can result in smaller space
        return CGSize(width: ceil(r.width) + paddingXCal, height: ceil(r.height) + paddingYCal)
    }
}

extension TextCell {
    func makeUI() {
        label.translatesAutoresizingMaskIntoConstraints = false
        container.translatesAutoresizingMaskIntoConstraints = false
        replyImage.translatesAutoresizingMaskIntoConstraints = false
        label.text = ""
        label.numberOfLines = 0
        container.addSubview(label)
        replyImage.tintColor = .systemOrange
        contentView.addSubview(replyImage)
        contentView.addSubview(container)

        NSLayoutConstraint.activate([
            replyImage.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor, constant: Self.paddingX),
            replyImage.centerYAnchor.constraint(
                equalTo: contentView.centerYAnchor),
            replyImage.widthAnchor.constraint(equalToConstant: 20),
            replyImage.heightAnchor.constraint(equalToConstant: 20),
        ])

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor),
            container.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor),
            container.topAnchor.constraint(equalTo: contentView.topAnchor),
            container.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor),
        ])

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(
                equalTo: container.leadingAnchor, constant: Self.paddingX),
            label.trailingAnchor.constraint(
                equalTo: container.trailingAnchor, constant: -Self.paddingX),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: Self.paddingY),
            label.bottomAnchor.constraint(
                equalTo: container.bottomAnchor, constant: -Self.paddingY),
        ])

        container.backgroundColor = UIColor(Color.messageBubble)
        container.layer.cornerRadius = 16
    }
}

extension TextCell: CellWithContextMenu {
    func makePreview() -> UITargetedPreview {
        let params = UIPreviewParameters()
        params.backgroundColor = container.backgroundColor

        // Match the contentView's layer cornerRadius exactly
        let radius = contentView.layer.cornerRadius
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
