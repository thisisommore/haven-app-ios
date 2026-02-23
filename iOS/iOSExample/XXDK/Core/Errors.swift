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
    case invalidChannelId
    case channelJsonNil
    case identityConstructionFailed
    case importReturnedNil
    case networkNotReady
    case appStateDirNotFound
    case custom(String)

    var errorDescription: String? {
        switch self {
        case .cmixNotInitialized: return "cMix not initialized"
        case .channelManagerNotInitialized: return "Channel manager not initialized"
        case .dmClientNotInitialized: return "DM Client not initialized"
        case .invalidChannelId: return "Invalid channel ID"
        case .channelJsonNil: return "GetChannelJSON returned nil"
        case .identityConstructionFailed: return "Failed to construct identity"
        case .importReturnedNil: return "Import returned nil"
        case .networkNotReady: return "Network not ready"
        case .appStateDirNotFound: return "App state directory not found"
        case let .custom(msg): return msg
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
