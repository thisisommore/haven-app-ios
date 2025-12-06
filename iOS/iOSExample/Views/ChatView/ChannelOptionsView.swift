//
//  ChannelOptionsView.swift
//  iOSExample
//
//  Created by Om More
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct MutedUserRow: View {
    let pubKey: Data
    var onUnmute: (() -> Void)?
    @Query private var senders: [Sender]
    
    init(pubKey: Data, onUnmute: (() -> Void)? = nil) {
        self.pubKey = pubKey
        self.onUnmute = onUnmute
        _senders = Query(filter: #Predicate<Sender> { sender in
            sender.pubkey == pubKey
        })
    }
    
    var body: some View {
        HStack {
            Image(systemName: "speaker.slash.fill")
                .foregroundColor(.secondary)
            if let sender = senders.first {
                Text(sender.codename)
                    .foregroundColor(.primary)
            } else {
                Text(pubKey.base64EncodedString())
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button {
                onUnmute?()
            } label: {
                Text("Unmute")
                    .font(.caption)
                    .foregroundColor(.haven)
            }
            .buttonStyle(.borderless)
        }
    }
}

struct ChannelOptionsView<T: XXDKP>: View {
    let chat: Chat?
    let onLeaveChannel: () -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var xxdk: T
    @State private var isDMEnabled: Bool = false
    @State private var shareURL: String?
    @State private var showExportKeySheet: Bool = false
    @State private var showImportKeySheet: Bool = false
    @State private var showBackgroundPicker: Bool = false
    @State private var toastMessage: String?
    @State private var isAdmin: Bool = false
    @State private var mutedUsers: [Data] = []
    
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
                    refreshAdminStatus()
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
                    do {
                        mutedUsers = try xxdk.getMutedUsers(channelId: channelId)
                    } catch {
                        print("Failed to fetch muted users: \(error)")
                    }
                }
                
                // Admin section - only visible for channel admins
                if let _ = chat?.id, isAdmin {
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
                
                // Muted Users section - only visible for admins
                if let _ = chat?.id, isAdmin {
                    Section(header: Text("Muted Users")) {
                        if mutedUsers.isEmpty {
                            Text("No muted users")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(mutedUsers, id: \.self) { pubKey in
                                MutedUserRow(pubKey: pubKey) {
                                    guard let channelId = chat?.id else { return }
                                    do {
                                        try xxdk.muteUser(channelId: channelId, pubKey: pubKey, mute: false)
                                        mutedUsers = try xxdk.getMutedUsers(channelId: channelId)
                                        withAnimation(.spring(response: 0.3)) {
                                            toastMessage = "User unmuted"
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                            withAnimation {
                                                toastMessage = nil
                                            }
                                        }
                                    } catch {
                                        print("Failed to unmute user: \(error)")
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Import key section - only visible for non-admins
                if let _ = chat?.id, !isAdmin {
                    Section {
                        Button {
                            showImportKeySheet = true
                        } label: {
                            HStack {
                                Image(systemName: "key.fill")
                                    .foregroundColor(.haven)
                                Text("Import Channel Key")
                                Spacer()
                                Image(systemName: "square.and.arrow.down")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tint(.primary)
                    }
                }
                
                // Chat Background section
                Section(header: Text("Appearance")) {
                    Button {
                        showBackgroundPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "paintbrush.fill")
                                .foregroundColor(.haven)
                            Text("Chat Background")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .tint(.primary)
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
                    xxdk: xxdk,
                    onSuccess: { message in
                        withAnimation(.spring(response: 0.3)) {
                            toastMessage = message
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                toastMessage = nil
                            }
                        }
                    }
                )
            }
            .sheet(isPresented: $showImportKeySheet) {
                ImportChannelKeySheet(
                    channelId: chat?.id ?? "",
                    channelName: chat?.name ?? "Unknown",
                    xxdk: xxdk,
                    onSuccess: { message in
                        chat?.isAdmin = true
                        refreshAdminStatus()
                        withAnimation(.spring(response: 0.3)) {
                            toastMessage = message
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                toastMessage = nil
                            }
                        }
                    }
                )
            }
            .sheet(isPresented: $showBackgroundPicker) {
                ChatBackgroundPickerView()
            }
            .overlay {
                if let message = toastMessage {
                    VStack {
                        Spacer()
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.white)
                            Text(message)
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
            .onReceive(NotificationCenter.default.publisher(for: .userMuteStatusChanged)) { notification in
                guard let channelId = chat?.id else { return }
                if let notificationChannelID = notification.userInfo?["channelID"] as? String,
                   notificationChannelID == channelId {
                    do {
                        mutedUsers = try xxdk.getMutedUsers(channelId: channelId)
                    } catch {
                        print("Failed to refresh muted users: \(error)")
                    }
                }
            }
        }
    }
    
    private func refreshAdminStatus() {
        isAdmin = chat?.isAdmin ?? false
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
                case .success(let url):
                    print("File saved to: \(url)")
                    onSuccess("Exported to File")
                    dismiss()
                case .failure(let error):
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
                case .success(let urls):
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
                case .failure(let error):
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
