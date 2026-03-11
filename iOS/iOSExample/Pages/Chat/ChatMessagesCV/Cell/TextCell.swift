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
    let replyPreviewLabel = UILabel()
    let replyImage = UIImageView(image: UIImage(systemName: "arrowshape.turn.up.left.circle.fill"))
    let container = UIView()
    var hasCrossedReplyThreshold = false
    let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    var onReply: (() -> Void)?
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
    private var containerTopToContentConstraint: Constraint?
    private var containerTopToReplyConstraint: Constraint?

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onReply = nil
        hasCrossedReplyThreshold = false
        container.transform = .identity
        replyImage.transform = .identity
        label.text = nil
        timeLabel.text = nil
        setSenderName(nil)
        setReplyPreview(nil)
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

    private static let replyTextAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 12, weight: .medium)
    ]
    private static let replySpacingToMessage: CGFloat = 6

    static let lastWidth: CGFloat = 0
    static var timeRecCached: CGRect = .zero

    private static func textRect(
        _ text: String,
        width: CGFloat,
        attributes: [NSAttributedString.Key: Any]
    ) -> CGRect {
        return text.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: .usesLineFragmentOrigin,
            attributes: attributes,
            context: nil
        )
    }

    static func size(text: String, sender: String?, replyPreview: String? = nil, width: CGFloat)
        -> CGSize
    {
        let availableWidth = width - paddingXCal
        let senderNameR: CGRect = {
            guard let sender else {
                return .zero
            }
            return textRect(
                sender,
                width: availableWidth,
                attributes: Self.senderNameTextAttributes
            )

        }()

        let messageR = textRect(
            text,
            width: availableWidth,
            attributes: Self.msgTextAttributes
        )
        let timeR = {
            if Self.lastWidth != width || Self.timeRecCached == .zero {
                let timeR = textRect(
                    "10:10pm",
                    width: availableWidth,
                    attributes: Self.timeTextAttributes
                )
                Self.timeRecCached = timeR
            }
            return Self.timeRecCached
        }()

        let replyContainerR: CGRect = {
            guard let replyPreview else { return .zero }
            guard !replyPreview.isEmpty else { return .zero }
            let textRect = textRect(
                replyPreview,
                width: availableWidth,
                attributes: Self.replyTextAttributes
            )

            return textRect
        }()

        let calculatedWidth =
            max(
                ceil(messageR.width),
                ceil(timeR.width),
                ceil(senderNameR.width),
                ceil(replyContainerR.width)
            ) + paddingXCal
        let calculatedHeight =
            ceil(messageR.height)
            + ceil(timeR.height)
            + ceil(senderNameR.height)
            + paddingYCal
            + ceil(replyContainerR.height)
            + (replyContainerR == .zero ? 0 : Self.replySpacingToMessage)

        // ceil to provide extra space since it might remove all the decimals which can result in smaller space
        return CGSize(width: calculatedWidth, height: calculatedHeight)
    }
}

extension TextCell {
    func makeUI() {
        contentView.addSubview(replyImage)
        contentView.addSubview(container)
        contentView.addSubview(replyPreviewLabel)
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
            $0.leading.equalTo(contentView)
            $0.trailing.equalTo(contentView)
            $0.bottom.equalTo(contentView)
            containerTopToContentConstraint = $0.top.equalTo(contentView).constraint
            containerTopToReplyConstraint =
                $0.top.equalTo(replyPreviewLabel.snp.bottom).offset(Self.replySpacingToMessage)
                .constraint
        }
        containerTopToReplyConstraint?.deactivate()
        container.backgroundColor = UIColor(Color.messageBubble)
        container.layer.cornerRadius = 12
        container.layer.masksToBounds = true

        senderNameLabel.snp.makeConstraints {
            $0.leading.equalTo(container).offset(Self.paddingX)
            $0.top.equalTo(container).offset(Self.paddingY)
        }
        senderNameLabel.textColor = .label
        senderNameLabel.font = UIFont.systemFont(ofSize: 8)
        senderNameLabel.text = ""

        replyPreviewLabel.snp.makeConstraints {
            $0.leading.equalTo(contentView).offset(Self.paddingX)
            $0.trailing.equalTo(contentView).offset(-Self.paddingX)
            $0.top.equalTo(contentView)
        }
        replyPreviewLabel.textColor = .secondaryLabel
        replyPreviewLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        replyPreviewLabel.numberOfLines = 1
        replyPreviewLabel.lineBreakMode = .byTruncatingTail
        replyPreviewLabel.text = ""
        replyPreviewLabel.isHidden = true

        label.snp.makeConstraints {
            $0.leading.equalTo(container).offset(Self.paddingX)
            $0.trailing.equalTo(container).offset(-Self.paddingX)
            messageTopToSenderConstraint = $0.top.equalTo(senderNameLabel.snp.bottom).constraint
            messageTopToContainerConstraint =
                $0.top.equalTo(container).offset(Self.paddingY)
                .constraint
            // We'll let timeLabel handle the vertical spacing between the two
        }
        messageTopToSenderConstraint?.deactivate()
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
        setReplyPreview(nil)
        setBubbleShape(.single, isIncoming: true)
    }

    func setSenderName(_ sender: String?, colorHex: Int? = nil) {
        guard let sender, !sender.isEmpty else {
            senderNameLabel.text = nil
            senderNameLabel.isHidden = true
            updateConstraint()
            return
        }
        senderNameLabel.text = sender
        if let colorHex {
            senderNameLabel.textColor = UIColor(Color(hexNumber: colorHex))
        }
        senderNameLabel.isHidden = false
        updateConstraint()
    }

    func setReplyPreview(_ replyPreview: String?) {
        guard let replyPreview, !replyPreview.isEmpty else {
            replyPreviewLabel.text = nil
            replyPreviewLabel.isHidden = true
            updateConstraint()
            return
        }

        replyPreviewLabel.text = replyPreview
        replyPreviewLabel.isHidden = false
        updateConstraint()
    }

    private func updateConstraint() {
        messageTopToSenderConstraint?.deactivate()
        messageTopToContainerConstraint?.deactivate()
        containerTopToContentConstraint?.deactivate()
        containerTopToReplyConstraint?.deactivate()

        if !replyPreviewLabel.isHidden {
            containerTopToReplyConstraint?.activate()
        } else {
            containerTopToContentConstraint?.activate()
        }

        if !senderNameLabel.isHidden {
            messageTopToSenderConstraint?.activate()
        } else {
            messageTopToContainerConstraint?.activate()
        }
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
