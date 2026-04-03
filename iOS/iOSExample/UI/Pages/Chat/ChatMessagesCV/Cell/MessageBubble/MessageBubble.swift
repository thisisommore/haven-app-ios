//
//  TextCell+New.swift
//  iOSExample
//
//  Created by Om More on 23/03/26.
//
import SnapKit
import SwiftUI
import UIKit

extension MessageBubble {
  private static func text(for message: MessageWithSender) -> NSAttributedString {
    return self.text(for: message.message)
  }

  private static func text(for message: ChatMessageModel) -> NSAttributedString {
    message.attributedText()
  }

  private static func replyText(for message: MessageWithSender) -> NSAttributedString? {
    guard let replyTo = message.replyTo else { return nil }
    return self.text(for: replyTo)
  }

  private static func time(for message: MessageWithSender) -> String {
    message.message.timestamp.formatted(date: .omitted, time: .shortened)
  }
}

final class MessageBubble: UICollectionViewCell {
  private static let padding: CGFloat = 8
  private lazy var swipe = MessageBubbleSwipe(uiView: self, delegate: self)

  // Child components
  let c = UIView()
  let replyPreviewLabel = ReplyPreview()
  let senderLabel = SenderLabel()
  let msgLabel = MessageLabel()
  let timeLabel = TimeLabel()
  let reaction = MessageBubbleReactions()

  let clock = MessageBubbleClock()

  //

  // callbacks
  var onReplyPreviewClick: (() -> Void)?
  var onReactionPreviewTap: (() -> Void)?
  var onReply: (() -> Void)?
  var onReact: (() -> Void)?
  var onMuteUser: (() -> Void)?
  var onDelete: (() -> Void)?
  var canDelete = false
  var canMuteUser = false
  var onLinkTapped: ((URL) -> Void)?

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    self.makeUI()
    self.swipe.setupGesture(view: self)
  }

  override func prepareForReuse() {
    self.onReplyPreviewClick = nil
  }
}

extension MessageBubble: MessageBubbleSwipeDelegate {
  func onSwip() {
    self.onReply?()
  }
}

private extension MessageBubble {
  func makeUI() {
    self.c.backgroundColor = UIColor(Color.messageBubble)
    self.c.layer.cornerRadius = 12
    self.makeMsgLabel()
  }

  @objc private func replyPreviewTapped() {
    self.onReplyPreviewClick?()
  }

  @objc private func reactionPreviewTap() {
    self.onReactionPreviewTap?()
  }

  func makeMsgLabel() {
    self.c.snp.makeConstraints {
      contentView.addSubview(self.c)
      $0.top.left.right.equalToSuperview()
      $0.bottom.equalTo(contentView.snp.bottom).offset(-MessageBubbleReactions.reactionSideLength / 2)
    }
    self.senderLabel.snp.makeConstraints {
      self.c.addSubview(self.senderLabel)
      $0.top.left.right.equalToSuperview().inset(MessageBubble.padding)
    }

    self.replyPreviewLabel.snp.makeConstraints {
      self.c.addSubview(self.replyPreviewLabel)
      $0.top.equalTo(self.senderLabel.snp.bottom)
      $0.left.right.equalToSuperview().inset(MessageBubble.padding)

      self.replyPreviewLabel.addGestureRecognizer(
        UITapGestureRecognizer(
          target: self,
          action: #selector(self.replyPreviewTapped)
        )
      )
      self.replyPreviewLabel.isUserInteractionEnabled = true
    }

    self.msgLabel.snp.makeConstraints {
      self.msgLabel.delegate = self
      self.c.addSubview(self.msgLabel)
      $0.top.equalTo(self.replyPreviewLabel.snp.bottom)
      $0.left.right.equalToSuperview().inset(MessageBubble.padding)
    }

    self.clock.snp.makeConstraints {
      self.c.addSubview(self.clock)
      $0.top.equalTo(self.msgLabel.snp.bottom)
      $0.right.equalToSuperview().inset(MessageBubble.padding)
    }

    self.timeLabel.snp.makeConstraints {
      self.c.addSubview(self.timeLabel)
      $0.top.equalTo(self.msgLabel.snp.bottom)
      $0.right.equalTo(self.clock.snp.left)
    }

    self.reaction.snp.makeConstraints {
      self.contentView.addSubview(self.reaction)
      $0.centerY.equalTo(self.c.snp.bottom)
      $0.left.equalTo(self.contentView.snp.left).offset(4)

      self.reaction.addGestureRecognizer(
        UITapGestureRecognizer(
          target: self,
          action: #selector(self.reactionPreviewTap)
        )
      )
    }
  }
}

extension MessageBubble {
  /// Brief haven border, then fades out (e.g. scroll-to-message highlight).
  func highlight() {
    let view = self.c
    view.layer.borderColor = UIColor(Color.haven).cgColor
    view.layer.borderWidth = 1.5

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak view] in
      guard let view else { return }
      UIView.animate(withDuration: 0.5) {
        view.layer.borderWidth = 0
      }
    }
  }
}

extension MessageBubble: CVCell {
  typealias Data = MessageWithSender
  static let identifier = String(describing: MessageBubble.self)
  private static func padded(_ value: CGFloat) -> CGFloat {
    value - (2 * self.padding)
  }

  private static func padded(_ value: CGSize) -> CGSize {
    CGSize(width: value.width + (2 * self.padding),
           height: value.height + (2 * self.padding))
  }

  static func size(for data: Data, width: CGFloat) -> CGSize {
    let paddedW = self.padded(width)
    return self.padded(
      CGSize.maxW(
        MessageLabel.size(for: data.message.attributedText(), width: paddedW),
        SenderLabel.size(for: data, width: paddedW),
        TimeLabel.size(for: Self.time(for: data), width: paddedW),
        ReplyPreview.size(for: data.replyTo?.attributedText(), width: paddedW),

        data.reactionEmojis.isEmpty ? .zero : MessageBubbleReactions.size(for: data.reactionEmojis, width: paddedW)
      )
    )
  }

  func render(for data: Data) {
    self.senderLabel.render(for: data)
    self.msgLabel.render(for: Self.text(for: data))
    self.replyPreviewLabel.render(for: Self.replyText(for: data))
    self.clock.render(for: data.message.status == .unsent || data.message.status == .deleting)
    self.timeLabel.render(for: Self.time(for: data))
    self.reaction.render(for: data.reactionEmojis)
    self.c.snp.updateConstraints {
      $0.bottom
        .equalTo(contentView.snp.bottom)
        .offset(data.reactionEmojis.isEmpty ? 0 : -16)
    }
    if !data.sender.codename.isEmpty {
      if #available(iOS 26, *) {
        self.c.cornerConfiguration = .corners(
          topLeftRadius: data.message.isIncoming ? .fixed(6) : .fixed(12),
          topRightRadius: data.message.isIncoming ? .fixed(12) : .fixed(6),
          bottomLeftRadius: data.message.isIncoming ? .fixed(6) : .fixed(12),
          bottomRightRadius: data.message.isIncoming ? .fixed(12) : .fixed(6)
        )
      } else {
        self.c.layer.maskedCorners = data.message.isIncoming ? .right : .left
      }
    } else {
      if #available(iOS 26, *) {
        self.c.cornerConfiguration = .corners(
          topLeftRadius: .fixed(12),
          topRightRadius: .fixed(12),
          bottomLeftRadius: data.message.isIncoming ? .fixed(6) : .fixed(12),
          bottomRightRadius: data.message.isIncoming ? .fixed(12) : .fixed(6)
        )
      } else {
        self.c.layer.maskedCorners = [
          .top,
          data.message.isIncoming ? .bottomRight : .bottomLeft,
        ]
      }
    }
  }
}

extension MessageBubble: UITextViewDelegate {
  func textView(_: UITextView, shouldInteractWith URL: URL, in _: NSRange)
    -> Bool {
    self.onLinkTapped?(URL)
    return false
  }
}
