import SwiftUI
import UIKit

final class SenderLabel: UILabel {
  static let font = UIFont.systemFont(ofSize: 12)
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.translatesAutoresizingMaskIntoConstraints = false
    self.font = Self.font
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

extension SenderLabel: CVView {
  typealias Data = MessageWithSender

  static func size(for data: Data, width: CGFloat) -> CGSize {
    guard let sender = data.sender else { return .zero }
    // self sender have empty string
    if sender == "" { return .zero }
    let rect = sender.boundingRect(
      with: CGSize(width: width, height: .greatestFiniteMagnitude),
      options: [.usesLineFragmentOrigin, .usesFontLeading],
      attributes: [.font: Self.font],
      context: nil
    )
    return CGSize(width: ceil(rect.width), height: ceil(rect.height))
  }

  func render(for data: Data) {
    self.text = data.sender
    if let colorHex = data.colorHex {
      self.textColor = UIColor { traitCollection in
        let colorScheme: ColorScheme =
          traitCollection.userInterfaceStyle == .dark ? .dark : .light
        return UIColor(Color(hexNumber: colorHex).adaptive(for: colorScheme))
      }
    }
  }
}
