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

// Mirrors the TypeScript decoder mapping { IsReady: boolean, HowClose: number }
struct IsReadyInfoJSON: Decodable {
    let isReady: Bool
    let howClose: Double

    private enum CodingKeys: String, CodingKey {
        case isReady = "IsReady"
        case howClose = "HowClose"
    }

    // Be tolerant of number-like strings or integers for HowClose
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isReady = try container.decode(Bool.self, forKey: .isReady)

        if let d = try? container.decode(Double.self, forKey: .howClose) {
            howClose = d
        } else if let i = try? container.decode(Int.self, forKey: .howClose) {
            howClose = Double(i)
        } else if let s = try? container.decode(String.self, forKey: .howClose),
                  let d = Double(s)
        {
            howClose = d
        } else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [CodingKeys.howClose],
                      debugDescription: "Expected Double/Int/String convertible to Double for HowClose")
            )
        }
    }
}

// identity derived from a private identity blob
// Keys map to: PubKey, Codename, Color, Extension, CodesetVersion
struct IdentityJSON: Codable {
    let pubkey: String
    let codename: String
    let color: String
    let ext: String
    let codeset: Int

    private enum CodingKeys: String, CodingKey {
        case pubkey = "PubKey"
        case codename = "Codename"
        case color = "Color"
        case ext = "Extension"
        case codeset = "CodesetVersion"
    }
}

// Channel info returned by JoinChannel
// Keys map to: ReceptionID, ChannelID, Name, Description
struct ChannelJSON: Decodable, Identifiable {
    let receptionId: String?
    let channelId: String?
    let name: String
    let description: String

    // Identifiable conformance
    var id: String {
        channelId ?? name
    }

    private enum CodingKeys: String, CodingKey {
        case receptionId = "ReceptionID"
        case channelId = "ChannelID"
        case name = "Name"
        case description = "Description"
    }
}

// Channel send report returned by sendText/sendMessage
// Keys map to: messageID ([]byte -> base64 in JSON), ephId (int64), roundsList
struct ChannelSendReportJSON: Decodable {
    let messageID: Data?
    let ephId: Int64?
    let roundsList: [Int64]?

    private enum CodingKeys: String, CodingKey {
        case messageID
        case ephId
        case roundsList
    }

    init(messageID: Data?, ephId: Int64?, roundsList: [Int64]? = nil) {
        self.messageID = messageID
        self.ephId = ephId
        self.roundsList = roundsList
    }
}

// Model message for getMessage responses
// Minimal struct containing only required fields: pubKey and messageID
struct ModelMessageJSON: Codable {
    let pubKey: Data
    let messageID: Data

    private enum CodingKeys: String, CodingKey {
        case pubKey
        case messageID
    }

    init(pubKey: Data, messageID: Data) {
        self.pubKey = pubKey
        self.messageID = messageID
    }
}

// Remote KV entry structure for channels storage tag
// Keys map to: Version (number), Data (string), Timestamp (string)
struct RemoteKVEntry: Codable {
    let Version: Int
    let Data: String
    let Timestamp: String

    private enum CodingKeys: String, CodingKey {
        case Version
        case Data
        case Timestamp
    }

    init(version: Int, data: String, timestamp: String) {
        Version = version
        Data = data
        Timestamp = timestamp
    }
}

// Share URL response from GetShareURL
// Keys map to: url, password
struct ShareURLJSON: Decodable {
    let url: String
    let password: String

    init(url: String, password: String) {
        self.url = url
        self.password = password
    }
}

// Message update info from updateFromUUID callback
struct MessageUpdateInfoJSON: Decodable {
    let messageID: String?
    let messageIDSet: Bool
    let timestamp: Int64?
    let timestampSet: Bool
    let roundID: Int64?
    let roundIDSet: Bool
    let pinned: Bool?
    let pinnedSet: Bool
    let hidden: Bool?
    let hiddenSet: Bool
    let status: Int?
    let statusSet: Bool

    private enum CodingKeys: String, CodingKey {
        case messageID = "MessageID"
        case messageIDSet = "MessageIDSet"
        case timestamp = "Timestamp"
        case timestampSet = "TimestampSet"
        case roundID = "RoundID"
        case roundIDSet = "RoundIDSet"
        case pinned = "Pinned"
        case pinnedSet = "PinnedSet"
        case hidden = "Hidden"
        case hiddenSet = "HiddenSet"
        case status = "Status"
        case statusSet = "StatusSet"
    }
}

// Mirrors the TypeScript CMixParams shape
struct CMixParamsJSON: Codable {
    var Network: NetworkParams
    var CMIX: CMixCoreParams

    init(Network: NetworkParams, CMIX: CMixCoreParams) {
        self.Network = Network
        self.CMIX = CMIX
    }
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
    var BlacklistedNodes: [String: Bool]?
    var Critical: Bool

    init(
        RoundTries: Int,
        Timeout: Int,
        RetryDelay: Int,
        SendTimeout: Int,
        DebugTag: String,
        BlacklistedNodes: [String: Bool]? = nil,
        Critical: Bool
    ) {
        self.RoundTries = RoundTries
        self.Timeout = Timeout
        self.RetryDelay = RetryDelay
        self.SendTimeout = SendTimeout
        self.DebugTag = DebugTag
        self.BlacklistedNodes = BlacklistedNodes
        self.Critical = Critical
    }
}

enum Parser {
    // Shared JSONDecoder for consistency
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        // We use explicit CodingKeys above, so default strategy is fine.
        return d
    }()

    // Shared JSONEncoder for consistency
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        return e
    }()

    static func decodeIsReadyInfo(from data: Data) throws -> IsReadyInfoJSON {
        try decoder.decode(IsReadyInfoJSON.self, from: data)
    }

    static func decodeIdentity(from data: Data) throws -> IdentityJSON {
        try decoder.decode(IdentityJSON.self, from: data)
    }

    static func decodeChannel(from data: Data) throws -> ChannelJSON {
        try decoder.decode(ChannelJSON.self, from: data)
    }

    static func decodeChannelSendReport(from data: Data) throws -> ChannelSendReportJSON {
        try decoder.decode(ChannelSendReportJSON.self, from: data)
    }

    static func decodeString(from data: Data) throws -> String {
        try decoder.decode(String.self, from: data)
    }

    static func encodeIdentity(_ identity: IdentityJSON) throws -> Data {
        try encoder.encode(identity)
    }

    static func encodeModelMessage(_ message: ModelMessageJSON) throws -> Data {
        try encoder.encode(message)
    }

    static func encodeRemoteKVEntry(_ entry: RemoteKVEntry) throws -> Data {
        try encoder.encode(entry)
    }

    static func decodeRemoteKVEntry(from data: Data) throws -> RemoteKVEntry {
        try decoder.decode(RemoteKVEntry.self, from: data)
    }

    static func encodeString(_ entry: String) throws -> Data {
        try encoder.encode(entry)
    }

    static func decodeCMixParams(from data: Data) throws -> CMixParamsJSON {
        try decoder.decode(CMixParamsJSON.self, from: data)
    }

    static func encodeCMixParams(_ params: CMixParamsJSON) throws -> Data {
        try encoder.encode(params)
    }

    static func decodeShareURL(from data: Data) throws -> ShareURLJSON {
        try decoder.decode(ShareURLJSON.self, from: data)
    }

    static func decodeMessageUpdateInfo(from data: Data) throws -> MessageUpdateInfoJSON {
        try decoder.decode(MessageUpdateInfoJSON.self, from: data)
    }
}
