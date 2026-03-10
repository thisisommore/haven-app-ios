//
//  TextCell.swift
//  iOSExample
//
//  Created by Om More on 07/03/26.
//

import SnapKit
import SwiftUI
import UIKit

class TextCell: UICollectionViewCell {
    static let identifier = String(describing: TextCell.self)
    let label = UILabel()
    let timeLabel = UILabel()
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

    private static let msgTextAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 17)
    ]

    private static let timeTextAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 8)
    ]

    static let lastWidth: CGFloat = 0
    static var timeRecCached: CGRect = .zero

    static func size(text: String, width: CGFloat) -> CGSize {
        let r = text.boundingRect(
            with: CGSize(width: width - paddingXCal, height: .greatestFiniteMagnitude),
            options: .usesLineFragmentOrigin,
            attributes: Self.msgTextAttributes,
            context: nil
        )
        let timeR = {
            if Self.lastWidth != width || Self.timeRecCached == .zero {
                let timeR = "10:10pm".boundingRect(
                    with: CGSize(width: width - paddingXCal, height: .greatestFiniteMagnitude),
                    options: .usesLineFragmentOrigin,
                    attributes: Self.timeTextAttributes,
                    context: nil
                )
                Self.timeRecCached = timeR
            }
            return Self.timeRecCached
        }()

        let width = max(ceil(r.width), ceil(timeR.width)) + paddingXCal
        let height = ceil(r.height) + ceil(timeR.height) + paddingYCal

        // ceil to provide extra space since it might remove all the decimals which can result in smaller space
        return CGSize(width: width, height: height)
    }
}

extension TextCell {
    func makeUI() {
        contentView.addSubview(replyImage)
        contentView.addSubview(container)
        container.addSubview(label)
        container.addSubview(timeLabel)

        replyImage.snp.makeConstraints {
            $0.leading.equalTo(contentView).offset(Self.paddingX)
            $0.centerY.equalTo(contentView)
            $0.size.equalTo(20)  // Combines width and height
        }
        replyImage.tintColor = .systemOrange

        container.snp.makeConstraints {
            $0.edges.equalTo(contentView)  // Automatically pins all 4 sides
        }
        container.backgroundColor = UIColor(Color.messageBubble)
        container.layer.cornerRadius = 16

        label.snp.makeConstraints {
            $0.leading.equalTo(container).offset(Self.paddingX)
            $0.trailing.equalTo(container).offset(-Self.paddingX)
            $0.top.equalTo(container).offset(Self.paddingY)
            // We'll let timeLabel handle the vertical spacing between the two
        }
        label.text = ""
        label.numberOfLines = 0

        timeLabel.snp.makeConstraints {
            $0.trailing.equalTo(container).offset(-Self.paddingX)
            $0.top.equalTo(label.snp.bottom).offset(Self.paddingY)  // Defines the vertical stack
            $0.bottom.equalTo(container).offset(-Self.paddingY)
        }
        timeLabel.textColor = .gray
        timeLabel.font = UIFont.systemFont(ofSize: 8)
        timeLabel.text = ""

    }
}
