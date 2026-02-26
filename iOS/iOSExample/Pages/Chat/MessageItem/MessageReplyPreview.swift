//
//  MessageReplyPreview.swift
//  iOSExample
//
//  Created by Om More on 19/10/25.
//

import SwiftUI
import UniformTypeIdentifiers

/// Shows a preview of the message being replied to
struct MessageReplyPreview: View {
    let text: String
    let isIncoming: Bool
    var onTap: (() -> Void)?

    var body: some View {
        HStack {
            NewRenderedMessageText(
                rawHTML: text,
                isIncoming: isIncoming,
                textColor: .messageReplyPreview,
                linkColor: .messageReplyPreview,
                fontSize: 12,
                lineLimit: 4
            )
            .padding(.top, 12)
            .foregroundStyle(.black)
            .opacity(0.4)
            .font(.footnote)
            .contextMenu {
                Button {
                    UIPasteboard.general.setValue(
                        stripParagraphTags(text),
                        forPasteboardType: UTType.plainText.identifier
                    )
                } label: {
                    Text("Copy")
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }
}
