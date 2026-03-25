import SwiftUI
import UIKit

private extension String {
  static func * (lhs: String, rhs: Int) -> String {
    String(repeating: lhs, count: rhs)
  }
}

final class TimeLabel: UILabel {
  static let font = UIFont.systemFont(ofSize: 12)
  static let size = {
    let rect = ((" " * 4) + "10:10pm").boundingRect(
      with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
      options: [.usesLineFragmentOrigin, .usesFontLeading],
      attributes: [.font: TimeLabel.font],
      context: nil
    )
    return CGSize(width: ceil(rect.width), height: ceil(rect.height))
  }()

  override init(frame: CGRect) {
    super.init(frame: frame)
    self.translatesAutoresizingMaskIntoConstraints = false
    self.textColor = .gray
    self.font = Self.font
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

extension TimeLabel: CVView {
  typealias Data = String

  static func size(for data: Data, width _: CGFloat) -> CGSize {
    if data == "" {
      return .zero
    } else {
      return self.size
    }
  }

  func render(for data: Data) {
    self.text = data
  }
}
