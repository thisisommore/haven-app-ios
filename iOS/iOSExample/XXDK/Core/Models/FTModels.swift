//
//  FTModels.swift
//  iOSExample
//

import Bindings
import Foundation

/// Callback for file download progress (file storage is handled by EventModel.updateFile)
class FileDownloadCallback: FtReceivedProgressCallback {
    private let messageId: String

    init(messageId: String) {
        self.messageId = messageId
    }

    func callback(payload: Data, fileData _: Data?, partTracker _: Any?, error: Error?) {
        if let error = error {
            AppLogger.fileTransfer.error("Download error for \(self.messageId, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return
        }

        // Parse progress - file storage is handled automatically by SDK via EventModel.updateFile
        if let progress = try? JSONDecoder().decode(FtReceivedProgress.self, from: payload) {
            if progress.completed {}
        }
    }
}

/// Progress info for file download
struct FtReceivedProgress: Codable {
    let completed: Bool
    let received: Int
    let total: Int
}
