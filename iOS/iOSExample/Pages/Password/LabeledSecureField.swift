//
//  Lab.swift
//  iOSExample
//
//  Created by Om More on 16/12/25.
//
import Foundation
import SwiftUI

struct LabeledSecureField: View {
    let title: String
    @Binding var text: String
    var isInvalid: Bool
    var isFocused: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(isFocused ? BranchColor.primary : .secondary)

            HStack {
                Group {
                    SecureField("-", text: $text)
                        .textContentType(.newPassword)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .keyboardType(.asciiCapable)
                }
                .privacySensitive()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isInvalid
                            ? Color.red
                            : (isFocused
                                ? BranchColor.primary
                                : (text.isEmpty ? .clear : .separator)),
                        lineWidth: isFocused ? 1.5 : 1
                    )
            )
        }
    }
}
