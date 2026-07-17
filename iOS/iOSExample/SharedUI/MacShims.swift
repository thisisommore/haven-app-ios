//
//  MacShims.swift
//  iOSExample
//
//  No-op / AppKit-backed shims for iOS-only SwiftUI and UIKit APIs used by
//  shared (SharedUI) code, so those files compile unchanged on macOS.
//  Everything in this file is compiled for macOS only.
//

#if os(macOS)
  import AppKit
  import SwiftUI

  // MARK: - UIColor namespace, backed by NSColor

  /// Lets shared code write `UIColor.label` / `Color(uiColor: .systemBackground)`
  /// on macOS. Values map to the closest adaptive AppKit color.
  enum UIColor {
    static let label = NSColor.labelColor
    static let secondaryLabel = NSColor.secondaryLabelColor
    static let systemBackground = NSColor.windowBackgroundColor
    static let secondarySystemBackground = NSColor.controlBackgroundColor
    static let tertiarySystemBackground = NSColor.controlBackgroundColor
    static let systemGray4 = NSColor.systemGray
    static let systemGray6 = NSColor.systemGray.withAlphaComponent(0.12)
    static let separator = NSColor.separatorColor
  }

  /// Implicit-member lookups in `Color(uiColor: .secondarySystemBackground)`
  /// resolve against NSColor on macOS, so expose the same names there.
  /// (`label` already exists via `UXTypes.swift`.)
  extension NSColor {
    static var secondaryLabel: NSColor { .secondaryLabelColor }
    static var systemBackground: NSColor { .windowBackgroundColor }
    static var secondarySystemBackground: NSColor { .controlBackgroundColor }
    static var tertiarySystemBackground: NSColor { .controlBackgroundColor }
    static var systemGray4: NSColor { .systemGray }
    static var systemGray6: NSColor { .systemGray.withAlphaComponent(0.12) }
    static var separator: NSColor { .separatorColor }
  }

  extension Color {
    init(uiColor: NSColor) {
      self.init(nsColor: uiColor)
    }
  }

  // MARK: - UIScreen, backed by the main NSScreen

  /// Shared code uses `UIScreen.screenWidth` / `.w(_)` / `.h(_)` for sizing
  /// sheets and popovers; on macOS the main screen's visible frame is used.
  struct UIScreen {
    static let main = UIScreen()

    private init() {}

    var bounds: CGRect {
      NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1280, height: 800)
    }
  }

  // MARK: - Navigation bar APIs that do not exist on macOS (no-ops)

  enum NavigationBarTitleDisplayMode {
    case automatic
    case inline
    case large
  }

  extension View {
    func navigationBarTitleDisplayMode(_: NavigationBarTitleDisplayMode) -> some View {
      self
    }
  }

  // MARK: - Keyboard APIs (no physical keyboard configuration on mac)

  enum UIKeyboardType {
    case asciiCapable
  }

  enum TextInputAutocapitalization {
    case never
    case words
    case sentences
    case characters
  }

  extension View {
    func keyboardType(_: UIKeyboardType) -> some View {
      self
    }

    func textInputAutocapitalization(_: TextInputAutocapitalization?) -> some View {
      self
    }
  }

  // MARK: - Presentation adaptation (mac sheets/popovers ignore it)

  enum PresentationAdaptation {
    case popover
    case sheet
    case fullScreenCover
    case none
  }

  extension View {
    func presentationCompactAdaptation(_: PresentationAdaptation) -> some View {
      self
    }
  }

  // MARK: - UIPasteboard, backed by NSPasteboard

  final class UIPasteboard {
    static let general = UIPasteboard()

    private init() {}

    var string: String? {
      get { NSPasteboard.general.string(forType: .string) }
      set {
        NSPasteboard.general.clearContents()
        if let newValue {
          NSPasteboard.general.setString(newValue, forType: .string)
        }
      }
    }
  }

  // MARK: - Toolbar placements missing on macOS

  extension ToolbarItemPlacement {
    static let navigationBarLeading = ToolbarItemPlacement.automatic
    static let navigationBarTrailing = ToolbarItemPlacement.automatic
    static let topBarLeading = ToolbarItemPlacement.automatic
    static let topBarTrailing = ToolbarItemPlacement.automatic
  }
#endif
