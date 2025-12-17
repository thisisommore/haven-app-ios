//
//  ExportIdentitySheet.swift
//  iOSExample
//
//  Created by Om More on 17/12/25.
//

import SwiftUI
import Foundation

struct ExportIdentitySheet<T: XXDKP>: View {
    let xxdk: T
    let onSuccess: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var encryptionPassword = ""
    @State private var showFileExporter = false
    @State private var exportedText = ""
    @State private var errorMessage: String?

    private var isPasswordValid: Bool {
        !encryptionPassword.isEmpty
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
                        dismiss()
                    }
                    .tint(.haven)
                }.hiddenSharedBackground()
            }
            .fileExporter(
                isPresented: $showFileExporter,
                document: TextFileDocument(text: exportedText),
                contentType: .plainText,
                defaultFilename: "codename_backup.json"
            ) { result in
                switch result {
                case .success:
                    onSuccess("Exported to File")
                    dismiss()
                case let .failure(error):
                    errorMessage = "Failed to save: \(error.localizedDescription)"
                }
            }
        }
    }

    private func exportToFile() {
        do {
            let data = try xxdk.exportIdentity(password: encryptionPassword)
            exportedText = String(data: data, encoding: .utf8) ?? ""
            errorMessage = nil
            showFileExporter = true
        } catch {
            errorMessage = "Failed to export: \(error.localizedDescription)"
        }
    }

    private func copyToClipboard() {
        do {
            let data = try xxdk.exportIdentity(password: encryptionPassword)
            UIPasteboard.general.string = String(data: data, encoding: .utf8) ?? ""
            errorMessage = nil
            onSuccess("Copied to Clipboard")
            dismiss()
        } catch {
            errorMessage = "Failed to export: \(error.localizedDescription)"
        }
    }
}
