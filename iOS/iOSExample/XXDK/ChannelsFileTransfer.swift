//
//  ChannelsFileTransfer.swift
//  iOSExample
//
//  Channel File Transfer API implementation
//

import Bindings
import Foundation


private func ftLog(_ message: String) {
    print("[FT] \(message)")
}


public enum FileTransferLimits {
    /// Maximum file size: 250,000 bytes (250 KB)
    public static let maxFileSize: Int = 250_000
    /// Maximum file name length: 48 bytes
    public static let maxFileNameLen: Int = 48
    /// Maximum file type length: 8 bytes
    public static let maxFileTypeLen: Int = 8
    /// Maximum preview size: 297 bytes
    public static let maxPreviewSize: Int = 297
}


/// Wrapper for tracking individual file part status
public class ChFilePartTracker {
    private let tracker: Bindings.BindingsChFilePartTracker?

    init(tracker: Bindings.BindingsChFilePartTracker?) {
        self.tracker = tracker
    }

    public func getPartStatus(partNum: Int) -> FilePartStatus {
        guard let tracker = tracker else { return .unsent }
        let status = tracker.getPartStatus(partNum)
        return FilePartStatus(rawValue: status) ?? .unsent
    }

    public func numParts() -> Int {
        guard let tracker = tracker else { return 0 }
        return tracker.getNumParts()
    }
}


/// Internal wrapper to bridge Swift callback to Bindings protocol for uploads
class FtSentProgressCallbackWrapper: NSObject, BindingsFtSentProgressCallbackProtocol {
    private weak var progressCallback: FtSentProgressCallback?

    init(callback: FtSentProgressCallback) {
        progressCallback = callback
        super.init()
    }

    func callback(_ payload: Data?, fpt: Bindings.BindingsChFilePartTracker?, err: Error?) {
        ftLog("Progress callback - payload: \(payload?.count ?? 0) bytes, error: \(err?.localizedDescription ?? "none")")
        let tracker: Any? = fpt != nil ? ChFilePartTracker(tracker: fpt) : nil
        progressCallback?.callback(payload: payload ?? Data(), partTracker: tracker, error: err)
    }
}

/// Internal wrapper to bridge Swift callback to Bindings protocol for downloads
class FtReceivedProgressCallbackWrapper: NSObject, BindingsFtReceivedProgressCallbackProtocol {
    private weak var progressCallback: FtReceivedProgressCallback?

    init(callback: FtReceivedProgressCallback) {
        progressCallback = callback
        super.init()
    }

    func callback(_ payload: Data?, fpt: Bindings.BindingsChFilePartTracker?, err: Error?) {
        ftLog("Download progress callback - payload: \(payload?.count ?? 0) bytes, error: \(err?.localizedDescription ?? "none")")
        let tracker: Any? = fpt != nil ? ChFilePartTracker(tracker: fpt) : nil
        progressCallback?.callback(payload: payload ?? Data(), fileData: nil, partTracker: tracker, error: err)
    }
}


/// File transfer manager for channels
public class ChannelsFileTransfer {
    private let fileTransfer: Bindings.BindingsChannelsFileTransfer

    private init(fileTransfer: Bindings.BindingsChannelsFileTransfer) {
        self.fileTransfer = fileTransfer
    }


    /// Creates a file transfer manager for channels
    /// - Parameters:
    ///   - e2eID: ID of the E2e object in tracker
    ///   - paramsJson: JSON of Params configuration (optional, uses defaults if nil)
    /// - Returns: ChannelsFileTransfer instance
    /// - Throws: Error if initialization fails
    public static func initialize(e2eID: Int, paramsJson: Data? = nil) throws -> ChannelsFileTransfer {
        ftLog("Initializing with e2eID: \(e2eID)")

        var err: NSError?
        let params = paramsJson ?? {
            let defaultParams = FileTransferParamsJSON()
            ftLog("Using default params")
            return try? Parser.encodeFileTransferParams(defaultParams)
        }()

        ftLog("Params: \(params?.count ?? 0) bytes - \(params?.utf8 ?? "nil")")
        ftLog("Calling BindingsInitChannelsFileTransfer...")

        guard let ft = BindingsInitChannelsFileTransfer(e2eID, params, &err) else {
            ftLog("ERROR: BindingsInitChannelsFileTransfer returned nil")
            ftLog("ERROR details: \(err?.localizedDescription ?? "unknown")")
            throw err ?? NSError(domain: "ChannelsFileTransfer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize file transfer"])
        }

        if let error = err {
            ftLog("ERROR after init: \(error.localizedDescription)")
            throw error
        }

        ftLog("Successfully initialized file transfer")
        return ChannelsFileTransfer(fileTransfer: ft)
    }


    /// Maximum file size in bytes (250 KB)
    public static func maxFileSize() -> Int {
        return FileTransferLimits.maxFileSize
    }

    /// Maximum file name length in bytes
    public static func maxFileNameLen() -> Int {
        return FileTransferLimits.maxFileNameLen
    }

    /// Maximum file type length in bytes
    public static func maxFileTypeLen() -> Int {
        return FileTransferLimits.maxFileTypeLen
    }

    /// Maximum preview size in bytes
    public static func maxPreviewSize() -> Int {
        return FileTransferLimits.maxPreviewSize
    }


    /// Starts uploading the file to a new ID
    /// - Parameters:
    ///   - fileData: File contents (max size: MaxFileSize)
    ///   - retry: Retry multiplier on failure (e.g., 2.0 with 6 parts = 12 total sends)
    ///   - progressCB: Callback for upload progress updates
    ///   - periodMS: Minimum interval (ms) between progress callbacks
    /// - Returns: Marshalled fileTransfer.ID - unique file identifier
    /// - Throws: Error if upload fails to start
    public func upload(fileData: Data, retry: Float, progressCB: FtSentProgressCallback, periodMS: Int) throws -> Data {
        ftLog("Upload starting - size: \(fileData.count) bytes, retry: \(retry), periodMS: \(periodMS)")
        let wrapper = FtSentProgressCallbackWrapper(callback: progressCB)
        let fileID = try fileTransfer.upload(fileData, retry: retry, progressCB: wrapper, periodMS: periodMS)
        ftLog("Upload started - fileID: \(fileID.base64EncodedString())")
        return fileID
    }


    /// Sends the file info to a channel. Call this after upload is complete.
    /// - Parameters:
    ///   - channelIdBytes: Marshalled bytes of channel's id.ID
    ///   - fileLinkJSON: JSON of FileLink from event model
    ///   - fileName: Human-readable file name (max length: MaxFileNameLen)
    ///   - fileType: File type identifier (e.g., "png", "pdf") (max length: MaxFileTypeLen)
    ///   - preview: Preview/thumbnail of file (max size: MaxPreviewSize)
    ///   - validUntilMS: Duration (ms) file is available (use ValidForever for max time)
    ///   - cmixParamsJSON: JSON of CMIXParams (empty uses defaults)
    ///   - pingsJSON: JSON array of Ed25519 public keys to notify
    /// - Returns: JSON of ChannelSendReport
    /// - Throws: Error if send fails
    public func send(
        channelIdBytes: Data,
        fileLinkJSON: Data,
        fileName: String,
        fileType: String,
        preview: Data?,
        validUntilMS: Int,
        cmixParamsJSON: Data?,
        pingsJSON: Data?
    ) throws -> Data {
        return try fileTransfer.send(
            channelIdBytes,
            fileLinkJSON: fileLinkJSON,
            fileName: fileName,
            fileType: fileType,
            preview: preview,
            validUntilMS: validUntilMS,
            cmixParamsJSON: cmixParamsJSON ?? Data(),
            pingsJSON: pingsJSON
        )
    }


    /// Downloads a file from a received file message
    /// - Parameters:
    ///   - fileInfoJSON: JSON of FileInfo from received message (contains fileID, key, mac, etc.)
    ///   - progressCB: Callback for download progress updates
    ///   - periodMS: Minimum interval (ms) between progress callbacks
    /// - Returns: Marshalled fileTransfer.ID
    /// - Throws: Error if download fails to start
    public func download(fileInfoJSON: Data, progressCB: FtReceivedProgressCallback, periodMS: Int) throws -> Data {
        ftLog("Download starting - fileInfoJSON: \(fileInfoJSON.count) bytes, periodMS: \(periodMS)")
        let wrapper = FtReceivedProgressCallbackWrapper(callback: progressCB)
        let fileID = try fileTransfer.download(fileInfoJSON, progressCB: wrapper, periodMS: periodMS)
        ftLog("Download started - fileID: \(fileID.base64EncodedString())")
        return fileID
    }


    /// Retries a failed upload
    /// - Parameters:
    ///   - fileIDBytes: Marshalled file ID
    ///   - progressCB: New progress callback (old ones are defunct)
    ///   - periodMS: Callback period in milliseconds
    /// - Throws: Error if retry fails
    public func retryUpload(fileIDBytes: Data, progressCB: FtSentProgressCallback, periodMS: Int) throws {
        let wrapper = FtSentProgressCallbackWrapper(callback: progressCB)
        try fileTransfer.retryUpload(fileIDBytes, progressCB: wrapper, periodMS: periodMS)
    }

    /// Cleans up after transfer completes or fails
    /// - Parameter fileIDBytes: Marshalled file ID
    /// - Throws: Error if close fails
    public func closeSend(fileIDBytes: Data) throws {
        try fileTransfer.closeSend(fileIDBytes)
    }

    /// Re-registers progress callback (use after client restart)
    /// - Parameters:
    ///   - fileIDBytes: Marshalled file ID
    ///   - progressCB: Progress callback
    ///   - periodMS: Callback period in milliseconds
    /// - Throws: Error if registration fails
    public func registerSentProgressCallback(fileIDBytes: Data, progressCB: FtSentProgressCallback, periodMS: Int) throws {
        let wrapper = FtSentProgressCallbackWrapper(callback: progressCB)
        try fileTransfer.registerSentProgressCallback(fileIDBytes, progressCB: wrapper, periodMS: periodMS)
    }


    /// Get the extension builder ID for channel manager
    public func getExtensionBuilderID() -> Int {
        return fileTransfer.getExtensionBuilderID()
    }
}


public func validForever() -> Int {
    return Int(Bindings.BindingsValidForeverBindings)
}
