//
//  ChannelOptionsView.swift
//  iOSExample
//
//  Created by Om More
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ChannelOptionsView<T: XXDKP>: View {
    let chat: Chat?
    let onLeaveChannel: () -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var xxdk: T
    @State private var isDMEnabled: Bool = false
    @State private var shareURL: String?
    @State private var showExportKeySheet: Bool = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Channel Name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(chat?.name ?? "Unknown")
                            .font(.body)
                    }
                    
                    if let description = chat?.channelDescription, !description.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(description)
                                .font(.body)
                        }
                    }
                    
                    Toggle("Direct Messages", isOn: $isDMEnabled)
                        .onChange(of: isDMEnabled) { oldValue, newValue in
                            guard let channelId = chat?.id else { return }
                            do {
                                if newValue {
                                    try xxdk.enableDirectMessages(channelId: channelId)
                                } else {
                                    try xxdk.disableDirectMessages(channelId: channelId)
                                }
                            } catch {
                                print("Failed to toggle DM: \(error)")
                                isDMEnabled = oldValue
                            }
                        }
                    
                    if let urlString = shareURL, let url = URL(string: urlString) {
                        ShareLink(item: url) {
                            HStack {
                                Text(verbatim: urlString)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                        .tint(.haven)
                    }
                }
                .onAppear {
                    guard let channelId = chat?.id else { return }
                    do {
                        isDMEnabled = try xxdk.areDMsEnabled(channelId: channelId)
                    } catch {
                        print("Failed to fetch DM status: \(error)")
                        isDMEnabled = false
                    }
                    do {
                        shareURL = try xxdk.getShareURL(channelId: channelId, host: "https://xxnetwork.com/join")
                        print("Share URL: \(shareURL ?? "nil")")
                    } catch {
                        print("Failed to fetch share URL: \(error)")
                    }
                }
                
                // Admin section - only visible for channel admins
                if let channelId = chat?.id, xxdk.isChannelAdmin(channelId: channelId) {
                    Section(header: Text("Admin")) {
                        Button {
                            showExportKeySheet = true
                        } label: {
                            HStack {
                                Image(systemName: "key.fill")
                                    .foregroundColor(.haven)
                                Text("Export Channel Key")
                                Spacer()
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tint(.primary)
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        onLeaveChannel()
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Leave Channel")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Channel Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }.tint(.haven)
                }.hiddenSharedBackground()
            }
            .sheet(isPresented: $showExportKeySheet) {
                ExportChannelKeySheet(
                    channelId: chat?.id ?? "",
                    channelName: chat?.name ?? "Unknown",
                    xxdk: xxdk
                )
            }
        }
    }
}

struct TextFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    
    var text: String
    
    init(text: String) {
        self.text = text
    }
    
    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            text = String(data: data, encoding: .utf8) ?? ""
        } else {
            text = ""
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: text.data(using: .utf8) ?? Data())
    }
}

struct ExportChannelKeySheet<T: XXDKP>: View {
    let channelId: String
    let channelName: String
    let xxdk: T
    @Environment(\.dismiss) private var dismiss
    @State private var showFileExporter = false
    @State private var encryptionPassword = ""
    @State private var document = TextFileDocument(text: "")
    @State private var errorMessage: String?
    @State private var showCopiedToast = false
    
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
                case .success(let url):
                    print("File saved to: \(url)")
                    dismiss()
                case .failure(let error):
                    print("Failed to save file: \(error)")
                    errorMessage = "Failed to save: \(error.localizedDescription)"
                }
            }
            .overlay {
                if showCopiedToast {
                    VStack {
                        Spacer()
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.white)
                            Text("Copied to Clipboard")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(Color.haven)
                        .cornerRadius(25)
                        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
                        .padding(.bottom, 50)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
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
            withAnimation(.spring(response: 0.3)) {
                showCopiedToast = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    showCopiedToast = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    dismiss()
                }
            }
        } catch {
            errorMessage = "Failed to export key: \(error.localizedDescription)"
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Chat.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    let mockChat = Chat(
        channelId: "mock-channel-123",
        name: "General Discussion",
        description: "A channel for general team discussions and announcements",
    )
    container.mainContext.insert(mockChat)
    
    return ChannelOptionsView<XXDKMock>(chat: mockChat) {
        print("Leave channel tapped")
    }
    .modelContainer(container)
    .environmentObject(XXDKMock())
}
