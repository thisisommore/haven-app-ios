//
//  MacUICommon.swift
//  haven
//
//  Small shared building blocks for the mac dialogs.
//

import AppKit
import SwiftUI

/// Settings-style row: label on the leading edge, control on the trailing
/// edge (LabeledContent only does this inside a Form on macOS).
struct MacSettingRow<Content: View>: View {
  let title: String
  @ViewBuilder let content: Content

  init(_ title: String, @ViewBuilder content: () -> Content) {
    self.title = title
    self.content = content()
  }

  var body: some View {
    HStack {
      Text(self.title)
      Spacer()
      self.content
    }
  }
}

// MARK: - Dismiss sheet on outside click

extension View {
  /// Dismisses a macOS sheet when the user clicks outside its window.
  ///
  /// SwiftUI/AppKit modal sheets do not dismiss on outside click by default
  /// (only Escape / explicit close). There is no first-party SwiftUI API for
  /// this; the supported approach is an `NSEvent` local monitor that calls
  /// `dismiss` when a mouse-down lands outside the sheet frame.
  ///
  /// Apply to the **content** of every `.sheet` presentation.
  func dismissOnOutsideClick() -> some View {
    modifier(DismissOnOutsideClickModifier())
  }
}

private struct DismissOnOutsideClickModifier: ViewModifier {
  @Environment(\.dismiss) private var dismiss

  func body(content: Content) -> some View {
    content.background(
      OutsideClickDismissInstaller(onOutsideClick: { self.dismiss() })
        .frame(width: 0, height: 0)
    )
  }
}

/// Installs a local mouse-down monitor while the hosting sheet window is
/// visible. Clicks whose screen location falls outside the sheet (and not on
/// a nested sheet / popover / menu belonging to it) trigger dismissal.
private struct OutsideClickDismissInstaller: NSViewRepresentable {
  let onOutsideClick: () -> Void

  func makeNSView(context: Context) -> OutsideClickNSView {
    let view = OutsideClickNSView()
    view.onOutsideClick = onOutsideClick
    return view
  }

  func updateNSView(_ nsView: OutsideClickNSView, context: Context) {
    nsView.onOutsideClick = onOutsideClick
  }

  static func dismantleNSView(_ nsView: OutsideClickNSView, coordinator: ()) {
    nsView.teardown()
  }

  final class OutsideClickNSView: NSView {
    var onOutsideClick: (() -> Void)?
    private var monitor: Any?

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      self.teardown()
      guard self.window != nil else { return }
      self.installMonitor()
    }

    func teardown() {
      if let monitor {
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
      }
    }

    private func installMonitor() {
      self.monitor = NSEvent.addLocalMonitorForEvents(
        matching: [.leftMouseDown, .rightMouseDown]
      ) { [weak self] event in
        guard let self else { return event }
        if self.shouldDismiss(for: event) {
          // Swallow the click so it does not land on the parent after dismiss.
          DispatchQueue.main.async {
            self.onOutsideClick?()
          }
          return nil
        }
        return event
      }
    }

    private func shouldDismiss(for event: NSEvent) -> Bool {
      guard let sheetWindow = self.window, sheetWindow.isVisible else { return false }

      // Nested sheet is on top — let that sheet own outside-click dismiss.
      if sheetWindow.attachedSheet != nil { return false }

      // Menus / higher-level popups should not dismiss the sheet.
      if let eventWindow = event.window,
         eventWindow.level.rawValue > sheetWindow.level.rawValue
      {
        return false
      }

      // Click landed in this sheet or one of its child windows (popover, nested UI).
      if let eventWindow = event.window, Self.isDescendant(eventWindow, of: sheetWindow) {
        return false
      }

      // Screen-space fallback: some parent-window clicks report a non-descendant
      // event.window; still treat hits inside our frame as inside.
      if sheetWindow.frame.contains(NSEvent.mouseLocation) {
        return false
      }

      return true
    }

    private static func isDescendant(_ window: NSWindow, of ancestor: NSWindow) -> Bool {
      if window === ancestor { return true }
      if window.sheetParent === ancestor { return true }
      var parent = window.parent
      while let p = parent {
        if p === ancestor { return true }
        parent = p.parent
      }
      return false
    }

    deinit {
      self.teardown()
    }
  }
}
