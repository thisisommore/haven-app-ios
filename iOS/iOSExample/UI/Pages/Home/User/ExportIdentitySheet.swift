//
//  ExportIdentitySheet.swift
//  iOSExample
//
//  Created by Om More on 17/12/25.
//

import Foundation
import LocalAuthentication
import SwiftUI

struct ExportIdentitySheet<T: XXDKP>: View {
  let xxdk: T
  let onSuccess: (String) -> Void
  let codename: String
  @Environment(\.dismiss) private var dismiss
  @State private var encryptionPassword = ""
  @State private var showFileExporter = false
  @State private var exportedText: TextFileDocument?
  @State private var errorMessage: String?

  private var isPasswordValid: Bool {
    !self.encryptionPassword.isEmpty
  }

  private func exportToFile() {
    do {
      let exportedText = try xxdk.exportIdentity(password: self.encryptionPassword)
      self.exportedText = TextFileDocument(data: exportedText)
      self.errorMessage = nil
      self.showFileExporter = true
    } catch {
      self.errorMessage = "Failed to export: \(error.localizedDescription)"
    }
  }

  private func copyToClipboard() {
    do {
      let data = try xxdk.exportIdentity(password: self.encryptionPassword)
      UIPasteboard.general.string = try data.utf8()
      self.errorMessage = nil
      self.onSuccess("Copied to Clipboard")
      self.dismiss()
    } catch {
      self.errorMessage = "Failed to export: \(error.localizedDescription)"
    }
  }

  private func authenticateAndPerform(action: @escaping () -> Void) {
    let context = LAContext()
    var error: NSError?

    if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
      let reason = "Authenticate to export your identity."
      context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authenticationError in
        DispatchQueue.main.async {
          if success {
            action()
          } else {
            self.errorMessage = "Authentication failed: \(authenticationError?.localizedDescription ?? "Unknown error")"
          }
        }
      }
    } else {
      action()
    }
  }

  var body: some View {
    NavigationView {
      VStack(spacing: 24) {
        Image(systemName: "person.crop.circle.badge.checkmark")
          .font(.system(size: 48))
          .foregroundColor(.haven)
          .padding(.top, 32)

        Text("Export Codename")
          .font(.title2)
          .fontWeight(.semibold)

        Text("Export your codename to use on another device or back it up securely.")
          .font(.body)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 24)

        VStack(alignment: .leading, spacing: 8) {
          Text("Encryption Password")
            .font(.caption)
            .foregroundColor(.secondary)
          HStack(spacing: 12) {
            Image(systemName: "lock.fill")
              .foregroundColor(.haven)
              .frame(width: 20)
            SecureField("Enter password", text: self.$encryptionPassword)
          }
          .padding()
          .background(Color.haven.opacity(0.08))
          .cornerRadius(10)
          .overlay(
            RoundedRectangle(cornerRadius: 10)
              .stroke(self.encryptionPassword.isEmpty ? Color.clear : Color.haven, lineWidth: 1.5)
          )
        }
        .padding(.horizontal, 24)

        if let errorMessage {
          Text(errorMessage)
            .font(.caption)
            .foregroundColor(.red)
            .padding(.horizontal, 24)
        }

        VStack(spacing: 12) {
          Button {
            self.authenticateAndPerform {
              self.exportToFile()
            }
          } label: {
            HStack {
              Image(systemName: "doc.fill")
              Text("Export to File")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(self.isPasswordValid ? Color.haven : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(10)
          }
          .disabled(!self.isPasswordValid)

          Button {
            self.authenticateAndPerform {
              self.copyToClipboard()
            }
          } label: {
            HStack {
              Image(systemName: "doc.on.doc")
              Text("Copy to Clipboard")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(self.isPasswordValid ? Color.haven.opacity(0.15) : Color.gray.opacity(0.15))
            .foregroundColor(self.isPasswordValid ? .haven : .gray)
            .cornerRadius(10)
          }
          .disabled(!self.isPasswordValid)
        }
        .padding(.horizontal, 24)

        Spacer()

        Text("Keep this file secure. Anyone with this file and password can access your identity.")
          .font(.caption)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 24)
          .padding(.bottom, 16)
      }
      .navigationTitle("Export Codename")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Cancel") {
            self.dismiss()
          }
          .tint(.haven)
        }.hiddenSharedBackground()
      }
      .fileExporter(
        isPresented: self.$showFileExporter,
        document: self.exportedText,
        contentType: .json,
        defaultFilename: self.codename + "_export"
      ) { result in
        switch result {
        case .success:
          self.onSuccess("Exported to File")
          self.dismiss()
        case let .failure(error):
          self.errorMessage = "Failed to save: \(error.localizedDescription)"
        }
      }
    }
  }
}
