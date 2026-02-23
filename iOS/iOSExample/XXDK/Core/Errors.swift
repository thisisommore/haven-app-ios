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
    case channelIdMissing
    case channelIdNotFound
    case dmTokenRequired
    case pubkeyRequired
    case loadNotificationsDummyFailed(String)
    case loadChannelsManagerFailed(String)
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
        case .channelIdMissing: return "Channel ID is missing"
        case .channelIdNotFound: return "ChannelID was not found"
        case .dmTokenRequired: return "dmToken is required to create chat with pubKey"
        case .pubkeyRequired: return "pubkey is required to create chat"
        case let .loadNotificationsDummyFailed(msg): return "could not load notifications dummy: \(msg)"
        case let .loadChannelsManagerFailed(msg): return "could not load channels manager: \(msg)"
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
