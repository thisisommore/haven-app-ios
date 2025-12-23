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
        !encryptionPassword.isEmpty
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

                Text("Export the admin key for \"\(channelName)\" to share admin privileges with another user.")
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
                        SecureField("Enter password", text: $encryptionPassword)
                    }
                    .padding()
                    .background(Color.haven.opacity(0.08))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(encryptionPassword.isEmpty ? Color.clear : Color.haven, lineWidth: 1.5)
                    )
                }
                .padding(.horizontal, 24)

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 24)
                }

                VStack(spacing: 12) {
                    Button {
                        exportToFile()
                    } label: {
                        HStack {
                            Image(systemName: "doc.fill")
                            Text("Export to File")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isPasswordValid ? Color.haven : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(!isPasswordValid)

                    Button {
                        copyToClipboard()
                    } label: {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("Copy to Clipboard")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isPasswordValid ? Color.haven.opacity(0.15) : Color.gray.opacity(0.15))
                        .foregroundColor(isPasswordValid ? .haven : .gray)
                        .cornerRadius(10)
                    }
                    .disabled(!isPasswordValid)
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
                        dismiss()
                    }
                    .tint(.haven)
                }.hiddenSharedBackground()
            }
            .fileExporter(
                isPresented: $showFileExporter,
                document: document,
                contentType: .plainText,
                defaultFilename: "\(channelName)_admin_key.txt"
            ) { result in
                switch result {
                case let .success(url):
                    onSuccess("Exported to File")
                    dismiss()
                case let .failure(error):
                    print("Failed to save file: \(error)")
                    errorMessage = "Failed to save: \(error.localizedDescription)"
                }
            }
        }
    }

    private func exportToFile() {
        do {
            let key = try xxdk.exportChannelAdminKey(channelId: channelId, encryptionPassword: encryptionPassword)
            document = TextFileDocument(text: key)
            errorMessage = nil
            showFileExporter = true
        } catch {
            errorMessage = "Failed to export key: \(error.localizedDescription)"
        }
    }

    private func copyToClipboard() {
        do {
            let key = try xxdk.exportChannelAdminKey(channelId: channelId, encryptionPassword: encryptionPassword)
            UIPasteboard.general.string = key
            errorMessage = nil
            onSuccess("Copied to Clipboard")
            dismiss()
        } catch {
            errorMessage = "Failed to export key: \(error.localizedDescription)"
        }
    }
}



