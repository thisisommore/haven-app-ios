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
      Text(self.title)
        .font(.footnote)
        .foregroundStyle(self.isFocused ? BranchColor.primary : .secondary)

      HStack {
        Group {
          SecureField("-", text: self.$text)
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
            self.isInvalid
              ? Color.red
              : (self.isFocused
                ? BranchColor.primary
                : (self.text.isEmpty ? .clear : .separator)),
            lineWidth: self.isFocused ? 1.5 : 1
          )
      )
    }
  }
}
