//
//  Parser.swift
//  iOSExample
//
//  Created by Om More on 24/09/25.
//

import Bindings
import Foundation

// This file centralizes JSON models and decode helpers used across the app.
// Add new payload models and decode helpers here to keep parsing consistent.

enum PrivacyLevel: Int {
    case publicChannel = 0
    case secret = 2
}

// MARK: - Models

struct IsReadyInfoJSON: Decodable {
    let IsReady: Bool
    let HowClose: Double

    private enum CodingKeys: String, CodingKey {
        case IsReady, HowClose
    }

    // Custom init retained to be tolerant of number-like strings or integers
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        IsReady = try container.decode(Bool.self, forKey: .IsReady)

        if let d = try? container.decode(Double.self, forKey: .HowClose) {
            HowClose = d
        } else if let i = try? container.decode(Int.self, forKey: .HowClose) {
            HowClose = Double(i)
        } else if let s = try? container.decode(String.self, forKey: .HowClose),
                  let d = Double(s) {
            HowClose = d
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .HowClose,
                in: container,
                debugDescription: "Expected Double/Int/String convertible to Double for HowClose"
            )
        }
    }
}

struct IdentityJSON: Codable {
    let PubKey: String
    let Codename: String
    let Color: String
    let Extension: String
    let CodesetVersion: Int
}

struct ChannelJSON: Decodable {
    let ChannelID: String?
    let Name: String
    let Description: String
}

struct RoundsListJSON: Decodable {
    let Rounds: [UInt64]?
}

struct ChannelSendReportJSON: Decodable {
    let messageID: Data?
    let ephId: Int64?
    var roundsList: RoundsListJSON? = nil
}

struct ModelMessageJSON: Codable {
    let pubKey: Data
    let messageID: Data
}

struct RemoteKVEntry: Codable {
    let Version: Int
    let Data: String
    let Timestamp: String
}

struct ShareURLJSON: Decodable {
    let url: String
    let password: String
}

struct MessageUpdateInfoJSON: Decodable {
    let MessageID: String?
    let MessageIDSet: Bool
    let Timestamp: Int64?
    let TimestampSet: Bool
    let RoundID: Int64?
    let RoundIDSet: Bool
    let Pinned: Bool?
    let PinnedSet: Bool
    let Hidden: Bool?
    let HiddenSet: Bool
    let Status: Int?
    let StatusSet: Bool
}

// MARK: - CMix Params

struct CMixParamsJSON: Codable {
    var Network: NetworkParams
    var CMIX: CMixCoreParams
}

struct NetworkParams: Codable {
    var TrackNetworkPeriod: Int
    var MaxCheckedRounds: Int
    var RegNodesBufferLen: Int
    var NetworkHealthTimeout: Int
    var ParallelNodeRegistrations: Int
    var KnownRoundsThreshold: Int
    var FastPolling: Bool
    var VerboseRoundTracking: Bool
    var RealtimeOnly: Bool
    var ReplayRequests: Bool
    var EnableImmediateSending: Bool
    var MaxParallelIdentityTracks: Int
    var Rounds: RoundsParams
    var Pickup: PickupParams
    var Message: MessageParams
    var Historical: HistoricalParams
}

struct RoundsParams: Codable {
    var MaxHistoricalRounds: Int
    var HistoricalRoundsPeriod: Int
    var HistoricalRoundsBufferLen: Int
    var MaxHistoricalRoundsRetries: Int
}

struct PickupParams: Codable {
    var NumMessageRetrievalWorkers: Int
    var LookupRoundsBufferLen: Int
    var MaxHistoricalRoundsRetries: Int
    var UncheckRoundPeriod: Int
    var ForceMessagePickupRetry: Bool
    var SendTimeout: Int
    var RealtimeOnly: Bool
    var ForceHistoricalRounds: Bool
}

struct MessageParams: Codable {
    var MessageReceptionBuffLen: Int
    var MessageReceptionWorkerPoolSize: Int
    var MaxChecksInProcessMessage: Int
    var InProcessMessageWait: Int
    var RealtimeOnly: Bool
}

struct HistoricalParams: Codable {
    var MaxHistoricalRounds: Int
    var HistoricalRoundsPeriod: Int
    var HistoricalRoundsBufferLen: Int
    var MaxHistoricalRoundsRetries: Int
}

struct CMixCoreParams: Codable {
    var RoundTries: Int
    var Timeout: Int
    var RetryDelay: Int
    var SendTimeout: Int
    var DebugTag: String
    var BlacklistedNodes: [String: Bool]? = nil
    var Critical: Bool
}

// MARK: - Universal Parser

enum Parser {
    // Shared JSONDecoder and JSONEncoder for consistency
    private static let decoder = JSONDecoder()
    private static let encoder = JSONEncoder()

    /// Decodes any Decodable object from Data
    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try decoder.decode(T.self, from: data)
    }

    /// Encodes any Encodable object to Data
    static func encode<T: Encodable>(_ value: T) throws -> Data {
        try encoder.encode(value)
    }
}