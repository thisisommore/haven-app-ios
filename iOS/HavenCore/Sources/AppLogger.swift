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

  /// Logger for messaging operations
  static let messaging = Logger(subsystem: subsystem, category: "Messaging")

  /// Logger for storage/persistence operations
  static let storage = Logger(subsystem: subsystem, category: "Storage")
}
