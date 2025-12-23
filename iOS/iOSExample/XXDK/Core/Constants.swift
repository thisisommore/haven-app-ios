//
//  Constants.swift
//  iOSExample
//

import Bindings
import Foundation

// NDF is the configuration file used to connect to the xx network. It
// is a list of known hosts and nodes on the network.
// A new list is downloaded on the first connection to the network
public var MAINNET_URL =
    "https://elixxir-bins.s3.us-west-1.amazonaws.com/ndf/mainnet.json"

let XX_GENERAL_CHAT =
    "<Speakeasy-v3:xxGeneralChat|description:Talking about the xx network|level:Public|created:1674152234202224215|secrets:rb+rK0HsOYcPpTF6KkpuDWxh7scZbj74kVMHuwhgUR0=|RMfN+9pD/JCzPTIzPk+pf0ThKPvI425hye4JqUxi3iA=|368|1|/qE8BEgQQkXC6n0yxeXGQjvyklaRH6Z+Wu8qvbFxiuw=>"

// This resolves to "Resources/mainnet.crt" in the project folder for iOSExample
public var MAINNET_CERT =
    Bundle.main.path(forResource: "mainnet", ofType: "crt")
        ?? "unknown resource path"

enum MyError: Error {
    case runtimeError(String)
}

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
