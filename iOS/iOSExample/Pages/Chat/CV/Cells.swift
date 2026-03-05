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
  private static let verticalPadding: CGFloat = 2
  private static let horizontalPadding: CGFloat = 8
  let label: UILabel = UILabel()
  func render(message: ChatMessageModel) {
    self.label.text = message.message
  }

  override required init(frame: CGRect) {
    super.init(frame: frame)
    // Make the cell visible for the example
    backgroundColor = UIColor(named: "MessageBubble")
    layer.cornerRadius = 8
    label.numberOfLines = 0
    label.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(label)
    NSLayoutConstraint.activate([
      label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Self.verticalPadding),
      label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Self.verticalPadding),
      label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Self.horizontalPadding),
      label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Self.horizontalPadding),
    ])
  }

  private static var sizeCache: [String: CGRect] = [:]
  private static let cacheQueue = DispatchQueue(
    label: "cv.textcell.sizeCache", attributes: .concurrent)

  static func size(width: CGFloat, message: ChatMessageModel) -> CGRect {
    let key = "\(message.id)_\(width)"

    var cachedSize: CGRect?
    cacheQueue.sync {
      cachedSize = sizeCache[key]
    }
    if let cached = cachedSize {
      return cached
    }

    let m = message.message
    let horizontalPadding = Self.horizontalPadding * 2
    let verticalPadding = Self.verticalPadding * 2
    let constraintRect = CGSize(
      width: max(0, width - horizontalPadding), height: .greatestFiniteMagnitude)
    let boundingBox = m.boundingRect(
      with: constraintRect,
      options: .usesLineFragmentOrigin,
      attributes: [.font: UIFont.systemFont(ofSize: 17)],
      context: nil
    )

    let result = CGRect(
      x: boundingBox.origin.x,
      y: boundingBox.origin.y,
      width: ceil(boundingBox.width) + horizontalPadding,
      height: ceil(boundingBox.height) + verticalPadding
    )

    cacheQueue.async(flags: .barrier) {
      sizeCache[key] = result
    }

    return result
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
