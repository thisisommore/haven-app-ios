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
            print("[FT] Download error for \(messageId): \(error.localizedDescription)")
            return
        }

        // Parse progress - file storage is handled automatically by SDK via EventModel.updateFile
        if let progress = try? JSONDecoder().decode(FtReceivedProgress.self, from: payload) {
            print("[FT] Download progress for \(messageId): \(progress.received)/\(progress.total)")
            if progress.completed {
                print("[FT] Download completed for \(messageId)")
            }
        }
    }
}

/// Progress info for file download
struct FtReceivedProgress: Codable {
    let completed: Bool
    let received: Int
    let total: Int
}
