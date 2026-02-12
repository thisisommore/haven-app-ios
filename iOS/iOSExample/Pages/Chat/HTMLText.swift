//
//  HTMLText.swift
//  iOSExample
//
//  Created by Om More on 29/09/25.
//  Simplified for testing: no HTML parsing, show raw text.
//

import SwiftUI
import UIKit

@available(iOS 15.0, *)
struct HTMLText: View, Equatable {
    private let html: String
    private let textColor: Color
    private let linkColor: Color
    private let lineLimit: Int?
    private let underlineLinks: Bool
    private let baseTextStyle: UIFont.TextStyle
    private let preserveSizes: Bool
    private let preserveBoldItalic: Bool
    private let customFontSize: CGFloat?

    /// - Parameters:
    ///   - html: Raw HTML string.
    ///   - textColor: Desired color for all text (default: `.white`).
    ///   - linkColor: Desired color for link text/underline (default: `.white`).
    ///   - underlineLinks: Whether links should be underlined (default: `true`).
    ///   - baseTextStyle: Base text style used if a run has no size (default: `.body`).
    ///   - preserveSizes: Keep original point sizes from HTML (keeps H1/H2 larger). Default `true`.
    ///   - preserveBoldItalic: Keep bold/italic traits from HTML. Default `true`.
    init(
        _ html: String,
        textColor: Color = .white,
        linkColor: Color = .white,
        underlineLinks: Bool = true,
        baseTextStyle: UIFont.TextStyle = .body,
        preserveSizes: Bool = true,
        preserveBoldItalic: Bool = true,
        customFontSize: CGFloat? = nil,
        lineLimit: Int? = nil
    ) {
        self.html = html
        self.textColor = textColor
        self.linkColor = linkColor
        self.underlineLinks = underlineLinks
        self.baseTextStyle = baseTextStyle
        self.preserveSizes = preserveSizes
        self.preserveBoldItalic = preserveBoldItalic
        self.customFontSize = customFontSize
        self.lineLimit = lineLimit
    }

    static func == (lhs: HTMLText, rhs: HTMLText) -> Bool {
        lhs.html == rhs.html &&
            lhs.textColor == rhs.textColor &&
            lhs.linkColor == rhs.linkColor &&
            lhs.underlineLinks == rhs.underlineLinks &&
            lhs.baseTextStyle == rhs.baseTextStyle &&
            lhs.preserveSizes == rhs.preserveSizes &&
            lhs.preserveBoldItalic == rhs.preserveBoldItalic &&
            lhs.customFontSize == rhs.customFontSize &&
            lhs.lineLimit == rhs.lineLimit
    }

    @ViewBuilder
    var body: some View {
        if let customFontSize {
            Text(verbatim: html)
                .font(.system(size: customFontSize))
                .foregroundStyle(textColor)
                .tint(linkColor)
                .lineLimit(lineLimit)
        } else {
            Text(verbatim: html)
                .foregroundStyle(textColor)
                .tint(linkColor)
                .lineLimit(lineLimit)
        }
    }

    /// Modifier to set a custom font size
    func fontSize(_ size: CGFloat) -> HTMLText {
        HTMLText(
            html,
            textColor: textColor,
            linkColor: linkColor,
            underlineLinks: underlineLinks,
            baseTextStyle: baseTextStyle,
            preserveSizes: preserveSizes,
            preserveBoldItalic: preserveBoldItalic,
            customFontSize: size,
            lineLimit: lineLimit
        )
    }
}

@available(iOS 15.0, *)
struct HTMLText_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            HTMLText("""
                     <p>This is a paragraph with a <a href=\"https://example.com\">link</a>,
                     and <strong>bold</strong>/<em>italic</em> text.</p>
                     <h2>Heading keeps larger size</h2>
                     <p>Another paragraph to show multiple lines in the skeleton.</p>
                     """,
                     textColor: .white,
                     linkColor: .white,
                     underlineLinks: true,
                     baseTextStyle: .body,
                     preserveSizes: true,
                     preserveBoldItalic: true)

            HTMLText("""
                     <p>This is another message with different HTML.</p>
                     """,
                     textColor: .white,
                     linkColor: .white)
        }
        .padding()
        .background(Color.blue)
        .previewLayout(.sizeThatFits)
    }
}
