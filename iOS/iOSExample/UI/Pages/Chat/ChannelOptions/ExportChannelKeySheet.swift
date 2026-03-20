//
//  ExportChannelKeySheet.swift
//  iOSExample
//
//  Created by Om More
//

import SwiftUI
import UniformTypeIdentifiers

struct ExportChannelKeySheet<T: XXDKP>: View {
  let channelId: String
  let channelName: String
  let xxdk: T
  let onSuccess: (String) -> Void

  @Environment(\.dismiss) private var dismiss

  @State private var showFileExporter = false
  @State private var encryptionPassword = ""
  @State private var document = TextFileDocument(text: "")
  @State private var errorMessage: String?

  private var isPasswordValid: Bool {
    !self.encryptionPassword.isEmpty
  }

  private func exportToFile() {
    do {
      let key = try xxdk.channel.exportChannelAdminKey(
        channelId: self.channelId, encryptionPassword: self.encryptionPassword
      )
      self.document = TextFileDocument(text: key)
      self.errorMessage = nil
      self.showFileExporter = true
    } catch {
      self.errorMessage = "Failed to export key: \(error.localizedDescription)"
    }
  }

  private func copyToClipboard() {
    do {
      let key = try xxdk.channel.exportChannelAdminKey(
        channelId: self.channelId, encryptionPassword: self.encryptionPassword
      )
      UIPasteboard.general.string = key
      self.errorMessage = nil
      self.onSuccess("Copied to Clipboard")
      self.dismiss()
    } catch {
      self.errorMessage = "Failed to export key: \(error.localizedDescription)"
    }
  }

  var body: some View {
    NavigationView {
      VStack(spacing: 24) {
        Image(systemName: "key.fill")
          .font(.system(size: 48))
          .foregroundColor(.haven)
          .padding(.top, 32)

        Text("Export Admin Key")
          .font(.title2)
          .fontWeight(.semibold)

        Text(
          "Export the admin key for \"\(self.channelName)\" to share admin privileges with another user."
        )
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
            self.exportToFile()
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
            self.copyToClipboard()
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

        Text("Keep this key secure. Anyone with this key can manage the channel.")
          .font(.caption)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 24)
          .padding(.bottom, 16)
      }
      .navigationTitle("Export Key")
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
        document: self.document,
        contentType: .plainText,
        defaultFilename: "\(self.channelName)_admin_key.txt"
      ) { result in
        switch result {
        case let .success(url):
          self.onSuccess("Exported to File")
          self.dismiss()
        case let .failure(error):
          AppLogger.channels.error(
            "Failed to save file: \(error.localizedDescription, privacy: .public)"
          )
          self.errorMessage = "Failed to save: \(error.localizedDescription)"
        }
      }
    }
  }
}
