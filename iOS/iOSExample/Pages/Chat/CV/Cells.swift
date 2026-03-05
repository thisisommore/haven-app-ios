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
  private static let baseFont = UIFont.systemFont(ofSize: 17)
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
  let label: UILabel = UILabel()
  func render(message: ChatMessageModel) {
    switch Self.renderedContent(for: message) {
    case .plain(let text):
      label.attributedText = nil
      label.text = text
    case .rich(let attributed):
      label.text = nil
      label.attributedText = attributed
    }
  }

  override required init(frame: CGRect) {
    super.init(frame: frame)
    // Make the cell visible for the example
    backgroundColor = UIColor(named: "MessageBubble")
    layer.cornerRadius = 8
    label.numberOfLines = 0
    label.font = Self.baseFont
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

    let renderedContent = renderedContent(for: message)
    let horizontalPadding = Self.horizontalPadding * 2
    let verticalPadding = Self.verticalPadding * 2
    let constraintRect = CGSize(
      width: max(0, width - horizontalPadding), height: .greatestFiniteMagnitude)
    let boundingBox: CGRect
    switch renderedContent {
    case .plain(let text):
      boundingBox = text.boundingRect(
        with: constraintRect,
        options: .usesLineFragmentOrigin,
        attributes: [.font: Self.baseFont],
        context: nil
      )
    case .rich(let attributed):
      boundingBox = attributed.boundingRect(
        with: constraintRect,
        options: [.usesLineFragmentOrigin, .usesFontLeading],
        context: nil
      )
    }

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

  private static func attributedString(from payload: NewMessageParsedPayload) -> NSAttributedString {
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
        attributes[.font] = UIFont.monospacedSystemFont(ofSize: baseFont.pointSize, weight: .regular)
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
