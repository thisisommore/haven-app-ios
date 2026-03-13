//
//  HighlightedText.swift
//  iOSExample
//
//  Created by Om More on 17/12/25.
//

import Foundation
import SwiftUI

struct HighlightedText: View {
    let text: String
    let highlight: String
    let baseColor: Color
    let highlightColor: Color

    var body: some View {
        if highlight.isEmpty {
            Text(text)
                .foregroundColor(baseColor)
        } else {
            highlightedAttributedText
        }
    }

    private var highlightedAttributedText: Text {
        let ranges = text.ranges(of: highlight, options: .caseInsensitive)
        var result = Text("")
        var currentIndex = text.startIndex

        for range in ranges {
            // Add non-highlighted part
            if currentIndex < range.lowerBound {
                result = result + Text(text[currentIndex ..< range.lowerBound])
                    .foregroundColor(baseColor)
            }
            // Add highlighted part with bold styling
            result = result + Text(text[range])
                .foregroundColor(highlightColor)
                .bold()

            currentIndex = range.upperBound
        }

        // Add remaining text
        if currentIndex < text.endIndex {
            result = result + Text(text[currentIndex...])
                .foregroundColor(baseColor)
        }

        return result
    }
}
