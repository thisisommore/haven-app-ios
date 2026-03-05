//
//  Cells.swift
//  iOSExample
//
//  Created by Om More on 04/03/26.
//
import UIKit

protocol CVCell: UICollectionViewCell {
  func render(message: ChatMessageModel)
  static func size(width: CGFloat, message: ChatMessageModel) -> CGRect
}

class TextCell: UICollectionViewCell, CVCell {
  static let identifier = String(describing: TextCell.self)
  let label: UILabel = UILabel()
  func render(message: ChatMessageModel) {
    self.label.text = message.message
  }

  override required init(frame: CGRect) {
    super.init(frame: frame)
    // Make the cell visible for the example
    backgroundColor = .systemBlue
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

  static func size(width: CGFloat, message: ChatMessageModel) -> CGRect {
    let m = message.message
    let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
    let boundingBox = m.boundingRect(
      with: constraintRect,
      options: .usesLineFragmentOrigin,
      attributes: [.font: UIFont.systemFont(ofSize: 17)],
      context: nil
    )

    return boundingBox
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
    sizeCache = boundingBox
    return boundingBox
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
