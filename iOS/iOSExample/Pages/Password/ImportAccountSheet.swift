//
//  ImportAccountSheet.swift
//  iOSExample
//
//  Created by Om More on 16/12/25.
//

import Foundation
import SwiftUI

struct ImportAccountSheet<T: XXDKP>: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var navigation: AppNavigationPath
    @EnvironmentObject var xxdk: T
    @EnvironmentObject var sm: AppStorage

    @Binding var importPassword: String
    @State private var selectedFileURL: URL?
    @State private var showFilePicker = false
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Import your account")
                            .font(.title2)
                            .bold()

                        Text(
                            "Note that importing your account will only restore your codename. You need to rejoin manually any previously joined channel"
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    // File picker
                    Button(action: { showFilePicker = true }) {
                        HStack {
                            Image(systemName: "doc")
                            Text(
                                selectedFileURL?.lastPathComponent
                                    ?? "Choose a file"
                            )
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.separator, lineWidth: 1)
                        )
                    }
                    .foregroundStyle(.primary)

                    // Password field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Unlock export with your password")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        SecureField("-", text: $importPassword)
                            .textContentType(.password)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.secondarySystemBackground))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.separator, lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }.tint(.haven)
                }.hiddenSharedBackground()
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        handleImport()
                    } label: {
                        if isImporting {
                            ProgressView()
                        } else {
                            Text("Import")
                        }
                    }
                    .tint(.haven)
                    .disabled(importPassword.isEmpty || selectedFileURL == nil || isImporting)
                }.hiddenSharedBackground()
            }
            .alert("Import Failed", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Unknown error")
            }

            if isImporting {
                VStack {
                    Text(xxdk.status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                selectedFileURL = url
            }
        }
    }

    private func handleImport() {
        guard let url = selectedFileURL else { return }
        isImporting = true

        // Access security scoped resource
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            // Call import
            let identity = try xxdk.importIdentity(password: importPassword, data: data)

            // Use the import password as the app password
            try sm.storePassword(importPassword)

            Task.detached {
                // Initialize Cmix before loading identity
                await xxdk.setUpCmix()

                // Start network follower to ensure connectivity before load blocks
                await xxdk.startNetworkFollower()

                await xxdk.load(privateIdentity: identity)
            }

            // Navigate immediately
            isImporting = false
            dismiss()
            navigation.path.append(Destination.landing)

        } catch {
            AppLogger.identity.error("Import failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
            showError = true
            isImporting = false
        }
    }
}

extension Color {
    static let separator = Color(UIColor.separator)
}
