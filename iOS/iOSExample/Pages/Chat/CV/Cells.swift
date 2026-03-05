//
//  Cells.swift
//  iOSExample
//
//  Created by Om More on 04/03/26.
//
import SwiftUI
import UIKit

protocol CVCell: UICollectionViewCell {
  func render(message: ChatMessageModel)
  static func size(width: CGFloat, message: ChatMessageModel) -> CGRect
}

class TextCell: UICollectionViewCell, CVCell {
  static let identifier = String(describing: TextCell.self)
  private static let verticalPadding: CGFloat = 6
  private static let horizontalPadding: CGFloat = 8
  private static let baseFont = UIFont.systemFont(ofSize: 17)
  private static let senderFont = UIFont.systemFont(ofSize: 12, weight: .bold)
  private static let senderBottomSpacing: CGFloat = 2
  private static let timeFont = UIFont.systemFont(ofSize: 10)
  private static let timePlaceholderSpacing = "    "
  private static let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter
  }()
  private struct CachedRenderedContent {
    let sourceHash: Int
    let content: RenderedContent
  }
  private enum RenderedContent {
    case plain(String)
    case rich(NSAttributedString)
  }
  private static var renderedContentCache: [String: CachedRenderedContent] = [:]
  private static let renderedContentCacheQueue = DispatchQueue(
    label: "cv.textcell.renderCache", attributes: .concurrent)
  private static let payloadDecoder = JSONDecoder()
  private let senderLabel: UILabel = UILabel()
  private let timeLabel: UILabel = UILabel()
  let label: UILabel = UILabel()
  private var labelTopToContentConstraint: NSLayoutConstraint?
  private var labelTopToSenderConstraint: NSLayoutConstraint?

  func render(message: ChatMessageModel) {
    render(message: message, senderDisplayName: nil)
  }

  func render(message: ChatMessageModel, sender: MessageSenderModel?) {
    render(
      message: message, senderDisplayName: Self.senderDisplayName(from: sender),
      senderColor: sender?.color)
  }

  func render(message: ChatMessageModel, senderDisplayName: String?, senderColor: Int? = nil) {
    let shouldShowSender = message.isIncoming && senderDisplayName != nil
    currentSenderColorHex = shouldShowSender ? senderColor : nil

    if shouldShowSender {
      senderLabel.isHidden = false
      senderLabel.text = senderDisplayName
      if let hex = senderColor {
        let isDark = traitCollection.userInterfaceStyle == .dark
        let color = Color(hexNumber: hex).adaptive(for: isDark ? .dark : .light)
        senderLabel.textColor = UIColor(color)
      } else {
        senderLabel.textColor = UIColor.secondaryLabel
      }
      labelTopToContentConstraint?.isActive = false
      labelTopToSenderConstraint?.isActive = true
    } else {
      senderLabel.isHidden = true
      senderLabel.text = nil
      senderLabel.textColor = UIColor.secondaryLabel
      labelTopToSenderConstraint?.isActive = false
      labelTopToContentConstraint?.isActive = true
    }

    let timeText = Self.timeText(from: message.timestamp)
    timeLabel.text = timeText
    label.text = nil
    label.attributedText = Self.contentWithTimePlaceholder(
      Self.renderedContent(for: message),
      timeText: timeText
    )
  }

  private var currentSenderColorHex: Int?

  override required init(frame: CGRect) {
    super.init(frame: frame)

    if #available(iOS 17.0, *) {
      registerForTraitChanges([UITraitUserInterfaceStyle.self]) {
        (self: TextCell, previousTraitCollection: UITraitCollection) in
        self.updateSenderColor()
      }
    }

    // Bubble styling must be on contentView so swipe offset moves full bubble (bg + text)
    backgroundColor = .clear
    contentView.backgroundColor = UIColor(named: "MessageBubble")
    contentView.layer.cornerRadius = 16
    contentView.layer.masksToBounds = true
    senderLabel.numberOfLines = 1
    senderLabel.font = Self.senderFont
    senderLabel.textColor = UIColor.secondaryLabel
    senderLabel.lineBreakMode = .byTruncatingTail
    senderLabel.isHidden = true
    senderLabel.translatesAutoresizingMaskIntoConstraints = false
    timeLabel.numberOfLines = 1
    timeLabel.font = Self.timeFont
    timeLabel.textColor = UIColor.secondaryLabel
    timeLabel.translatesAutoresizingMaskIntoConstraints = false
    label.numberOfLines = 0
    label.font = Self.baseFont
    label.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(senderLabel)
    contentView.addSubview(timeLabel)
    contentView.addSubview(label)
    labelTopToContentConstraint = label.topAnchor.constraint(
      equalTo: contentView.topAnchor, constant: Self.verticalPadding)
    labelTopToSenderConstraint = label.topAnchor.constraint(
      equalTo: senderLabel.bottomAnchor, constant: Self.senderBottomSpacing)
    labelTopToContentConstraint?.isActive = true

    NSLayoutConstraint.activate([
      senderLabel.topAnchor.constraint(
        equalTo: contentView.topAnchor, constant: Self.verticalPadding),
      senderLabel.leadingAnchor.constraint(
        equalTo: contentView.leadingAnchor, constant: Self.horizontalPadding),
      senderLabel.trailingAnchor.constraint(
        equalTo: contentView.trailingAnchor, constant: -Self.horizontalPadding),

      timeLabel.trailingAnchor.constraint(
        equalTo: contentView.trailingAnchor, constant: -Self.horizontalPadding),
      timeLabel.bottomAnchor.constraint(
        equalTo: contentView.bottomAnchor, constant: -Self.verticalPadding),

      label.bottomAnchor.constraint(
        equalTo: contentView.bottomAnchor, constant: -Self.verticalPadding),
      label.leadingAnchor.constraint(
        equalTo: contentView.leadingAnchor, constant: Self.horizontalPadding),
      label.trailingAnchor.constraint(
        equalTo: contentView.trailingAnchor, constant: -Self.horizontalPadding),
    ])
  }

  private func updateSenderColor() {
    if let hex = currentSenderColorHex {
      let isDark = traitCollection.userInterfaceStyle == .dark
      let color = Color(hexNumber: hex).adaptive(for: isDark ? .dark : .light)
      senderLabel.textColor = UIColor(color)
    } else {
      senderLabel.textColor = UIColor.secondaryLabel
    }
  }

  @available(iOS, deprecated: 17.0)
  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
      updateSenderColor()
    }
  }

  private static var sizeCache: [String: CGRect] = [:]
  private static let cacheQueue = DispatchQueue(
    label: "cv.textcell.sizeCache", attributes: .concurrent)

  static func size(width: CGFloat, message: ChatMessageModel) -> CGRect {
    size(width: width, message: message, senderDisplayName: nil)
  }

  static func size(width: CGFloat, message: ChatMessageModel, senderDisplayName: String?)
    -> CGRect
  {
    let senderHashPart = senderDisplayName?.hashValue ?? 0
    let key = "\(message.id)_\(width)_\(senderHashPart)"

    var cachedSize: CGRect?
    cacheQueue.sync {
      cachedSize = sizeCache[key]
    }
    if let cached = cachedSize {
      return cached
    }

    let renderedContent = renderedContent(for: message)
    let timeText = timeText(from: message.timestamp)
    let horizontalPadding = Self.horizontalPadding * 2
    let verticalPadding = Self.verticalPadding * 2
    let maxContentWidth = max(0, width - horizontalPadding)
    let constraintRect = CGSize(
      width: maxContentWidth, height: .greatestFiniteMagnitude)
    let baseBoundingBox: CGRect
    switch renderedContent {
    case .plain(let text):
      baseBoundingBox = text.boundingRect(
        with: constraintRect,
        options: .usesLineFragmentOrigin,
        attributes: [.font: Self.baseFont],
        context: nil
      )
    case .rich(let attributed):
      baseBoundingBox = attributed.boundingRect(
        with: constraintRect,
        options: [.usesLineFragmentOrigin, .usesFontLeading],
        context: nil
      )
    }

    let senderTextWidth: CGFloat
    if let senderText = senderDisplayName {
      let senderBoundingBox = senderText.boundingRect(
        with: constraintRect,
        options: .usesLineFragmentOrigin,
        attributes: [.font: Self.senderFont],
        context: nil
      )
      senderTextWidth = ceil(senderBoundingBox.width)
    } else {
      senderTextWidth = 0
    }

    let renderedWithTime = contentWithTimePlaceholder(renderedContent, timeText: timeText)
    let timedConstraintRect = CGSize(
      width: maxContentWidth, height: .greatestFiniteMagnitude)
    let timedBoundingBox = renderedWithTime.boundingRect(
      with: timedConstraintRect,
      options: [.usesLineFragmentOrigin, .usesFontLeading],
      context: nil
    )

    let timedTextWidth = ceil(timedBoundingBox.width)
    let contentWidth = min(max(timedTextWidth, senderTextWidth), maxContentWidth)

    let result = CGRect(
      x: baseBoundingBox.origin.x,
      y: baseBoundingBox.origin.y,
      width: contentWidth + horizontalPadding,
      height: ceil(timedBoundingBox.height) + verticalPadding
    )
    let incomingSenderHeight =
      senderDisplayName != nil ? ceil(Self.senderFont.lineHeight) + Self.senderBottomSpacing : 0
    let adjustedResult = CGRect(
      x: result.origin.x,
      y: result.origin.y,
      width: result.width,
      height: result.height + incomingSenderHeight
    )

    cacheQueue.async(flags: .barrier) {
      sizeCache[key] = adjustedResult
    }

    return adjustedResult
  }

  private static func renderedContent(for message: ChatMessageModel) -> RenderedContent {
    let key = message.id
    let sourceHash = message.message.hashValue

    var cached: CachedRenderedContent?
    renderedContentCacheQueue.sync {
      cached = renderedContentCache[key]
    }
    if let cached, cached.sourceHash == sourceHash {
      return cached.content
    }

    let computed = buildRenderedContent(rawHTML: message.message)
    renderedContentCacheQueue.async(flags: .barrier) {
      renderedContentCache[key] = CachedRenderedContent(sourceHash: sourceHash, content: computed)
    }
    return computed
  }

  private static func buildRenderedContent(rawHTML: String) -> RenderedContent {
    let precomputed = NewMessageHTMLPrecomputer.precompute(rawHTML: rawHTML)

    guard precomputed.kind == .rich,
      let payloadData = precomputed.payloadData,
      let payload = try? payloadDecoder.decode(NewMessageParsedPayload.self, from: payloadData)
    else {
      return .plain(precomputed.plainText)
    }

    return .rich(attributedString(from: payload))
  }

  private static func attributedString(from payload: NewMessageParsedPayload) -> NSAttributedString
  {
    let mutable = NSMutableAttributedString(
      string: payload.text,
      attributes: [.font: baseFont]
    )
    let fullLength = (payload.text as NSString).length

    for span in payload.spans {
      guard span.startUTF16 >= 0,
        span.endUTF16 <= fullLength,
        span.endUTF16 > span.startUTF16
      else {
        continue
      }

      let range = NSRange(location: span.startUTF16, length: span.endUTF16 - span.startUTF16)
      let bits = NewMessageStyleBits(rawValue: span.styleBits)
      var attributes: [NSAttributedString.Key: Any] = [:]

      if bits.contains(.code) || bits.contains(.pre) {
        attributes[.font] = UIFont.monospacedSystemFont(
          ofSize: baseFont.pointSize, weight: .regular)
      } else {
        var symbolicTraits = UIFontDescriptor.SymbolicTraits()
        if bits.contains(.bold) {
          symbolicTraits.insert(.traitBold)
        }
        if bits.contains(.italic) {
          symbolicTraits.insert(.traitItalic)
        }
        if !symbolicTraits.isEmpty,
          let descriptor = baseFont.fontDescriptor.withSymbolicTraits(symbolicTraits)
        {
          attributes[.font] = UIFont(descriptor: descriptor, size: baseFont.pointSize)
        }
      }

      if bits.contains(.strike) {
        attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
      }

      if bits.contains(.link) {
        attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
      }

      if !attributes.isEmpty {
        mutable.addAttributes(attributes, range: range)
      }
    }

    return mutable
  }

  private static func senderDisplayName(from sender: MessageSenderModel?) -> String {
    guard let sender else { return "Unknown" }
    guard let nickname = sender.nickname, !nickname.isEmpty else {
      return sender.codename
    }
    let truncatedNickname = nickname.count > 10 ? String(nickname.prefix(10)) + "…" : nickname
    return "\(truncatedNickname) aka \(sender.codename)"
  }

  private static func contentWithTimePlaceholder(
    _ content: RenderedContent,
    timeText: String
  ) -> NSAttributedString {
    let mutable: NSMutableAttributedString
    switch content {
    case .plain(let text):
      mutable = NSMutableAttributedString(
        string: text,
        attributes: [.font: Self.baseFont]
      )
    case .rich(let attributed):
      mutable = NSMutableAttributedString(attributedString: attributed)
    }

    let placeholder = NSAttributedString(
      string: "\(Self.timePlaceholderSpacing)\(timeText)",
      attributes: [
        .font: Self.timeFont,
        .foregroundColor: UIColor.clear,
      ]
    )
    mutable.append(placeholder)
    return mutable
  }

  private static func timeText(from date: Date) -> String {
    timeFormatter.string(from: date)
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

class ChannelLinkCell: UICollectionViewCell, CVCell {
  static let identifier = String(describing: ChannelLinkCell.self)
  private static let senderFont = UIFont.systemFont(ofSize: 12, weight: .bold)
  private static let messageFont = UIFont.systemFont(ofSize: 16)
  private static let titleFont = UIFont.preferredFont(forTextStyle: .headline)
  private static let subtitleFont = UIFont.preferredFont(forTextStyle: .subheadline)
  private static let buttonFont = UIFont.systemFont(ofSize: 15, weight: .semibold)
  private static let timestampFont = UIFont.systemFont(ofSize: 10)
  private static let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter
  }()
  private static let senderBottomSpacing: CGFloat = 2
  private static let messageHorizontalPadding: CGFloat = 10
  private static let messageVerticalPadding: CGFloat = 8
  private static let previewPadding: CGFloat = 10
  private static let sectionSpacing: CGFloat = 10
  private static let bubbleCornerRadius: CGFloat = 26
  private static let buttonCornerRadius: CGFloat = 8
  private static let iconSize: CGFloat = 28
  private static let bubbleWidthInset: CGFloat = 44

  private let bubbleView = UIView()
  private let topMessageView = UIView()
  private let senderLabel = UILabel()
  private let messageLabel = UILabel()
  private let previewView = UIView()
  private let iconView = UIImageView()
  private let titleLabel = UILabel()
  private let subtitleLabel = UILabel()
  private let buttonContainer = UIView()
  private let buttonLabel = UILabel()
  private let timestampLabel = UILabel()
  private var messageTopToTopConstraint: NSLayoutConstraint?
  private var messageTopToSenderConstraint: NSLayoutConstraint?
  private var currentSenderColorHex: Int?
  private var currentIsIncoming = true

  private static var sizeCache: [String: CGRect] = [:]
  private static let cacheQueue = DispatchQueue(
    label: "cv.channelLink.sizeCache", attributes: .concurrent)
  private static let sizingCell = ChannelLinkCell(frame: .zero)

  func render(message: ChatMessageModel) {
    guard let link = ParsedChannelLink.parse(from: message.message) else {
      currentIsIncoming = message.isIncoming
      messageLabel.text = Self.displayText(from: message)
      messageLabel.textColor = message.isIncoming ? UIColor(Color.messageText) : UIColor.white
      topMessageView.backgroundColor =
        message.isIncoming
        ? (UIColor(named: "MessageBubble") ?? UIColor(Color.messageBubble))
        : (UIColor(named: "Haven") ?? UIColor(Color.haven))
      titleLabel.text = "Channel Invite"
      subtitleLabel.text = nil
      subtitleLabel.isHidden = true
      timestampLabel.text = Self.timeText(from: message.timestamp)
      return
    }
    render(message: message, link: link, senderDisplayName: nil)
  }

  func render(
    message: ChatMessageModel,
    link: ParsedChannelLink,
    senderDisplayName: String?,
    senderColor: Int? = nil
  ) {
    currentIsIncoming = message.isIncoming
    let shouldShowSender = message.isIncoming && senderDisplayName != nil
    currentSenderColorHex = shouldShowSender ? senderColor : nil
    if shouldShowSender {
      senderLabel.isHidden = false
      senderLabel.text = senderDisplayName
      messageTopToTopConstraint?.isActive = false
      messageTopToSenderConstraint?.isActive = true
      updateSenderColor()
    } else {
      senderLabel.isHidden = true
      senderLabel.text = nil
      senderLabel.textColor = UIColor.secondaryLabel
      messageTopToSenderConstraint?.isActive = false
      messageTopToTopConstraint?.isActive = true
    }

    messageLabel.text = Self.displayText(from: message)
    messageLabel.textColor = message.isIncoming ? UIColor(Color.messageText) : UIColor.white
    topMessageView.backgroundColor =
      message.isIncoming
      ? (UIColor(named: "MessageBubble") ?? UIColor(Color.messageBubble))
      : (UIColor(named: "Haven") ?? UIColor(Color.haven))
    timestampLabel.text = Self.timeText(from: message.timestamp)
    iconView.image = UIImage(
      systemName: link.level == "Secret" ? "lock.circle.fill" : "number.circle.fill")
    titleLabel.text = link.name
    if link.description.isEmpty {
      subtitleLabel.isHidden = true
      subtitleLabel.text = nil
    } else {
      subtitleLabel.isHidden = false
      subtitleLabel.text = link.description
    }
  }

  override required init(frame: CGRect) {
    super.init(frame: frame)

    if #available(iOS 17.0, *) {
      registerForTraitChanges([UITraitUserInterfaceStyle.self]) {
        (self: ChannelLinkCell, previousTraitCollection: UITraitCollection) in
        self.updateSenderColor()
      }
    }

    backgroundColor = .clear
    contentView.backgroundColor = .clear

    bubbleView.translatesAutoresizingMaskIntoConstraints = false
    bubbleView.layer.cornerRadius = Self.bubbleCornerRadius
    bubbleView.layer.masksToBounds = true
    contentView.addSubview(bubbleView)

    topMessageView.translatesAutoresizingMaskIntoConstraints = false
    topMessageView.backgroundColor = UIColor(named: "MessageBubble")
    bubbleView.addSubview(topMessageView)

    senderLabel.translatesAutoresizingMaskIntoConstraints = false
    senderLabel.numberOfLines = 1
    senderLabel.font = Self.senderFont
    senderLabel.textColor = UIColor.secondaryLabel
    senderLabel.lineBreakMode = .byTruncatingTail
    senderLabel.isHidden = true
    topMessageView.addSubview(senderLabel)

    messageLabel.translatesAutoresizingMaskIntoConstraints = false
    messageLabel.numberOfLines = 0
    messageLabel.font = Self.messageFont
    topMessageView.addSubview(messageLabel)

    previewView.translatesAutoresizingMaskIntoConstraints = false
    previewView.backgroundColor = UIColor(Color.appBackground)
    previewView.layer.borderWidth = 1
    previewView.layer.borderColor = UIColor(Color.messageBubble).cgColor
    previewView.layer.cornerRadius = Self.bubbleCornerRadius
    previewView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
    previewView.layer.masksToBounds = true
    bubbleView.addSubview(previewView)

    let headerStack = UIStackView()
    headerStack.translatesAutoresizingMaskIntoConstraints = false
    headerStack.axis = .horizontal
    headerStack.spacing = Self.previewPadding
    headerStack.alignment = .top

    iconView.translatesAutoresizingMaskIntoConstraints = false
    iconView.contentMode = .scaleAspectFit
    iconView.tintColor = UIColor(named: "Haven") ?? UIColor(Color.haven)
    iconView.setContentHuggingPriority(.required, for: .horizontal)
    iconView.setContentCompressionResistancePriority(.required, for: .horizontal)
    iconView.image = UIImage(systemName: "number.circle.fill")

    titleLabel.numberOfLines = 1
    titleLabel.font = Self.titleFont
    titleLabel.textColor = UIColor.label
    titleLabel.lineBreakMode = .byTruncatingTail

    subtitleLabel.numberOfLines = 2
    subtitleLabel.font = Self.subtitleFont
    subtitleLabel.textColor = UIColor.secondaryLabel

    let titleStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
    titleStack.axis = .vertical
    titleStack.spacing = 2
    titleStack.alignment = .fill

    headerStack.addArrangedSubview(iconView)
    headerStack.addArrangedSubview(titleStack)

    previewView.addSubview(headerStack)

    buttonContainer.translatesAutoresizingMaskIntoConstraints = false
    buttonContainer.backgroundColor = (UIColor(named: "Haven") ?? UIColor(Color.haven))
      .withAlphaComponent(0.15)
    buttonContainer.layer.cornerRadius = Self.buttonCornerRadius
    buttonContainer.layer.masksToBounds = true
    previewView.addSubview(buttonContainer)

    buttonLabel.translatesAutoresizingMaskIntoConstraints = false
    buttonLabel.numberOfLines = 1
    buttonLabel.text = "Join Channel"
    buttonLabel.font = Self.buttonFont
    buttonLabel.textColor = UIColor(named: "Haven") ?? UIColor(Color.haven)
    buttonLabel.textAlignment = .center
    buttonContainer.addSubview(buttonLabel)

    timestampLabel.translatesAutoresizingMaskIntoConstraints = false
    timestampLabel.numberOfLines = 1
    timestampLabel.font = Self.timestampFont
    timestampLabel.textColor = UIColor.secondaryLabel
    timestampLabel.textAlignment = .right
    previewView.addSubview(timestampLabel)

    messageTopToTopConstraint = messageLabel.topAnchor.constraint(
      equalTo: topMessageView.topAnchor, constant: Self.messageVerticalPadding)
    messageTopToSenderConstraint = messageLabel.topAnchor.constraint(
      equalTo: senderLabel.bottomAnchor, constant: Self.senderBottomSpacing)
    messageTopToTopConstraint?.isActive = true

    NSLayoutConstraint.activate([
      bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor),
      bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
      bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

      topMessageView.topAnchor.constraint(equalTo: bubbleView.topAnchor),
      topMessageView.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor),
      topMessageView.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor),

      senderLabel.topAnchor.constraint(
        equalTo: topMessageView.topAnchor, constant: Self.messageVerticalPadding),
      senderLabel.leadingAnchor.constraint(
        equalTo: topMessageView.leadingAnchor, constant: Self.messageHorizontalPadding),
      senderLabel.trailingAnchor.constraint(
        equalTo: topMessageView.trailingAnchor, constant: -Self.messageHorizontalPadding),

      messageLabel.leadingAnchor.constraint(
        equalTo: topMessageView.leadingAnchor, constant: Self.messageHorizontalPadding),
      messageLabel.trailingAnchor.constraint(
        equalTo: topMessageView.trailingAnchor, constant: -Self.messageHorizontalPadding),
      messageLabel.bottomAnchor.constraint(
        equalTo: topMessageView.bottomAnchor, constant: -Self.messageVerticalPadding),

      previewView.topAnchor.constraint(equalTo: topMessageView.bottomAnchor),
      previewView.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor),
      previewView.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor),
      previewView.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor),

      headerStack.topAnchor.constraint(
        equalTo: previewView.topAnchor, constant: Self.previewPadding),
      headerStack.leadingAnchor.constraint(
        equalTo: previewView.leadingAnchor, constant: Self.previewPadding),
      headerStack.trailingAnchor.constraint(
        equalTo: previewView.trailingAnchor, constant: -Self.previewPadding),

      iconView.widthAnchor.constraint(equalToConstant: Self.iconSize),
      iconView.heightAnchor.constraint(equalToConstant: Self.iconSize),

      buttonContainer.topAnchor.constraint(
        equalTo: headerStack.bottomAnchor, constant: Self.sectionSpacing),
      buttonContainer.leadingAnchor.constraint(
        equalTo: previewView.leadingAnchor, constant: Self.previewPadding),
      buttonContainer.trailingAnchor.constraint(
        equalTo: previewView.trailingAnchor, constant: -Self.previewPadding),

      buttonLabel.topAnchor.constraint(
        equalTo: buttonContainer.topAnchor, constant: Self.previewPadding),
      buttonLabel.bottomAnchor.constraint(
        equalTo: buttonContainer.bottomAnchor, constant: -Self.previewPadding),
      buttonLabel.leadingAnchor.constraint(
        equalTo: buttonContainer.leadingAnchor, constant: Self.previewPadding),
      buttonLabel.trailingAnchor.constraint(
        equalTo: buttonContainer.trailingAnchor, constant: -Self.previewPadding),

      timestampLabel.topAnchor.constraint(
        equalTo: buttonContainer.bottomAnchor, constant: Self.sectionSpacing),
      timestampLabel.leadingAnchor.constraint(
        greaterThanOrEqualTo: previewView.leadingAnchor, constant: Self.previewPadding),
      timestampLabel.trailingAnchor.constraint(
        equalTo: previewView.trailingAnchor, constant: -Self.previewPadding),
      timestampLabel.bottomAnchor.constraint(
        equalTo: previewView.bottomAnchor, constant: -Self.previewPadding),
    ])
  }

  private func updateSenderColor() {
    if let hex = currentSenderColorHex {
      let isDark = traitCollection.userInterfaceStyle == .dark
      let color = Color(hexNumber: hex).adaptive(for: isDark ? .dark : .light)
      senderLabel.textColor = UIColor(color)
    } else {
      senderLabel.textColor = UIColor.secondaryLabel
    }
  }

  @available(iOS, deprecated: 17.0)
  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
      updateSenderColor()
      previewView.layer.borderColor = UIColor(Color.messageBubble).cgColor
      topMessageView.backgroundColor =
        currentIsIncoming
        ? (UIColor(named: "MessageBubble") ?? UIColor(Color.messageBubble))
        : (UIColor(named: "Haven") ?? UIColor(Color.haven))
      let havenColor = UIColor(named: "Haven") ?? UIColor(Color.haven)
      iconView.tintColor = havenColor
      buttonLabel.textColor = havenColor
      buttonContainer.backgroundColor = havenColor.withAlphaComponent(0.15)
    }
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    senderLabel.isHidden = true
    senderLabel.text = nil
    senderLabel.textColor = UIColor.secondaryLabel
    messageTopToSenderConstraint?.isActive = false
    messageTopToTopConstraint?.isActive = true
    subtitleLabel.isHidden = false
    subtitleLabel.text = nil
    currentSenderColorHex = nil
    currentIsIncoming = true
  }

  static func size(width: CGFloat, message: ChatMessageModel) -> CGRect {
    guard let link = ParsedChannelLink.parse(from: message.message) else {
      return TextCell.size(width: width, message: message)
    }
    return size(width: width, message: message, link: link, senderDisplayName: nil)
  }

  static func size(
    width: CGFloat,
    message: ChatMessageModel,
    link: ParsedChannelLink,
    senderDisplayName: String?
  ) -> CGRect {
    let senderHashPart = senderDisplayName?.hashValue ?? 0
    let key =
      "\(message.id)_\(message.message.hashValue)_\(width)_\(senderHashPart)_\(link.url.hashValue)"

    var cachedSize: CGRect?
    cacheQueue.sync {
      cachedSize = sizeCache[key]
    }
    if let cachedSize {
      return cachedSize
    }

    let bubbleWidth = max(0, min(width, width - Self.bubbleWidthInset))
    guard bubbleWidth > 0 else { return .zero }

    let sizingCell = Self.sizingCell
    sizingCell.bounds = CGRect(x: 0, y: 0, width: bubbleWidth, height: 1)
    sizingCell.contentView.bounds = sizingCell.bounds
    sizingCell.render(message: message, link: link, senderDisplayName: senderDisplayName)
    sizingCell.setNeedsLayout()
    sizingCell.layoutIfNeeded()

    let targetSize = CGSize(width: bubbleWidth, height: UIView.layoutFittingCompressedSize.height)
    let measuredSize = sizingCell.contentView.systemLayoutSizeFitting(
      targetSize,
      withHorizontalFittingPriority: .required,
      verticalFittingPriority: .fittingSizeLevel
    )

    let result = CGRect(
      x: 0,
      y: 0,
      width: bubbleWidth,
      height: ceil(measuredSize.height)
    )

    cacheQueue.async(flags: .barrier) {
      sizeCache[key] = result
    }
    return result
  }

  private static func displayText(from message: ChatMessageModel) -> String {
    // Keep channel-link cell text path aligned with TextCell.
    // `newRenderPlainText` can still contain legacy raw HTML for older rows.
    return NewMessageHTMLPrecomputer.precompute(rawHTML: message.message).plainText
  }

  private static func timeText(from date: Date) -> String {
    timeFormatter.string(from: date)
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

class DateCell: UICollectionViewCell {
  static let identifier = String(describing: DateCell.self)
  private static let font = UIFont.systemFont(ofSize: 12, weight: .medium)
  private static let nonFirstTopPadding: CGFloat = 28
  private static let bottomPadding: CGFloat = 12
  private static let badgeHorizontalPadding: CGFloat = 12
  private static let badgeVerticalPadding: CGFloat = 6
  private static let formatterCurrentYear: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEE d MMM"
    return formatter
  }()
  private static let formatterWithYear: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEE d MMM yyyy"
    return formatter
  }()

  private let badgeView = UIView()
  private let label = UILabel()
  private var topConstraint: NSLayoutConstraint?

  func render(date: Date, isFirst: Bool) {
    label.text = Self.dateText(for: date)
    topConstraint?.constant = isFirst ? 0 : Self.nonFirstTopPadding
  }

  override required init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .clear
    contentView.backgroundColor = .clear

    badgeView.translatesAutoresizingMaskIntoConstraints = false
    badgeView.backgroundColor = UIColor.secondarySystemBackground
    badgeView.layer.cornerRadius = 14
    badgeView.layer.masksToBounds = true
    contentView.addSubview(badgeView)

    label.translatesAutoresizingMaskIntoConstraints = false
    label.font = Self.font
    label.textColor = UIColor.secondaryLabel
    label.numberOfLines = 1
    badgeView.addSubview(label)

    let top = badgeView.topAnchor.constraint(equalTo: contentView.topAnchor)
    topConstraint = top

    NSLayoutConstraint.activate([
      top,
      badgeView.bottomAnchor.constraint(
        equalTo: contentView.bottomAnchor, constant: -Self.bottomPadding),
      badgeView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

      label.topAnchor.constraint(equalTo: badgeView.topAnchor, constant: Self.badgeVerticalPadding),
      label.bottomAnchor.constraint(
        equalTo: badgeView.bottomAnchor, constant: -Self.badgeVerticalPadding),
      label.leadingAnchor.constraint(
        equalTo: badgeView.leadingAnchor, constant: Self.badgeHorizontalPadding),
      label.trailingAnchor.constraint(
        equalTo: badgeView.trailingAnchor, constant: -Self.badgeHorizontalPadding),
    ])
  }

  static func size(width: CGFloat, date _: Date, isFirst: Bool) -> CGRect {
    let topPadding = isFirst ? CGFloat(0) : Self.nonFirstTopPadding
    let badgeHeight = ceil(font.lineHeight) + (Self.badgeVerticalPadding * 2)
    let height = topPadding + badgeHeight + Self.bottomPadding
    return CGRect(x: 0, y: 0, width: width, height: height)
  }

  private static func dateText(for date: Date) -> String {
    let calendar = Calendar.current
    if calendar.isDateInToday(date) {
      return "Today"
    }
    if calendar.isDateInYesterday(date) {
      return "Yesterday"
    }
    if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
      return formatterCurrentYear.string(from: date)
    }
    return formatterWithYear.string(from: date)
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

class LoadMoreMessages: UICollectionViewCell {
  static let identifier = String(describing: LoadMoreMessages.self)
  static let texts = "Load More Messages"
  let label: UILabel = UILabel()
  static var sizeCache: CGRect?
  func render() {
    self.label.text = "Load More Messages"
  }

  override required init(frame: CGRect) {
    super.init(frame: frame)
    // Make the cell visible for the example
    label.numberOfLines = 0
    label.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(label)
    NSLayoutConstraint.activate([
      label.topAnchor.constraint(equalTo: contentView.topAnchor),
      label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
      label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
    ])
  }

  static func size(width: CGFloat) -> CGRect {
    if let sizeCache {
      return sizeCache
    }
    let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
    let boundingBox = texts.boundingRect(
      with: constraintRect,
      options: .usesLineFragmentOrigin,
      attributes: [.font: UIFont.systemFont(ofSize: 17)],
      context: nil
    )
    let result = CGRect(
      x: boundingBox.origin.x,
      y: boundingBox.origin.y,
      width: ceil(boundingBox.width),
      height: ceil(boundingBox.height)
    )
    sizeCache = result
    return result
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
