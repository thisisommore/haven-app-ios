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
            if showLineNumbers {
                Text("\(lineNumber)")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.5))
                    .frame(width: 40, alignment: .trailing)
                    .padding(.trailing, 12)
            }

            // Message text with highlighting
            HighlightedText(
                text: message.text,
                highlight: searchText,
                baseColor: textColor(for: message.level),
                highlightColor: .haven
            )
            .font(.system(size: 12, weight: .regular, design: .monospaced))
            .lineSpacing(2)
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 16)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(isAlternate ? Color(uiColor: .secondarySystemBackground).opacity(0.5) : Color.clear)
        .contentShape(Rectangle())
        .contextMenu {
            Button(action: {
                UIPasteboard.general.string = message.text
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
