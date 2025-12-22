//
//  ImportChannelKeySheet.swift
//  iOSExample
//
//  Created by Om More
//

import SwiftUI
import UniformTypeIdentifiers

struct ImportChannelKeySheet<T: XXDKP>: View {
    let channelId: String
    let channelName: String
    let xxdk: T
    let onSuccess: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showFileImporter = false
    @State private var decryptionPassword = ""
    @State private var importedKeyContent: String?
    @State private var errorMessage: String?

    private var isPasswordValid: Bool {
        !decryptionPassword.isEmpty
    }

    private var canImport: Bool {
        isPasswordValid && importedKeyContent != nil
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "key.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.haven)
                    .padding(.top, 32)

                Text("Import Admin Key")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Import an admin key for \"\(channelName)\" to gain admin privileges.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Button {
                    showFileImporter = true
                } label: {
                    HStack {
                        Image(systemName: importedKeyContent != nil ? "checkmark.circle.fill" : "doc.fill")
                            .foregroundColor(.haven)
                            Text(importedKeyContent != nil ? "Key File Selected" : "Select Key File (.txt)")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.haven.opacity(0.15))
                    .foregroundColor(.haven)
                    .cornerRadius(10)
                }
                .padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Decryption Password")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.haven)
                            .frame(width: 20)
                        SecureField("Enter password", text: $decryptionPassword)
                    }
                    .padding()
                    .background(Color.haven.opacity(0.08))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(decryptionPassword.isEmpty ? Color.clear : Color.haven, lineWidth: 1.5)
                    )
                }
                .padding(.horizontal, 24)

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 24)
                }

                Button {
                    importKey()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Import Key")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canImport ? Color.haven : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(!canImport)
                .padding(.horizontal, 24)

                Spacer()

                Text("You will need the password used to encrypt this key.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
            .navigationTitle("Import Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .tint(.haven)
                }.hiddenSharedBackground()
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.plainText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case let .success(urls):
                    guard let url = urls.first else { return }
                    do {
                        guard url.startAccessingSecurityScopedResource() else {
                            errorMessage = "Cannot access the selected file"
                            return
                        }
                        defer { url.stopAccessingSecurityScopedResource() }
                        let content = try String(contentsOf: url, encoding: .utf8)
                        importedKeyContent = content
                        errorMessage = nil
                    } catch {
                        errorMessage = "Failed to read file: \(error.localizedDescription)"
                    }
                case let .failure(error):
                    errorMessage = "Failed to select file: \(error.localizedDescription)"
                }
            }
        }
    }

    private func importKey() {
        guard let keyContent = importedKeyContent else {
            errorMessage = "No key file selected"
            return
        }

        do {
            try xxdk.importChannelAdminKey(channelId: channelId, encryptionPassword: decryptionPassword, privateKey: keyContent)
            errorMessage = nil
            onSuccess("Key Imported Successfully")
            dismiss()
        } catch {
            errorMessage = "Import failed: \(error.localizedDescription)"
        }
    }
}



