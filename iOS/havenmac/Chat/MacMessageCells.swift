//
//  MacMessageCells.swift
//  haven
//
//  NSCollectionView items hosting SwiftUI content (message bubbles and date
//  badges) inside NSHostingView. Auto Layout pins the hosting view to all
//  edges so compositional-layout estimated heights self-size correctly.
//

import AppKit
import SwiftUI

final class MacHostingCell: NSCollectionViewItem {
  static let messageReuseId = NSUserInterfaceItemIdentifier("chatMessage")
  static let dateReuseId = NSUserInterfaceItemIdentifier("chatDateBadge")

  private var hostingView: NSHostingView<AnyView>?

  override func loadView() {
    self.view = NSView()
    let hosting = NSHostingView(rootView: AnyView(EmptyView()))
    hosting.translatesAutoresizingMaskIntoConstraints = false
    self.view.addSubview(hosting)
    NSLayoutConstraint.activate([
      hosting.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
      hosting.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
      hosting.topAnchor.constraint(equalTo: self.view.topAnchor),
      hosting.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
    ])
    self.hostingView = hosting
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    self.hostingView?.rootView = AnyView(EmptyView())
  }

  func setContent<Content: View>(_ content: Content) {
    self.hostingView?.rootView = AnyView(content)
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
  }
}
