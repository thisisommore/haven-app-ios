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
  private let timeLabel = UILabel()
  private let senderNameLabel = UILabel()
  private let replyPreviewLabel = UILabel()
  private let reactionsContainer = UIStackView()
  let replyImage = UIImageView(image: UIImage(systemName: "arrowshape.turn.up.left.circle.fill"))
  let container = UIView()
  var hasCrossedReplyThreshold = false
  let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
  var onReply: (() -> Void)?
  var onReact: (() -> Void)?
  var onReactionPreviewTap: (() -> Void)?
  var onReplyPreviewClick: (() -> Void)?
  var onLinkTapped: ((URL) -> Void)?

  private static let paddingY: CGFloat = 4
  private static let paddingX: CGFloat = 8
  private static let paddingYCal = paddingY * 2
  private static let paddingXCal = paddingX * 2
  private static let maxMessageWidthRatio: CGFloat = 0.76

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
  private static let reactionPlusToken = "+"
  private static let reactionPlusIconName = "plus"
  private static let reactionChipSize: CGFloat = 20
  private static let reactionChipSpacing: CGFloat = 4
  private static let reactionPlusIconSize: CGFloat = 10

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
  private var containerBottomConstraint: Constraint?

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    self.onReply = nil
    self.onReact = nil
    self.onReactionPreviewTap = nil
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
    setReactions([])
  }
}

extension TextCell: UITextViewDelegate {
  func textView(_: UITextView, shouldInteractWith URL: URL, in _: NSRange)
    -> Bool {
    self.onLinkTapped?(URL)
    return false
  }
}

extension TextCell {
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

  private static func reactionRowSize(for emojis: [String]) -> CGSize {
    guard !emojis.isEmpty else { return .zero }
    let count = CGFloat(emojis.count)
    let width = (count * Self.reactionChipSize) + ((count - 1) * Self.reactionChipSpacing)
    return CGSize(width: width, height: Self.reactionChipSize)
  }

  private static func formattedSenderName(sender: String?, nickname: String?) -> String? {
    guard let sender, !sender.isEmpty else { return nil }
    let trimmedNickname = nickname?.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let trimmedNickname, !trimmedNickname.isEmpty else {
      return sender
    }
    return "\(sender) aka \(trimmedNickname)"
  }

  static func size(
    text: NSAttributedString, sender: String?, senderNickname: String? = nil,
    replyPreview: String? = nil, reactionEmojis: [String] = [], width: CGFloat,
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
    let reactionsR: CGRect = {
      guard !reactionEmojis.isEmpty else { return .zero }
      return CGRect(origin: .zero, size: self.reactionRowSize(for: reactionEmojis))
    }()
    let reactionBottomInset = reactionsR == .zero ? 0 : ceil(reactionsR.height / 2)

    let calculatedWidth =
      max(
        ceil(messageR.width),
        ceil(timeR.width),
        ceil(senderNameR.width),
        ceil(replyContainerR.width),
        ceil(reactionsR.width)
      ) + self.paddingXCal
    let calculatedHeight =
      ceil(messageR.height)
        + ceil(timeR.height)
        + ceil(senderNameR.height)
        + self.paddingYCal
        + ceil(replyContainerR.height)
        + (replyContainerR == .zero
          ? 0 : Self.replySpacingToMessage + Self.replySpacingAboveMessage)
        + reactionBottomInset

    // ceil to provide extra space since it might remove all the decimals which can result in smaller space
    return CGSize(width: min(calculatedWidth, maxBubbleWidth), height: calculatedHeight)
  }
}

// MARK: - TextCell UI

extension TextCell {
  // MARK: - Setup

  /// Builds the view hierarchy and constraints. Vertical order: reply preview row → bubble (sender, body, time) → reactions overlapping the bubble bottom.
  private func makeUI() {
    self.installSubviews()

    self.configureReplyPreviewRow()
    self.configureBubbleContainer()
    self.configureReplySwipeIcon()
    self.configureSenderRow()
    self.configureMessageBody()
    self.configureTimeRow()
    self.configureReactionsRow()

    self.applyInitialEmptyState()
  }

  private func installSubviews() {
    // replyImage first so it draws beneath the bubble (later siblings are on top).
    contentView.addSubview(self.replyImage)
    contentView.addSubview(self.container)
    contentView.addSubview(self.replyPreviewLabel)
    contentView.addSubview(self.reactionsContainer)

    self.container.addSubview(self.senderNameLabel)
    self.container.addSubview(self.label)
    self.container.addSubview(self.timeLabel)
  }

  /// One-line preview of the message being replied to; sits above the bubble when visible.
  private func configureReplyPreviewRow() {
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
  }

  /// Main message bubble; top is pinned either to the reply preview or to the cell top.
  private func configureBubbleContainer() {
    self.container.snp.makeConstraints {
      $0.leading.equalTo(contentView)
      $0.trailing.equalTo(contentView)
      self.containerBottomConstraint = $0.bottom.equalTo(contentView).constraint
      self.containerTopToContentConstraint = $0.top.equalTo(contentView).constraint
      self.containerTopToReplyConstraint =
        $0.top.equalTo(self.replyPreviewLabel.snp.bottom).offset(Self.replySpacingToMessage)
          .constraint
    }
    self.containerTopToReplyConstraint?.deactivate()

    self.container.backgroundColor = UIColor(Color.messageBubble)
    self.container.layer.cornerRadius = 12
    self.container.layer.masksToBounds = true
  }

  /// Icon revealed when swiping right to reply; aligned with the bubble, not the preview row.
  private func configureReplySwipeIcon() {
    self.replyImage.snp.makeConstraints {
      $0.leading.equalTo(self.container).offset(Self.paddingX)
      $0.centerY.equalTo(self.container)
      $0.size.equalTo(20)
    }
    self.replyImage.tintColor = .systemOrange
  }

  /// Optional sender line at the top inside the bubble.
  private func configureSenderRow() {
    self.senderNameLabel.snp.makeConstraints {
      $0.leading.equalTo(self.container).offset(Self.paddingX)
      $0.top.equalTo(self.container).offset(Self.paddingY)
    }
    self.senderNameLabel.textColor = .label
    self.senderNameLabel.font = UIFont.systemFont(ofSize: 12)
    self.senderNameLabel.text = ""
  }

  /// Non-editable text with link styling; top switches between “under sender” and “top of bubble”.
  private func configureMessageBody() {
    self.label.snp.makeConstraints {
      $0.leading.equalTo(self.container).offset(Self.paddingX)
      $0.trailing.equalTo(self.container).offset(-Self.paddingX)
      self.messageTopToSenderConstraint = $0.top.equalTo(self.senderNameLabel.snp.bottom).constraint
      self.messageTopToContainerConstraint =
        $0.top.equalTo(self.container).offset(Self.paddingY).constraint
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
  }

  /// Trailing timestamp; bottom pins the bubble height together with the message.
  private func configureTimeRow() {
    self.timeLabel.snp.makeConstraints {
      $0.trailing.equalTo(self.container).offset(-Self.paddingX)
      $0.top.equalTo(self.label.snp.bottom).offset(Self.paddingY)
      $0.bottom.equalTo(self.container).offset(-Self.paddingY)
    }
    self.timeLabel.textColor = .gray
    self.timeLabel.font = UIFont.systemFont(ofSize: 8)
    self.setTime(nil)
  }

  /// Emoji chips centered on the bottom edge of the bubble.
  private func configureReactionsRow() {
    self.reactionsContainer.snp.makeConstraints {
      $0.leading.equalTo(self.container).offset(Self.paddingX)
      $0.centerY.equalTo(self.container.snp.bottom)
      $0.trailing.lessThanOrEqualTo(contentView).offset(-Self.paddingX)
      $0.height.equalTo(Self.reactionChipSize)
    }
    self.reactionsContainer.axis = .horizontal
    self.reactionsContainer.spacing = Self.reactionChipSpacing
    self.reactionsContainer.alignment = .center
    self.reactionsContainer.distribution = .fill
    self.reactionsContainer.isHidden = true
    self.reactionsContainer.isUserInteractionEnabled = true
    self.reactionsContainer.addGestureRecognizer(
      UITapGestureRecognizer(target: self, action: #selector(self.handleReactionTap))
    )
  }

  private func applyInitialEmptyState() {
    self.setSenderName(nil)
    self.setReplyPreview(nil)
    self.setReactions([])
    self.setBubbleShape(.single, isIncoming: true)
  }

  // MARK: - Configuration (callers / reuse)

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

  func setReactions(_ reactionEmojis: [String]) {
    for subview in self.reactionsContainer.arrangedSubviews {
      self.reactionsContainer.removeArrangedSubview(subview)
      subview.removeFromSuperview()
    }

    guard !reactionEmojis.isEmpty else {
      self.reactionsContainer.isHidden = true
      self.updateReactionBottomInset()
      return
    }

    for token in reactionEmojis {
      self.reactionsContainer.addArrangedSubview(Self.makeReactionChip(token))
    }
    self.reactionsContainer.isHidden = false
    self.updateReactionBottomInset()
  }

  func setTime(_ text: String?, showsClockIcon: Bool = false) {
    guard let text, !text.isEmpty
    else {
      self.timeLabel.attributedText = nil
      return
    }
    self.timeLabel.attributedText = self.makeAttributedTimeText(text, showsClockIcon: showsClockIcon)
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

  /// Brief orange border, then fades out (e.g. scroll-to-message highlight).
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

  // MARK: - Gesture actions

  @objc private func handleReplyPreviewTap() {
    self.onReplyPreviewClick?()
  }

  @objc private func handleReactionTap() {
    self.onReactionPreviewTap?()
  }

  // MARK: - Layout

  /// Activates the correct vertical constraints for reply preview, sender row, and reaction inset.
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
    self.updateReactionBottomInset()
  }

  private func updateReactionBottomInset() {
    self.containerBottomConstraint?.update(offset: -self.currentReactionBottomInset())
  }

  /// Half a chip height so the overlapping reactions row does not clip.
  private func currentReactionBottomInset() -> CGFloat {
    guard !self.reactionsContainer.isHidden else { return 0 }
    return ceil(Self.reactionChipSize / 2)
  }

  // MARK: - Time

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
    let iconHeight = font.pointSize
    let iconWidth = iconImage.size.width * (iconHeight / iconImage.size.height)
    attachment.bounds = CGRect(
      x: 0,
      y: (font.capHeight - iconHeight) / 2,
      width: iconWidth,
      height: iconHeight
    )
    attributedText.append(NSAttributedString(attachment: attachment))
    return attributedText
  }

  // MARK: - Reaction chips

  private static func makeReactionChip(_ token: String) -> UIView {
    let chip = UIView()
    chip.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.9)
    chip.layer.cornerRadius = Self.reactionChipSize / 2
    chip.layer.masksToBounds = true
    chip.snp.makeConstraints { $0.size.equalTo(Self.reactionChipSize) }

    if token == Self.reactionPlusToken {
      let icon = UIImageView(image: UIImage(systemName: Self.reactionPlusIconName))
      icon.tintColor = .secondaryLabel
      icon.contentMode = .scaleAspectFit
      chip.addSubview(icon)
      icon.snp.makeConstraints {
        $0.center.equalToSuperview()
        $0.size.equalTo(Self.reactionPlusIconSize)
      }
      return chip
    }

    let label = UILabel()
    label.text = token
    label.textAlignment = .center
    label.font = UIFont.systemFont(ofSize: 13)
    chip.addSubview(label)
    label.snp.makeConstraints { $0.center.equalToSuperview() }
    return chip
  }
}
