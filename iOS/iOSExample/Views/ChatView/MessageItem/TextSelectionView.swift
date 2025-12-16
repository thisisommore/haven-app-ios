//
//  TextSelectionView.swift
//  iOSExample
//
//  Created by Cursor on 15/12/25.
//

import SwiftUI
import UIKit

struct SelectableTextView: UIViewRepresentable {
    let text: String

    func makeUIView(context _: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.textColor = .label
        textView.backgroundColor = UIColor.secondarySystemGroupedBackground
        textView.layer.cornerRadius = 16
        textView.textContainerInset = UIEdgeInsets(top: 24, left: 20, bottom: 24, right: 20)
        textView.dataDetectorTypes = .all
        return textView
    }

    func updateUIView(_ uiView: UITextView, context _: Context) {
        uiView.text = text
    }
}

struct TextSelectionView: View {
    let text: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                SelectableTextView(text: text)
                    .padding()
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
            }
            .navigationTitle("Message Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.medium)
                    .tint(.haven)
                }
                .hiddenSharedBackground()
            }
        }
    }
}
