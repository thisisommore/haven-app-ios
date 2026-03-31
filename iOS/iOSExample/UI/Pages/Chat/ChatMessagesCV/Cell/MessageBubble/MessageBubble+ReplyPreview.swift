import SnapKit
import SwiftUI
import UIKit

final class ReplyPreview: UIView {
  static let padding: CGFloat = 4
  static let font = UIFont.systemFont(ofSize: 17)
  let tv = UITextView()
  private let orangeLine = UIView()
  private static let lineWidth: CGFloat = 3
  // 1. Keep a reference to a zero-height constraint
  private var zeroHeightConstraint: Constraint?
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.tv.isScrollEnabled = false
    self.tv.isEditable = false
    self.tv.textContainerInset = .zero
    self.tv.textContainer.lineFragmentPadding = 0
    self.orangeLine.backgroundColor = UIColor(Color.haven)
    self.layer.cornerRadius = 8
    self.layer.masksToBounds = true
    self.tv.font = Self.font
    self.tv.backgroundColor = .clear
    addSubview(self.orangeLine)
    self.orangeLine.snp.makeConstraints {
      $0.leading.top.bottom.equalToSuperview()
      $0.width.equalTo(Self.lineWidth)
    }
    addSubview(self.tv)
    self.tv.snp.makeConstraints {
      $0.leading.equalTo(self.orangeLine.snp.trailing).offset(8)
      $0.top.trailing.equalToSuperview().inset(Self.padding)
      $0.bottom.equalToSuperview().inset(Self.padding).priority(999)
    }

    self.snp.makeConstraints {
      self.zeroHeightConstraint = $0.height.equalTo(0).constraint
    }
    self.zeroHeightConstraint?.deactivate()
    // Style
    backgroundColor = UIColor(Color.messageReplyPreview)
    self.tv.linkTextAttributes = [
      .foregroundColor: UIColor(Color.haven),
      .underlineStyle: NSUnderlineStyle.single.rawValue,
      .underlineColor: UIColor(Color.haven),
      .backgroundColor: UIColor(Color.haven).withAlphaComponent(0.15),
    ]
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension CGFloat {
  var padded: CGFloat {
    self - ((2 * ReplyPreview.padding) + 8)
  }
}

private extension CGSize {
  var unpadded: CGSize {
    return CGSize(width: width + ((2 * ReplyPreview.padding) + 8),
                  height: height + (2 * ReplyPreview.padding))
  }
}

extension ReplyPreview: CVView {
  typealias Data = NSAttributedString?

  static func size(for text: Data, width: CGFloat) -> CGSize {
    guard let text else { return .zero }
    let rect = text.boundingRect(
      with: CGSize(width: width.padded, height: .greatestFiniteMagnitude),
      options: [.usesLineFragmentOrigin, .usesFontLeading],
      context: nil
    )
    return CGSize(width: ceil(rect.width), height: ceil(rect.height)).unpadded
  }

  func render(for text: Data) {
    guard let text else {
      self.zeroHeightConstraint?.activate()
      return
    }
    self.zeroHeightConstraint?.deactivate()
    self.tv.attributedText = text
  }
}
