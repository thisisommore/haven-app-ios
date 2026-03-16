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
    var html: NSAttributedString {
        guard let data = self.data(using: .utf8) else {
            return NSAttributedString(string: self)
        }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue,
        ]

        do {
            let attributedString = try NSMutableAttributedString(
                data: data,
                options: options,
                documentAttributes: nil
            )

            // 1. Strip out the unnecessary trailing newlines
            while attributedString.string.hasSuffix("\n") {
                attributedString.deleteCharacters(in: NSRange(attributedString.length - 1))
            }

            // 2. Strip out the unnecessary leading newlines
            while attributedString.string.hasPrefix("\n") {
                attributedString.deleteCharacters(in: NSRange.first)
            }

            // 3. Update the font natively without CSS
            let fullRange = NSRange(location: 0, length: attributedString.length)
            let baseFont = UIFont.systemFont(ofSize: 17)

            attributedString.beginEditing()

            attributedString.enumerateAttribute(.font, in: fullRange, options: []) { value, range, _ in
                guard let oldFont = value as? UIFont else { return }

                let traits = oldFont.fontDescriptor.symbolicTraits
                if let newDescriptor = baseFont.fontDescriptor.withSymbolicTraits(traits) {
                    let newFont = UIFont(descriptor: newDescriptor, size: baseFont.pointSize)
                    attributedString.addAttribute(.font, value: newFont, range: range)
                    attributedString.addAttribute(.foregroundColor, value: UIColor.label, range: range)
                } else {
                    attributedString.addAttributes(Self.defaultAttributes, range: range)
                }
            }
            attributedString.endEditing()

            return attributedString
        } catch {
            print("Error converting HTML to NSAttributedString: \(error.localizedDescription)")
            return NSAttributedString(string: self)
        }
    }

    var attr: NSAttributedString {
        return NSAttributedString(string: self, attributes: Self.defaultAttributes)
    }
}
