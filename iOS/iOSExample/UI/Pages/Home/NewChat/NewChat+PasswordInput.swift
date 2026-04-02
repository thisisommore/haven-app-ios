//
//  NewChat+PasswordInput.swift
//  iOSExample
//
//  Created by Om More on 17/12/25.
//

import Foundation
import SwiftUI

struct PasswordInputView: View {
  let url: String
  let onConfirm: (String) -> Void
  let onCancel: () -> Void

  @Environment(\.dismiss) var dismiss

  @State private var password: String = ""

  var body: some View {
    NavigationStack {
      Form {
        Section(header: Text("Private Channel")) {
          Text(
            "This channel is password protected. Enter the password to continue."
          )
          .font(.subheadline)
          .foregroundColor(.secondary)
        }

        Section(header: Text("Password")) {
          SecureField("Enter password", text: self.$password)
            .textContentType(.password)
            .textInputAutocapitalization(.never)
            .disableAutocorrection(true)
        }
      }
      .navigationTitle("Enter Password")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            self.onCancel()
            self.dismiss()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Confirm") {
            self.onConfirm(self.password)
            self.dismiss()
          }
          .disabled(self.password.isEmpty)
        }
      }
    }
  }
}
