//
//  PasswordInputView.swift
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

    @State private var password: String = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Private Channel")) {
                    Text(
                        "This channel is password protected. Enter the password to continue."
                    )
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }

                Section(header: Text("Password")) {
                    SecureField("Enter password", text: $password)
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
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") {
                        onConfirm(password)
                        dismiss()
                    }
                    .disabled(password.isEmpty)
                }
            }
        }
    }
}
