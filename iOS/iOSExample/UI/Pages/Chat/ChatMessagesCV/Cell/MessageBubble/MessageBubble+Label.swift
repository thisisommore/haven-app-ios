import SwiftUI
import UIKit

final class MessageLabel: UITextView {
  override init(frame: CGRect, textContainer: NSTextContainer?) {
    super.init(frame: frame, textContainer: textContainer)
    makeUI()
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension MessageLabel {
  func makeUI() {
    backgroundColor = .clear
    isScrollEnabled = false
    isEditable = false
    textContainerInset = .zero
    self.textContainer.lineFragmentPadding = 0
    // Style
    linkTextAttributes = [
      .foregroundColor: UIColor(Color.haven),
      .underlineStyle: NSUnderlineStyle.single.rawValue,
      .underlineColor: UIColor(Color.haven),
      .backgroundColor: UIColor(Color.haven).withAlphaComponent(0.15),
    ]
  }
}

extension MessageLabel: CVView {
  typealias Data = NSAttributedString

  static func size(for text: Data, width: CGFloat) -> CGSize {
    let rect = text.boundingRect(
      with: CGSize(width: width, height: .greatestFiniteMagnitude),
      options: [.usesLineFragmentOrigin, .usesFontLeading],
      context: nil
    )
    return CGSize(width: ceil(rect.width), height: ceil(rect.height))
  }

  func render(for text: Data) {
    attributedText = text
  }
}
