//
//  TextCell.swift
//  iOSExample
//
//  Created by Om More on 07/03/26.
//

import SnapKit
import SwiftUI
import UIKit

final class TextCell: UICollectionViewCell {
  enum BubbleShape {
    case single
    case firstInGroup
    case middleInGroup
  }

  static let identifier = String(describing: TextCell.self)
  let label = UITextView()
  let timeLabel = UILabel()
  private let senderNameLabel = UILabel()
  private let replyPreviewLabel = UILabel()
  let replyImage = UIImageView(image: UIImage(systemName: "arrowshape.turn.up.left.circle.fill"))
  let container = UIView()
  var hasCrossedReplyThreshold = false
  let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
  var onReply: (() -> Void)?
  var onReplyPreviewClick: (() -> Void)?
  var onLinkTapped: ((URL) -> Void)?
  private static let paddingY: CGFloat = 4
  private static let paddingX: CGFloat = 8
  private static let paddingYCal = paddingY * 2
  private static let paddingXCal = paddingX * 2
  private static let maxMessageWidthRatio: CGFloat = 0.76
  override init(frame: CGRect) {
    super.init(frame: frame)
    makeUI()
    setupGesture()
  }

  lazy var panGesture = UIPanGestureRecognizer(
    target: self, action: #selector(handlePan(_:))
  )

  private var originalCenter: CGPoint = .zero
  private var messageTopToSenderConstraint: Constraint?
  private var messageTopToContainerConstraint: Constraint?
  private var containerTopToContentConstraint: Constraint?
  private var containerTopToReplyConstraint: Constraint?

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    self.onReply = nil
    self.onReplyPreviewClick = nil
    self.onLinkTapped = nil
    self.hasCrossedReplyThreshold = false
    self.container.transform = .identity
    self.replyImage.transform = .identity
    self.label.text = nil
    self.setTime(nil)
    self.container.layer.borderWidth = 0
    self.container.layer.borderColor = nil
    setSenderName(nil)
    setReplyPreview(nil)
  }

  private static let senderNameTextAttributes: [NSAttributedString.Key: Any] = [
    .font: UIFont.systemFont(ofSize: 12),
  ]

  private static let timeTextAttributes: [NSAttributedString.Key: Any] = [
    .font: UIFont.systemFont(ofSize: 8),
  ]
  private static let timeIconName = "clock"
  private static let timeIconSpacing: CGFloat = 2
  private static let timeIconWidth: CGFloat = {
    guard let image = UIImage(systemName: TextCell.timeIconName) else {
      return 0
    }
    let iconHeight = UIFont.systemFont(ofSize: 8).pointSize
    return image.size.width * (iconHeight / max(image.size.height, 1)) + TextCell.timeIconSpacing
  }()

  private static let replyTextAttributes: [NSAttributedString.Key: Any] = [
    .font: UIFont.systemFont(ofSize: 12, weight: .medium),
  ]
  private static let replySpacingToMessage: CGFloat = 6
  private static let replySpacingAboveMessage: CGFloat = 10

  private static let lastWidth: CGFloat = 0
  private static var timeRecCached: CGRect = .zero

  private static func textRect(
    _ text: NSAttributedString,
    width: CGFloat
  ) -> CGRect {
    return text.boundingRect(
      with: CGSize(width: width, height: .greatestFiniteMagnitude),
      options: [.usesLineFragmentOrigin, .usesFontLeading],
      context: nil
    )
  }

  static func formattedSenderName(sender: String?, nickname: String?) -> String? {
    guard let sender, !sender.isEmpty else { return nil }
    let trimmedNickname = nickname?.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let trimmedNickname, !trimmedNickname.isEmpty else {
      return sender
    }
    return "\(sender) aka \(trimmedNickname)"
  }

  static func size(
    text: NSAttributedString, sender: String?, senderNickname: String? = nil,
    replyPreview: String? = nil, width: CGFloat,
    showsClockIcon: Bool = false
  )
    -> CGSize {
    let maxBubbleWidth = width * Self.maxMessageWidthRatio
    let availableWidth = max(maxBubbleWidth - self.paddingXCal, 0)
    let senderNameR: CGRect = {
      guard let senderName = self.formattedSenderName(sender: sender, nickname: senderNickname)
      else {
        return .zero
      }
      return self.textRect(
        NSAttributedString(string: senderName, attributes: Self.senderNameTextAttributes),
        width: availableWidth
      )

    }()

    let messageR = self.textRect(
      text,
      width: availableWidth
    )
    let timeR = {
      if Self.lastWidth != width || Self.timeRecCached == .zero {
        let timeR = self.textRect(
          NSAttributedString(string: "10:10pm", attributes: Self.timeTextAttributes),
          width: availableWidth
        )
        Self.timeRecCached = timeR
      }
      var timeR = Self.timeRecCached
      if showsClockIcon {
        timeR.size.width += Self.timeIconWidth
      }
      return timeR
    }()

    let replyContainerR: CGRect = {
      guard let replyPreview else { return .zero }
      guard !replyPreview.isEmpty else { return .zero }
      return self.textRect(
        NSAttributedString(string: replyPreview, attributes: Self.replyTextAttributes),
        width: availableWidth
      )
    }()

    let calculatedWidth =
      max(
        ceil(messageR.width),
        ceil(timeR.width),
        ceil(senderNameR.width),
        ceil(replyContainerR.width)
      ) + self.paddingXCal
    let calculatedHeight =
      ceil(messageR.height)
        + ceil(timeR.height)
        + ceil(senderNameR.height)
        + self.paddingYCal
        + ceil(replyContainerR.height)
        + (replyContainerR == .zero
          ? 0 : Self.replySpacingToMessage + Self.replySpacingAboveMessage)

    // ceil to provide extra space since it might remove all the decimals which can result in smaller space
    return CGSize(width: min(calculatedWidth, maxBubbleWidth), height: calculatedHeight)
  }
}

extension TextCell {
  private func makeUI() {
    contentView.addSubview(self.replyImage)
    contentView.addSubview(self.container)
    contentView.addSubview(self.replyPreviewLabel)
    self.container.addSubview(self.label)
    self.container.addSubview(self.timeLabel)
    self.container.addSubview(self.senderNameLabel)

    self.replyImage.snp.makeConstraints {
      $0.leading.equalTo(self.container).offset(Self.paddingX)
      $0.centerY.equalTo(self.container)
      $0.size.equalTo(20) // Combines width and height
    }
    self.replyImage.tintColor = .systemOrange

    self.container.snp.makeConstraints {
      $0.leading.equalTo(contentView)
      $0.trailing.equalTo(contentView)
      $0.bottom.equalTo(contentView)
      self.containerTopToContentConstraint = $0.top.equalTo(contentView).constraint
      self.containerTopToReplyConstraint =
        $0.top.equalTo(self.replyPreviewLabel.snp.bottom).offset(Self.replySpacingToMessage)
          .constraint
    }
    self.containerTopToReplyConstraint?.deactivate()
    self.container.backgroundColor = UIColor(Color.messageBubble)
    self.container.layer.cornerRadius = 12
    self.container.layer.masksToBounds = true

    self.senderNameLabel.snp.makeConstraints {
      $0.leading.equalTo(self.container).offset(Self.paddingX)
      $0.top.equalTo(self.container).offset(Self.paddingY)
    }
    self.senderNameLabel.textColor = .label
    self.senderNameLabel.font = UIFont.systemFont(ofSize: 12)
    self.senderNameLabel.text = ""

    self.replyPreviewLabel.snp.makeConstraints {
      $0.leading.equalTo(contentView).offset(Self.paddingX)
      $0.trailing.equalTo(contentView).offset(-Self.paddingX)
      $0.top.equalTo(contentView).offset(Self.replySpacingAboveMessage)
    }
    self.replyPreviewLabel.textColor = .secondaryLabel
    self.replyPreviewLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
    self.replyPreviewLabel.numberOfLines = 1
    self.replyPreviewLabel.lineBreakMode = .byTruncatingTail
    self.replyPreviewLabel.text = ""
    self.replyPreviewLabel.isHidden = true
    self.replyPreviewLabel.isUserInteractionEnabled = true
    self.replyPreviewLabel.addGestureRecognizer(
      UITapGestureRecognizer(target: self, action: #selector(self.handleReplyPreviewTap))
    )

    self.label.snp.makeConstraints {
      $0.leading.equalTo(self.container).offset(Self.paddingX)
      $0.trailing.equalTo(self.container).offset(-Self.paddingX)
      self.messageTopToSenderConstraint = $0.top.equalTo(self.senderNameLabel.snp.bottom).constraint
      self.messageTopToContainerConstraint =
        $0.top.equalTo(self.container).offset(Self.paddingY)
          .constraint
      // We'll let timeLabel handle the vertical spacing between the two
    }
    self.messageTopToSenderConstraint?.deactivate()
    self.messageTopToContainerConstraint?.deactivate()
    self.label.attributedText = nil
    self.label.isEditable = false
    self.label.isScrollEnabled = false
    self.label.backgroundColor = .clear
    self.label.textContainerInset = .zero
    self.label.textContainer.lineFragmentPadding = 0
    self.label.textColor = .label
    self.label.delegate = self
    self.label.linkTextAttributes = [
      .foregroundColor: UIColor.systemOrange,
      .underlineStyle: NSUnderlineStyle.single.rawValue,
      .underlineColor: UIColor.systemOrange,
      .backgroundColor: UIColor.systemOrange.withAlphaComponent(0.15),
    ]

    self.timeLabel.snp.makeConstraints {
      $0.trailing.equalTo(self.container).offset(-Self.paddingX)
      $0.top.equalTo(self.label.snp.bottom).offset(Self.paddingY) // Defines the vertical stack
      $0.bottom.equalTo(self.container).offset(-Self.paddingY)
    }
    self.timeLabel.textColor = .gray
    self.timeLabel.font = UIFont.systemFont(ofSize: 8)
    self.setTime(nil)

    self.setSenderName(nil)
    self.setReplyPreview(nil)
    self.setBubbleShape(.single, isIncoming: true)
  }

  @objc private func handleReplyPreviewTap() {
    self.onReplyPreviewClick?()
  }

  func setSenderName(_ sender: String?, nickname: String? = nil, colorHex: Int? = nil) {
    guard let senderName = Self.formattedSenderName(sender: sender, nickname: nickname)
    else {
      self.senderNameLabel.text = nil
      self.senderNameLabel.isHidden = true
      self.updateConstraint()
      return
    }
    self.senderNameLabel.text = senderName
    if let colorHex {
      self.senderNameLabel.textColor = UIColor { traitCollection in
        let colorScheme: ColorScheme =
          traitCollection.userInterfaceStyle == .dark ? .dark : .light
        return UIColor(Color(hexNumber: colorHex).adaptive(for: colorScheme))
      }
    }
    self.senderNameLabel.isHidden = false
    self.updateConstraint()
  }

  func setReplyPreview(_ replyPreview: String?) {
    guard let replyPreview, !replyPreview.isEmpty
    else {
      self.replyPreviewLabel.text = nil
      self.replyPreviewLabel.isHidden = true
      self.updateConstraint()
      return
    }

    self.replyPreviewLabel.text = replyPreview
    self.replyPreviewLabel.isHidden = false
    self.updateConstraint()
  }

  private func updateConstraint() {
    self.messageTopToSenderConstraint?.deactivate()
    self.messageTopToContainerConstraint?.deactivate()
    self.containerTopToContentConstraint?.deactivate()
    self.containerTopToReplyConstraint?.deactivate()

    if !self.replyPreviewLabel.isHidden {
      self.containerTopToReplyConstraint?.activate()
    } else {
      self.containerTopToContentConstraint?.activate()
    }

    if !self.senderNameLabel.isHidden {
      self.messageTopToSenderConstraint?.activate()
    } else {
      self.messageTopToContainerConstraint?.activate()
    }
  }

  func setTime(_ text: String?, showsClockIcon: Bool = false) {
    guard let text, !text.isEmpty
    else {
      self.timeLabel.attributedText = nil
      return
    }
    self.timeLabel.attributedText = self.makeAttributedTimeText(text, showsClockIcon: showsClockIcon)
  }

  private func makeAttributedTimeText(_ text: String, showsClockIcon: Bool) -> NSAttributedString {
    let font = self.timeLabel.font ?? UIFont.systemFont(ofSize: 8)
    let color = self.timeLabel.textColor ?? .gray
    let attributes: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: color,
    ]
    let attributedText = NSMutableAttributedString(string: text, attributes: attributes)

    guard showsClockIcon else {
      return attributedText
    }
    attributedText.append(NSAttributedString(string: " ", attributes: attributes))

    guard let iconImage = UIImage(systemName: Self.timeIconName)?
      .withTintColor(color, renderingMode: .alwaysOriginal)
    else {
      return attributedText
    }

    let attachment = NSTextAttachment()
    attachment.image = iconImage
    // Scale icon to match text size.
    let iconHeight = font.pointSize
    // Keep original symbol aspect ratio after scaling.
    let iconWidth = iconImage.size.width * (iconHeight / iconImage.size.height)
    attachment.bounds = CGRect(
      x: 0,
      // Shift icon to vertically align with the text's cap-height.
      y: (font.capHeight - iconHeight) / 2,
      width: iconWidth,
      height: iconHeight
    )
    attributedText.append(NSAttributedString(attachment: attachment))
    return attributedText
  }

  func setBubbleShape(_ shape: BubbleShape, isIncoming: Bool) {
    switch shape {
    case .single:
      self.container.layer.cornerRadius = 12
      self.container.layer.maskedCorners = [
        .layerMinXMinYCorner, .layerMaxXMinYCorner,
        .layerMinXMaxYCorner, .layerMaxXMaxYCorner,
      ]
    case .firstInGroup:
      self.container.layer.cornerRadius = 12
      self.container.layer.maskedCorners =
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
      self.container.layer.cornerRadius = 12
      self.container.layer.maskedCorners =
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

  func highlight() {
    self.container.layer.borderColor = UIColor.systemOrange.cgColor
    self.container.layer.borderWidth = 1.5

    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
      guard let self else { return }
      UIView.animate(withDuration: 0.5) {
        self.container.layer.borderWidth = 0
      }
    }
  }
}

extension TextCell: UITextViewDelegate {
  func textView(_: UITextView, shouldInteractWith URL: URL, in _: NSRange)
    -> Bool {
    self.onLinkTapped?(URL)
    return false
  }
}
