//
//  UXTypes.swift
//  iOSExample
//
//  Cross-platform typealiases so shared code can refer to colors and fonts
//  without caring about UIKit vs AppKit.
//

#if canImport(UIKit)
  import UIKit
  typealias UXColor = UIColor
  typealias UXFont = UIFont
#elseif canImport(AppKit)
  import AppKit
  typealias UXColor = NSColor
  typealias UXFont = NSFont

  extension NSColor {
    /// UIKit-style alias for `labelColor` so shared code can use one name.
    static var label: NSColor { .labelColor }
  }

  extension NSFont {
    /// UIKit-style italic system font, bridged through the font manager.
    static func italicSystemFont(ofSize size: CGFloat) -> NSFont {
      let font = NSFont.systemFont(ofSize: size)
      return NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
    }
  }
#endif
