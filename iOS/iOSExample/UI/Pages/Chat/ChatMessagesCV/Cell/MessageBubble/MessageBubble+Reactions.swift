import SwiftUI
import UIKit

final class MessageBubbleReactions: UIView {
  static let reactionSideLength: CGFloat = {
    let font = UIFont.preferredFont(forTextStyle: .body)
    let rect = ("😂" as NSString).boundingRect(
      with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
      options: [.usesLineFragmentOrigin, .usesFontLeading],
      attributes: [.font: font],
      context: nil
    )
    return max(ceil(rect.width), ceil(rect.height))
  }()

  let emoji1 = Reaction()

  let emoji2 = Reaction()
  let emoji3 = Reaction()
  override init(frame: CGRect) {
    super.init(frame: frame)

    addSubview(self.emoji1)
    addSubview(self.emoji2)
    addSubview(self.emoji3)
    let side = Self.reactionSideLength

    self.snp.makeConstraints {
      $0.height.equalTo(Self.reactionSideLength)
      $0.width.equalTo((Self.reactionSideLength + 2) * 3)
    }
    self.emoji1.snp.makeConstraints {
      $0.size.equalTo(side)
      $0.top.equalToSuperview()
      $0.left.equalToSuperview()
      $0.bottom.equalToSuperview()
    }
    self.emoji2.snp.makeConstraints {
      $0.size.equalTo(side)
      $0.left.equalTo(self.emoji1.snp.right).offset(2)
      $0.top.equalToSuperview()
    }
    self.emoji3.snp.makeConstraints {
      $0.size.equalTo(side)
      $0.left.equalTo(self.emoji2.snp.right).offset(2)
      $0.top.equalToSuperview()
    }
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

extension Collection {
  subscript(safe index: Index) -> Element? {
    indices.contains(index) ? self[index] : nil
  }

  subscript(exist index: Index) -> Bool {
    indices.contains(index)
  }
}

extension MessageBubbleReactions: CVView {
  typealias Data = [String]

  private static let nonEmptySize = CGSize(
    width: (MessageBubbleReactions.reactionSideLength + 2) * 3,
    height: MessageBubbleReactions.reactionSideLength
  )

  func render(for data: Data) {
    self.manageVisibility(for: data)
    self.emoji1.t.text = data[safe: 0]
    self.emoji2.t.text = data[safe: 1]
    if data[safe: 2] != nil {
      self.emoji3.t.text = "+"
    }
  }

  func manageVisibility(for data: Data) {
    self.isHidden = data.isEmpty
    self.emoji1.isHidden = !data[exist: 0]
    self.emoji2.isHidden = !data[exist: 1]
    self.emoji3.isHidden = !data[exist: 2]
  }

  static func size(for data: [String], width _: CGFloat) -> CGSize {
    data.isEmpty ? .zero : self.nonEmptySize
  }
}

final class Reaction: UIView {
  let t = UILabel()
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.t.font = UIFont.preferredFont(forTextStyle: .body)
    self.backgroundColor = UIColor(Color.messageBubbleReactionBG)
    self.layer.cornerRadius = 10
    self.addSubview(self.t)
    self.t.snp.makeConstraints {
      $0.center.equalToSuperview()
    }
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
