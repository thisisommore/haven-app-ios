import SnapKit
import UIKit

final class MessageBubbleClock: UIImageView {
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
    image = UIImage(systemName: "clock")
    tintColor = .gray

    // 1. Establish initial size constraints (Valid even before it has a superview)
    self.snp.makeConstraints {
      $0.width.height.equalTo(14)
    }
  }

  convenience init() {
    self.init(frame: .zero)
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

extension MessageBubbleClock: CVView {
  typealias Data = Bool

  static func size(for enabled: Data, width _: CGFloat) -> CGSize {
    enabled ? CGSize(width: 20, height: 20) : .zero
  }

  func render(for enabled: Data) {
    isHidden = !enabled

    // 2. Dynamically collapse or expand the constraints
    self.snp.updateConstraints {
      $0.width.height.equalTo(enabled ? 14 : 0)
    }

    // Optional: Keep the symbol config consistent with the state
    self.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
      pointSize: enabled ? 17 : 0,
      weight: .medium
    )
  }
}
