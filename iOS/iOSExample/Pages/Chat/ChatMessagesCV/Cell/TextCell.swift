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
    enum BubbleShape {
        case single
        case firstInGroup
        case middleInGroup
    }

    static let identifier = String(describing: TextCell.self)
    let label = UILabel()
    let timeLabel = UILabel()
    let senderNameLabel = UILabel()
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
    private var messageTopToSenderConstraint: Constraint?
    private var messageTopToContainerConstraint: Constraint?

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static let senderNameTextAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 8)
    ]

    private static let msgTextAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 17)
    ]

    private static let timeTextAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 8)
    ]

    static let lastWidth: CGFloat = 0
    static var timeRecCached: CGRect = .zero

    static func size(text: String, sender: String?, width: CGFloat) -> CGSize {
        let senderNameR: CGRect = {
            guard let sender else {
                return .zero
            }
            return sender.boundingRect(
                with: CGSize(width: width - paddingXCal, height: .greatestFiniteMagnitude),
                options: .usesLineFragmentOrigin,
                attributes: Self.senderNameTextAttributes,
                context: nil
            )

        }()

        let messageR = text.boundingRect(
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

        let width =
            max(ceil(messageR.width), ceil(timeR.width), ceil(senderNameR.width)) + paddingXCal
        let height =
            ceil(messageR.height) + ceil(timeR.height) + ceil(senderNameR.height) + paddingYCal

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
        container.addSubview(senderNameLabel)
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
        container.layer.cornerRadius = 12
        container.layer.masksToBounds = true
        senderNameLabel.snp.makeConstraints {
            $0.leading.equalTo(container).offset(Self.paddingX)
            $0.top.equalTo(container).offset(Self.paddingY)
        }
        senderNameLabel.textColor = .red
        senderNameLabel.font = UIFont.systemFont(ofSize: 8)
        senderNameLabel.text = ""

        label.snp.makeConstraints {
            $0.leading.equalTo(container).offset(Self.paddingX)
            $0.trailing.equalTo(container).offset(-Self.paddingX)
            messageTopToSenderConstraint = $0.top.equalTo(senderNameLabel.snp.bottom).constraint
            messageTopToContainerConstraint =
                $0.top.equalTo(container).offset(Self.paddingY)
                .constraint
            // We'll let timeLabel handle the vertical spacing between the two
        }
        messageTopToContainerConstraint?.deactivate()
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

        setSenderName(nil)
        setBubbleShape(.single, isIncoming: true)
    }

    func setSenderName(_ sender: String?) {
        guard let sender else {
            senderNameLabel.isHidden = true
            messageTopToSenderConstraint?.deactivate()
            messageTopToContainerConstraint?.activate()
            return
        }
        senderNameLabel.text = sender
        senderNameLabel.isHidden = false
        messageTopToContainerConstraint?.deactivate()
        messageTopToSenderConstraint?.activate()
    }

    func setBubbleShape(_ shape: BubbleShape, isIncoming: Bool) {
        switch shape {
        case .single:
            container.layer.cornerRadius = 12
            container.layer.maskedCorners = [
                .layerMinXMinYCorner, .layerMaxXMinYCorner,
                .layerMinXMaxYCorner, .layerMaxXMaxYCorner,
            ]
        case .firstInGroup:
            container.layer.cornerRadius = 12
            container.layer.maskedCorners =
                if isIncoming {
                    [
                        .layerMinXMinYCorner, .layerMaxXMinYCorner,
                        .layerMaxXMaxYCorner,
                    ]
                } else {
                    [
                        .layerMinXMinYCorner, .layerMaxXMinYCorner,
                        .layerMinXMaxYCorner,
                    ]
                }
        case .middleInGroup:
            container.layer.cornerRadius = 12
            container.layer.maskedCorners =
                if isIncoming {
                    [
                        .layerMaxXMinYCorner, .layerMaxXMaxYCorner,
                    ]
                } else {
                    [
                        .layerMinXMinYCorner, .layerMinXMaxYCorner,
                    ]
                }
        }
    }
}
