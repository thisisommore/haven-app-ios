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
        HStack() {
            HTMLText(
                text,
                textColor: .messageReplyPreview,
                linkColor: .messageReplyPreview
            )
            .fontSize(12)
            .padding(.top, 12)
            .foregroundStyle(.black)
            .opacity(0.4)
            .font(.footnote)
            .lineLimit(4)
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
        .onTapGesture {
            onTap?()
        }
    }
}
