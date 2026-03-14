//
//  DateBadgeCell.swift
//  iOSExample
//
//  Created by Om More on 10/03/26.
//

import UIKit

final class DateBadgeCell: UICollectionViewCell {
  static let identifier = String(describing: DateBadgeCell.self)
  private let container = UIView()
  let label = UILabel()
  static let paddingT: CGFloat = 22
  static let paddingB: CGFloat = 4
  static let innerPaddingX: CGFloat = 12
  static let innerPaddingY: CGFloat = 4
  static let innerPaddingXCal = innerPaddingX * 2
  static let innerPaddingYCal = innerPaddingY * 2

  override init(frame: CGRect) {
    super.init(frame: frame)
    makeUI()
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private static let textAttributes: [NSAttributedString.Key: Any] = [
    .font: UIFont.systemFont(ofSize: 10, weight: .medium),
  ]

  static func size(text: String, width: CGFloat) -> CGSize {
    let r = text.boundingRect(
      with: CGSize(width: width - self.innerPaddingXCal, height: .greatestFiniteMagnitude),
      options: .usesLineFragmentOrigin,
      attributes: Self.textAttributes,
      context: nil
    )

    let calculatedWidth = ceil(r.width) + self.innerPaddingXCal
    let calculatedHeight = ceil(r.height) + self.paddingB + self.paddingT + self.innerPaddingYCal

    return CGSize(width: calculatedWidth, height: calculatedHeight)
  }
}

extension DateBadgeCell {
  func makeUI() {
    contentView.addSubview(self.container)
    self.container.addSubview(self.label)

    self.container.backgroundColor = .tertiarySystemFill
    self.container.layer.cornerRadius = 10
    self.container.layer.masksToBounds = true

    self.container.snp.makeConstraints {
      $0.centerX.equalTo(contentView)
      $0.top.equalTo(contentView).offset(Self.paddingT)
      $0.bottom.equalTo(contentView).offset(-Self.paddingB)
    }

    self.label.snp.makeConstraints {
      $0.leading.equalTo(self.container).offset(Self.innerPaddingX)
      $0.trailing.equalTo(self.container).offset(-Self.innerPaddingX)
      $0.top.equalTo(self.container).offset(Self.innerPaddingY)
      $0.bottom.equalTo(self.container).offset(-Self.innerPaddingY)
    }

    self.label.font = UIFont.systemFont(ofSize: 10, weight: .medium)
    self.label.textColor = .secondaryLabel
    self.label.text = "10 AM 2002"
    self.label.numberOfLines = 1
    self.label.textAlignment = .center
  }
}
