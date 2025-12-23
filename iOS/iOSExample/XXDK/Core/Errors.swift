//
//  Errors.swift
//  iOSExample
//

import Bindings
import Foundation

// MARK: - Modern Swift Error Types

/// Errors related to XXDK operations
enum XXDKError: LocalizedError {
    case cmixNotInitialized
    case channelManagerNotInitialized
    case dmClientNotInitialized
    case fileTransferNotInitialized
    case invalidChannelId
    case channelJsonNil
    case identityConstructionFailed
    case importReturnedNil
    case networkNotReady
    case custom(String)

    var errorDescription: String? {
        switch self {
        case .cmixNotInitialized: return "cMix not initialized"
        case .channelManagerNotInitialized: return "Channel manager not initialized"
        case .dmClientNotInitialized: return "DM Client not initialized"
        case .fileTransferNotInitialized: return "File transfer not initialized"
        case .invalidChannelId: return "Invalid channel ID"
        case .channelJsonNil: return "GetChannelJSON returned nil"
        case .identityConstructionFailed: return "Failed to construct identity"
        case .importReturnedNil: return "Import returned nil"
        case .networkNotReady: return "Network not ready"
        case .custom(let msg): return msg
        }
    }
}

/// Errors related to EventModel operations
enum EventModelError: LocalizedError {
    case modelActorNotAvailable
    case messageNotFound
    case identityConstructionFailed

    var errorDescription: String? {
        switch self {
        case .modelActorNotAvailable: return "modelActor not available"
        case .messageNotFound: return BindingsGetNoMessageErr()
        case .identityConstructionFailed: return "Failed to construct identity"
        }
    }
}

/// Errors related to file transfer operations
enum FileTransferError: LocalizedError {
    case initializationFailed
    case invalidChannelIdFormat
    case notInitialized

    var errorDescription: String? {
        switch self {
        case .initializationFailed: return "Failed to initialize file transfer"
        case .invalidChannelIdFormat: return "Invalid channel ID format"
        case .notInitialized: return "File transfer not initialized"
        }
    }
}

