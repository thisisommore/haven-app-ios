//
//  LogRow.swift
//  iOSExample
//
//  Created by Om More on 17/12/25.
//

import Foundation
import SwiftUI

struct LogRow: View {
  let message: StyledLogMessage
  let lineNumber: Int
  let searchText: String
  let isAlternate: Bool
  let showLineNumbers: Bool

  var body: some View {
    HStack(alignment: .top, spacing: 0) {
      // Line number
      if self.showLineNumbers {
        Text("\(self.lineNumber)")
          .font(.system(size: 11, weight: .regular, design: .monospaced))
          .foregroundColor(.secondary.opacity(0.5))
          .frame(width: 40, alignment: .trailing)
          .padding(.trailing, 12)
      }

      // Message text with highlighting
      HighlightedText(
        text: self.message.text,
        highlight: self.searchText,
        baseColor: self.textColor(for: self.message.level),
        highlightColor: .haven
      )
      .font(.system(size: 12, weight: .regular, design: .monospaced))
      .lineSpacing(2)
      .frame(maxWidth: .infinity, alignment: .leading)

      Spacer(minLength: 16)
    }
    .padding(.vertical, 6)
    .padding(.horizontal, 12)
    .background(self.isAlternate ? Color(uiColor: .secondarySystemBackground).opacity(0.5) : Color.clear)
    .contentShape(Rectangle())
    .contextMenu {
      Button(action: {
        UIPasteboard.general.string = self.message.text
      }) {
        Label("Copy", systemImage: "doc.on.doc")
      }
    }
  }

  private func textColor(for level: LogLevel) -> Color {
    switch level {
    case .error: return .red
    case .warning: return .orange
    case .debug: return .blue
    case .trace: return .purple
    default: return .primary
    }
  }
}
