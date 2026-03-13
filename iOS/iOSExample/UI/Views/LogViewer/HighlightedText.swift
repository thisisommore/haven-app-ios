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
    if self.highlight.isEmpty {
      Text(self.text)
        .foregroundColor(self.baseColor)
    } else {
      self.highlightedAttributedText
    }
  }

  private var highlightedAttributedText: Text {
    let ranges = self.text.ranges(of: self.highlight, options: .caseInsensitive)
    var result = Text("")
    var currentIndex = self.text.startIndex

    for range in ranges {
      // Add non-highlighted part
      if currentIndex < range.lowerBound {
        result =
          result
            + Text(self.text[currentIndex ..< range.lowerBound])
            .foregroundColor(self.baseColor)
      }
      // Add highlighted part with bold styling
      result =
        result
          + Text(self.text[range])
          .foregroundColor(self.highlightColor)
          .bold()

      currentIndex = range.upperBound
    }

    // Add remaining text
    if currentIndex < self.text.endIndex {
      result =
        result
          + Text(self.text[currentIndex...])
          .foregroundColor(self.baseColor)
    }

    return result
  }
}
