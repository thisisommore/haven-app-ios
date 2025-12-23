//
//  AppLogger.swift
//  iOSExample
//
//  Created by Cursor on 23/12/24.
//

import Foundation
import OSLog

/// Centralized logging utility using Apple's unified logging system.
/// Usage: AppLogger.chat.info("Message sent successfully")
enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.haven.app"

    // MARK: - Feature Loggers

    /// Logger for XXDK core operations
    static let xxdk = Logger(subsystem: subsystem, category: "XXDK")

    /// Logger for identity and authentication
    static let identity = Logger(subsystem: subsystem, category: "Identity")

    /// Logger for messaging operations
    static let messaging = Logger(subsystem: subsystem, category: "Messaging")

    /// Logger for channel operations
    static let channels = Logger(subsystem: subsystem, category: "Channels")

    /// Logger for network operations
    static let network = Logger(subsystem: subsystem, category: "Network")

    /// Logger for file transfer operations
    static let fileTransfer = Logger(subsystem: subsystem, category: "FileTransfer")

    /// Logger for storage/persistence operations
    static let storage = Logger(subsystem: subsystem, category: "Storage")

    /// Logger for chat UI operations
    static let chat = Logger(subsystem: subsystem, category: "Chat")

    /// Logger for home/navigation operations
    static let home = Logger(subsystem: subsystem, category: "Home")

    /// Logger for general app operations
    static let app = Logger(subsystem: subsystem, category: "App")
}
