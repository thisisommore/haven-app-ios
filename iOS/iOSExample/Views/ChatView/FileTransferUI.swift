//
//  FileTransferUI.swift
//  iOSExample
//
//  File transfer UI components for channels
//

import PhotosUI
import SwiftUI

enum FileTransferState: Equatable {
    case idle
    case selecting
    case uploading(progress: Double, fileName: String)
    case sending(fileName: String)
    case completed(fileName: String)
    case failed(error: String)
}

@MainActor
class FileTransferManager: ObservableObject, FtSentProgressCallback {
    @Published var state: FileTransferState = .idle
    @Published var selectedFileData: Data?
    @Published var selectedFileName: String?
    @Published var selectedFileType: String?

    private var currentFileID: Data?
    private var fileLinkJSON: Data?
    private var pendingChannelId: String?
    private var xxdkRef: (any XXDKP)?
    private var fileLinkObserver: NSObjectProtocol?
    private var uploadCompleted: Bool = false
    private var pendingFileLink: Data? // Store file link if received before progress completes

    nonisolated func callback(payload: Data, partTracker _: Any?, error: Error?) {
        Task { @MainActor in
            if let error = error {
                self.state = .failed(error: error.localizedDescription)
                self.cleanupObserver()
                return
            }

            do {
                let progress = try Parser.decodeFtSentProgress(from: payload)
                let progressPercent = progress.total > 0 ? Double(progress.received) / Double(progress.total) : 0

                print("[FT] Progress: \(progress.sent)/\(progress.total) sent, \(progress.received) received, completed: \(progress.completed)")

                if progress.completed {
                    // Upload complete
                    print("[FT] Upload complete!")
                    self.uploadCompleted = true
                    self.state = .uploading(progress: 1.0, fileName: self.selectedFileName ?? "File")

                    // Check if we already received the file link
                    if let fileLink = self.pendingFileLink {
                        print("[FT] Using pending file link...")
                        self.sendFileToChannel(fileLink: fileLink)
                    } else {
                        print("[FT] Waiting for file link notification...")
                    }
                } else {
                    self.state = .uploading(progress: progressPercent, fileName: self.selectedFileName ?? "File")
                }
            } catch {
                print("[FT] Failed to decode progress: \(error)")
            }
        }
    }

    func selectFile(data: Data, name: String, type: String) {
        // Validate file size
        guard data.count <= FileTransferLimits.maxFileSize else {
            state = .failed(error: "File too large. Max size is 250 KB.")
            return
        }

        // Truncate name if needed
        let truncatedName = String(name.prefix(FileTransferLimits.maxFileNameLen))
        let truncatedType = String(type.prefix(FileTransferLimits.maxFileTypeLen))

        selectedFileData = data
        selectedFileName = truncatedName
        selectedFileType = truncatedType
    }

    func uploadAndSend<T: XXDKP>(xxdk: T, channelId: String) {
        print("[FT] uploadAndSend called for channel: \(channelId)")
        guard let fileData = selectedFileData else {
            print("[FT] ERROR: No file selected")
            state = .failed(error: "No file selected")
            return
        }

        print("[FT] File size: \(fileData.count) bytes, name: \(selectedFileName ?? "unknown")")
        state = .uploading(progress: 0, fileName: selectedFileName ?? "File")

        // Store references for when file link arrives
        pendingChannelId = channelId
        xxdkRef = xxdk

        // Listen for file link notification
        fileLinkObserver = NotificationCenter.default.addObserver(
            forName: .fileLinkReceived,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleFileLinkReceived(notification)
        }

        Task {
            do {
                // Initialize file transfer if needed
                print("[FT] Initializing file transfer...")
                try xxdk.initChannelsFileTransfer(paramsJson: nil)
                print("[FT] File transfer initialized")

                // Upload file
                print("[FT] Starting upload...")
                let fileID = try xxdk.uploadFile(
                    fileData: fileData,
                    retry: 2.0,
                    progressCB: self,
                    periodMS: 250
                )
                currentFileID = fileID
                print("[FT] Upload started, fileID: \(fileID.base64EncodedString())")

                // Wait for file link via notification (handled in handleFileLinkReceived)

            } catch {
                print("[FT] ERROR: \(error.localizedDescription)")
                await MainActor.run {
                    self.state = .failed(error: error.localizedDescription)
                    self.cleanupObserver()
                }
            }
        }
    }

    private func handleFileLinkReceived(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let fileID = userInfo["fileID"] as? Data,
              let fileLink = userInfo["fileLink"] as? Data
        else {
            print("[FT] Invalid file link notification")
            return
        }

        let status = userInfo["status"] as? Int ?? -1

        // Check if this is for our current upload
        guard let currentID = currentFileID,
              fileID == currentID
        else {
            print("[FT] File link for different file, ignoring")
            return
        }

        print("[FT] Received file link for our upload, status: \(status), uploadCompleted: \(uploadCompleted)")

        // If upload already complete, send now
        if uploadCompleted {
            sendFileToChannel(fileLink: fileLink)
        } else {
            // Store for when upload completes
            print("[FT] Storing file link, waiting for upload to complete...")
            pendingFileLink = fileLink
        }
    }

    private func sendFileToChannel(fileLink: Data) {
        guard let channelId = pendingChannelId,
              let xxdk = xxdkRef,
              let fileName = selectedFileName,
              let fileType = selectedFileType
        else {
            print("[FT] Missing data for send")
            state = .failed(error: "Missing channel or file info")
            cleanupObserver()
            return
        }

        print("[FT] Sending file to channel: \(channelId)")
        state = .sending(fileName: fileName)

        Task {
            do {
                let report = try xxdk.sendFile(
                    channelId: channelId,
                    fileLinkJSON: fileLink,
                    fileName: fileName,
                    fileType: fileType,
                    preview: nil,
                    validUntilMS: 0
                )
                print("[FT] File sent successfully, messageID: \(report.messageID?.base64EncodedString() ?? "nil")")

                await MainActor.run {
                    self.state = .completed(fileName: fileName)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.reset()
                    }
                }
            } catch {
                print("[FT] ERROR sending file: \(error.localizedDescription)")
                await MainActor.run {
                    self.state = .failed(error: error.localizedDescription)
                }
            }

            cleanupObserver()
        }
    }

    private func cleanupObserver() {
        if let observer = fileLinkObserver {
            NotificationCenter.default.removeObserver(observer)
            fileLinkObserver = nil
        }
        pendingChannelId = nil
        xxdkRef = nil
    }

    func reset() {
        state = .idle
        selectedFileData = nil
        selectedFileName = nil
        selectedFileType = nil
        currentFileID = nil
        fileLinkJSON = nil
        uploadCompleted = false
        pendingFileLink = nil
        cleanupObserver()
    }

    func cancel<T: XXDKP>(xxdk: T) {
        if let fileID = currentFileID {
            try? xxdk.closeFileSend(fileIDBytes: fileID)
        }
        reset()
    }
}

struct FileAttachmentButton: View {
    @Binding var showFilePicker: Bool

    var body: some View {
        Button {
            showFilePicker = true
        } label: {
            Image(systemName: "paperclip")
                .font(.system(size: 22))
                .foregroundStyle(.messageText.opacity(0.2))
                .padding(6)
        }
    }
}

struct UploadProgressOverlay: View {
    let state: FileTransferState
    let onCancel: () -> Void

    var body: some View {
        switch state {
        case let .uploading(progress, fileName):
            uploadingView(progress: progress, fileName: fileName)
        case let .sending(fileName):
            sendingView(fileName: fileName)
        case let .completed(fileName):
            completedView(fileName: fileName)
        case let .failed(error):
            failedView(error: error)
        default:
            EmptyView()
        }
    }

    private func uploadingView(progress: Double, fileName: String) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "doc.fill")
                    .foregroundStyle(.haven)
                Text(fileName)
                    .lineLimit(1)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }

            ProgressView(value: progress)
                .tint(.haven)

            Text("Uploading... \(Int(progress * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func sendingView(fileName: String) -> some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Sending \(fileName)...")
                .font(.subheadline)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func completedView(fileName: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("\(fileName) sent!")
                .font(.subheadline.weight(.medium))
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .transition(.scale.combined(with: .opacity))
    }

    private func failedView(error: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            VStack(alignment: .leading, spacing: 2) {
                Text("Upload failed")
                    .font(.subheadline.weight(.medium))
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Dismiss") {
                onCancel()
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.haven)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

struct SelectedFilePreview: View {
    let fileName: String
    let fileSize: Int
    let onRemove: () -> Void

    private var formattedSize: String {
        if fileSize < 1024 {
            return "\(fileSize) B"
        } else if fileSize < 1024 * 1024 {
            return String(format: "%.1f KB", Double(fileSize) / 1024)
        } else {
            return String(format: "%.1f MB", Double(fileSize) / (1024 * 1024))
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.fill")
                .font(.title2)
                .foregroundStyle(.haven)

            VStack(alignment: .leading, spacing: 2) {
                Text(fileName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(formattedSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
    }
}

struct FilePickerSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject var manager: FileTransferManager
    @State private var selectedItem: PhotosPickerItem?
    @State private var showDocumentPicker = false

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 20)

            // Options row
            HStack(spacing: 32) {
                // Photo option
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    attachmentOption(
                        icon: "photo.fill",
                        title: "Photo",
                        color: .blue
                    )
                }
                .buttonStyle(.plain)

                // File option
                Button {
                    showDocumentPicker = true
                } label: {
                    attachmentOption(
                        icon: "doc.fill",
                        title: "File",
                        color: .haven
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 40)

            // Size limit hint
            Text("Max 250 KB")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 16)
                .padding(.bottom, 8)
        }
        .padding(.bottom, 16)
        .presentationDetents([.height(180)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(24)
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    let fileName = "image_\(Date().timeIntervalSince1970).jpg"
                    manager.selectFile(data: data, name: fileName, type: "jpg")
                    isPresented = false
                }
            }
        }
        .fileImporter(isPresented: $showDocumentPicker, allowedContentTypes: [.data]) { result in
            switch result {
            case let .success(url):
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    if let data = try? Data(contentsOf: url) {
                        let fileName = url.lastPathComponent
                        let fileType = url.pathExtension
                        manager.selectFile(data: data, name: fileName, type: fileType)
                    }
                }
                isPresented = false
            case let .failure(error):
                print("File import failed: \(error)")
            }
        }
    }

    private func attachmentOption(icon: String, title: String, color: Color) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 60, height: 60)

                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(color)
            }

            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
        }
    }
}
