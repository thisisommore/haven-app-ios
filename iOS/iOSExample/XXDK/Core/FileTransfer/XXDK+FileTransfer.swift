//
//  XXDK+FileTransfer.swift
//  iOSExample
//

import Bindings
import Foundation

public extension XXDK {
    /// Initialize channels file transfer
    func initChannelsFileTransfer(paramsJson _: Data? = nil) throws {
        guard channelsFileTransfer != nil else {
            print("[FT] ERROR: File transfer not initialized")
            throw MyError.runtimeError("File transfer not available")
        }
    }

    /// Upload a file
    func uploadFile(
        fileData: Data,
        retry: Float,
        progressCB: FtSentProgressCallback,
        periodMS: Int
    ) throws -> Data {
        guard let ft = channelsFileTransfer else {
            print("[FT] ERROR: File transfer not initialized")
            throw MyError.runtimeError("File transfer not initialized")
        }
        return try ft.upload(fileData: fileData, retry: retry, progressCB: progressCB, periodMS: periodMS)
    }

    /// Send a file to a channel
    func sendFile(
        channelId: String,
        fileLinkJSON: Data,
        fileName: String,
        fileType: String,
        preview: Data?,
        validUntilMS: Int = 0
    ) throws -> ChannelSendReportJSON {
        guard let ft = channelsFileTransfer else {
            throw MyError.runtimeError("File transfer not initialized")
        }

        let cleanChannelId = channelId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let channelIdData = Data(base64Encoded: cleanChannelId) else {
            print("[FT] ERROR: Failed to decode channelId base64: \(cleanChannelId)")
            throw MyError.runtimeError("Invalid channel ID format")
        }

        let reportData = try ft.send(
            channelIdBytes: channelIdData,
            fileLinkJSON: fileLinkJSON,
            fileName: fileName,
            fileType: fileType,
            preview: preview,
            validUntilMS: validUntilMS,
            cmixParamsJSON: nil,
            pingsJSON: nil
        )

        return try Parser.decodeChannelSendReport(from: reportData)
    }

    /// Retry a failed file upload
    func retryFileUpload(
        fileIDBytes: Data,
        progressCB: FtSentProgressCallback,
        periodMS: Int = 500
    ) throws {
        guard let ft = channelsFileTransfer else {
            throw MyError.runtimeError("File transfer not initialized")
        }
        try ft.retryUpload(fileIDBytes: fileIDBytes, progressCB: progressCB, periodMS: periodMS)
    }

    /// Close a file send operation
    func closeFileSend(fileIDBytes: Data) throws {
        guard let ft = channelsFileTransfer else {
            throw MyError.runtimeError("File transfer not initialized")
        }
        try ft.closeSend(fileIDBytes: fileIDBytes)
    }

    /// Register a progress callback for file upload
    func registerFileProgressCallback(
        fileIDBytes: Data,
        progressCB: FtSentProgressCallback,
        periodMS: Int = 500
    ) throws {
        guard let ft = channelsFileTransfer else {
            throw MyError.runtimeError("File transfer not initialized")
        }
        try ft.registerSentProgressCallback(fileIDBytes: fileIDBytes, progressCB: progressCB, periodMS: periodMS)
    }

    /// Download a file from a received file message
    func downloadFile(
        fileInfoJSON: Data,
        progressCB: FtReceivedProgressCallback,
        periodMS: Int = 500
    ) throws -> Data {
        guard let ft = channelsFileTransfer else {
            throw MyError.runtimeError("File transfer not initialized")
        }
        return try ft.download(fileInfoJSON: fileInfoJSON, progressCB: progressCB, periodMS: periodMS)
    }

    internal func handleFileDownloadNeeded(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let fileInfoJSON = userInfo["fileInfoJSON"] as? Data,
              let messageId = userInfo["messageId"] as? String
        else {
            return
        }

        Task {
            do {
                let callback = FileDownloadCallback(messageId: messageId)
                _ = try downloadFile(fileInfoJSON: fileInfoJSON, progressCB: callback, periodMS: 500)
            } catch {
                print("[FT] Download failed: \(error.localizedDescription)")
            }
        }
    }
}
