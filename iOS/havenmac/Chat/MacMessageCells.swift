//
//  MacMessageCells.swift
//  haven
//
//  NSCollectionView items hosting SwiftUI content (message bubbles and date
//  badges) via NSHostingController. Compositional-layout estimated heights
//  resolve from an explicit height constraint measured with sizeThatFits so
//  cells never overlap on macOS.
//

import AppKit
import SwiftUI

final class MacHostingCell: NSCollectionViewItem {
  static let messageReuseId = NSUserInterfaceItemIdentifier("chatMessage")
  static let dateReuseId = NSUserInterfaceItemIdentifier("chatDateBadge")

  /// Matches section leading+trailing insets in `MacChatMessagesVC.makeLayout`.
  private static let sectionHorizontalInsets: CGFloat = 32
  private static let fallbackWidth: CGFloat = 400
  private static let minHeight: CGFloat = 1

  private var hostingController: NSHostingController<AnyView>?
  private var heightConstraint: NSLayoutConstraint?

  override func loadView() {
    let container = NSView()
    container.wantsLayer = true
    self.view = container

    let hosting = NSHostingController(rootView: AnyView(EmptyView()))
    // Without this, the hosting view reports no usable height and estimated
    // compositional-layout sizes never expand → cells overlap on macOS.
    hosting.sizingOptions = [.intrinsicContentSize]
    hosting.view.translatesAutoresizingMaskIntoConstraints = false
    hosting.view.setContentHuggingPriority(.required, for: .vertical)
    hosting.view.setContentCompressionResistancePriority(.required, for: .vertical)
    // NSCollectionViewItem is an NSViewController — keep hosting in the VC
    // hierarchy so SwiftUI layout/environment stay valid.
    self.addChild(hosting)
    container.addSubview(hosting.view)

    // Explicit height backstop: sizeThatFits is reliable for SwiftUI-in-
    // collection-view on AppKit, where pure intrinsic size often fails.
    let height = container.heightAnchor.constraint(equalToConstant: 44)
    height.priority = .required
    height.identifier = "MacHostingCell.height"

    NSLayoutConstraint.activate([
      hosting.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      hosting.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      hosting.view.topAnchor.constraint(equalTo: container.topAnchor),
      hosting.view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      height,
    ])
    self.hostingController = hosting
    self.heightConstraint = height
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    self.hostingController?.rootView = AnyView(EmptyView())
    self.heightConstraint?.constant = 44
  }

  func setContent<Content: View>(_ content: Content) {
    // fixedSize(vertical:) forces a definite content height so measurement and
    // layout agree (horizontal Spacers only expand on the width axis).
    self.hostingController?.rootView = AnyView(
      content
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    )
    self.recomputeHeight()
  }

  override func apply(_ layoutAttributes: NSCollectionViewLayoutAttributes) {
    super.apply(layoutAttributes)
    // Width is authoritative here; remeasure so the height constraint matches
    // the final column width (important after window resize).
    self.recomputeHeight(width: layoutAttributes.frame.width)
  }

  private func recomputeHeight(width: CGFloat? = nil) {
    guard let hosting = hostingController else { return }

    let targetWidth: CGFloat = {
      if let width, width > 1 { return width }
      if self.view.bounds.width > 1 { return self.view.bounds.width }
      if let cvWidth = self.collectionView?.bounds.width, cvWidth > 1 {
        return max(cvWidth - Self.sectionHorizontalInsets, 100)
      }
      return Self.fallbackWidth
    }()

    let fitting = hosting.sizeThatFits(
      in: CGSize(width: targetWidth, height: CGFloat.greatestFiniteMagnitude)
    )
    let height = max(ceil(fitting.height), Self.minHeight)
    guard abs((self.heightConstraint?.constant ?? 0) - height) > 0.5 else {
      hosting.view.invalidateIntrinsicContentSize()
      return
    }
    self.heightConstraint?.constant = height
    hosting.view.invalidateIntrinsicContentSize()
  }
}

/// Centered date separator badge, mirroring the iOS DateBadgeCell style.
struct MacDateBadge: View {
  let text: String

  var body: some View {
    Text(self.text)
      .font(.caption)
      .foregroundStyle(.secondary)
      .padding(.horizontal, 10)
      .padding(.vertical, 3)
      .background(.regularMaterial, in: Capsule())
      .padding(.top, 14)
      .padding(.bottom, 6)
      .frame(maxWidth: .infinity)
      .fixedSize(horizontal: false, vertical: true)
  }
}
