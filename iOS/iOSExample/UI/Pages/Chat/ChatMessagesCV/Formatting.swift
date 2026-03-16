//
//  Formatting.swift
//  iOSExample
//
//  Created by Om More on 16/03/26.
//
//
//  Formatting.swift
//  iOSExample
//
//  Created by Om More on 16/03/26.
//
import Foundation
import UIKit // Required for UIFont and text attributes

extension NSRange {
    static var first: NSRange {
        NSRange(location: 0, length: 1)
    }

    init(_ location: Int) {
        self.init(location: location, length: 1)
    }
}

extension String {
    static let fontSize: CGFloat = 17
    static let defaultAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: fontSize),
        .foregroundColor: UIColor.label,
    ]

    /// Converts a string containing HTML tags to an NSAttributedString, removing trailing newlines and adjusting the font.
    var markdown: NSAttributedString {
        do {
            let attrStr = try NSMutableAttributedString(markdown: self)
            let fullRange = NSRange(location: 0, length: attrStr.length)

            let defaultFont = Self.defaultAttributes[.font] as? UIFont ?? UIFont.systemFont(ofSize: Self.fontSize)

            attrStr.enumerateAttribute(.font, in: fullRange, options: .longestEffectiveRangeNotRequired) { value, range, _ in
                if let currentFont = value as? UIFont {
                    let traits = currentFont.fontDescriptor.symbolicTraits
                    if traits.isEmpty {
                        attrStr.addAttribute(.font, value: defaultFont, range: range)
                    } else if let descriptor = defaultFont.fontDescriptor.withSymbolicTraits(traits) {
                        let newFont = UIFont(descriptor: descriptor, size: defaultFont.pointSize)
                        attrStr.addAttribute(.font, value: newFont, range: range)
                    }
                } else {
                    attrStr.addAttribute(.font, value: defaultFont, range: range)
                }
            }

            for (key, value) in Self.defaultAttributes where key != .font {
                attrStr.addAttribute(key, value: value, range: fullRange)
            }

            return attrStr
        } catch {
            print("Error converting HTML to NSAttributedString: \(error.localizedDescription)")
            return NSAttributedString(string: self, attributes: Self.defaultAttributes)
        }
    }

    var attr: NSAttributedString {
        return NSAttributedString(string: self, attributes: Self.defaultAttributes)
    }
}
