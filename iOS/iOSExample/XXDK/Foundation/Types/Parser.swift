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

public enum PrivacyLevel: Int {
    case publicChannel = 0
    case secret = 2
}

// Mirrors the TypeScript decoder mapping { IsReady: boolean, HowClose: number }
public struct IsReadyInfoJSON: Decodable {
    public let isReady: Bool
    public let howClose: Double

    private enum CodingKeys: String, CodingKey {
        case isReady = "IsReady"
        case howClose = "HowClose"
    }

    // Be tolerant of number-like strings or integers for HowClose
    public init(from decoder: Decoder) throws {
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

// Public identity derived from a private identity blob
// Keys map to: PubKey, Codename, Color, Extension, CodesetVersion
public struct IdentityJSON: Codable {
    public let pubkey: String
    public let codename: String
    public let color: String
    public let ext: String
    public let codeset: Int

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
public struct ChannelJSON: Decodable, Identifiable {
    public let receptionId: String?
    public let channelId: String?
    public let name: String
    public let description: String

    // Identifiable conformance
    public var id: String {
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
public struct ChannelSendReportJSON: Decodable {
    public let messageID: Data?
    public let ephId: Int64?
    public let roundsList: [Int64]?

    private enum CodingKeys: String, CodingKey {
        case messageID
        case ephId
        case roundsList
    }

    public init(messageID: Data?, ephId: Int64?, roundsList: [Int64]? = nil) {
        self.messageID = messageID
        self.ephId = ephId
        self.roundsList = roundsList
    }
}

// Model message for getMessage responses
// Minimal struct containing only required fields: pubKey and messageID
public struct ModelMessageJSON: Codable {
    public let pubKey: Data
    public let messageID: Data

    private enum CodingKeys: String, CodingKey {
        case pubKey
        case messageID
    }

    public init(pubKey: Data, messageID: Data) {
        self.pubKey = pubKey
        self.messageID = messageID
    }
}

// Remote KV entry structure for channels storage tag
// Keys map to: Version (number), Data (string), Timestamp (string)
public struct RemoteKVEntry: Codable {
    public let Version: Int
    public let Data: String
    public let Timestamp: String

    private enum CodingKeys: String, CodingKey {
        case Version
        case Data
        case Timestamp
    }

    public init(version: Int, data: String, timestamp: String) {
        Version = version
        Data = data
        Timestamp = timestamp
    }
}

// Share URL response from GetShareURL
// Keys map to: url, password
public struct ShareURLJSON: Decodable {
    public let url: String
    public let password: String

    public init(url: String, password: String) {
        self.url = url
        self.password = password
    }
}

// Message update info from updateFromUUID callback
public struct MessageUpdateInfoJSON: Decodable {
    public let messageID: String?
    public let messageIDSet: Bool
    public let timestamp: Int64?
    public let timestampSet: Bool
    public let roundID: Int64?
    public let roundIDSet: Bool
    public let pinned: Bool?
    public let pinnedSet: Bool
    public let hidden: Bool?
    public let hiddenSet: Bool
    public let status: Int?
    public let statusSet: Bool

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
public struct CMixParamsJSON: Codable {
    public var Network: NetworkParams
    public var CMIX: CMixCoreParams

    public init(Network: NetworkParams, CMIX: CMixCoreParams) {
        self.Network = Network
        self.CMIX = CMIX
    }
}

public struct NetworkParams: Codable {
    public var TrackNetworkPeriod: Int
    public var MaxCheckedRounds: Int
    public var RegNodesBufferLen: Int
    public var NetworkHealthTimeout: Int
    public var ParallelNodeRegistrations: Int
    public var KnownRoundsThreshold: Int
    public var FastPolling: Bool
    public var VerboseRoundTracking: Bool
    public var RealtimeOnly: Bool
    public var ReplayRequests: Bool
    public var EnableImmediateSending: Bool
    public var MaxParallelIdentityTracks: Int
    public var Rounds: RoundsParams
    public var Pickup: PickupParams
    public var Message: MessageParams
    public var Historical: HistoricalParams
}

public struct RoundsParams: Codable {
    public var MaxHistoricalRounds: Int
    public var HistoricalRoundsPeriod: Int
    public var HistoricalRoundsBufferLen: Int
    public var MaxHistoricalRoundsRetries: Int
}

public struct PickupParams: Codable {
    public var NumMessageRetrievalWorkers: Int
    public var LookupRoundsBufferLen: Int
    public var MaxHistoricalRoundsRetries: Int
    public var UncheckRoundPeriod: Int
    public var ForceMessagePickupRetry: Bool
    public var SendTimeout: Int
    public var RealtimeOnly: Bool
    public var ForceHistoricalRounds: Bool
}

public struct MessageParams: Codable {
    public var MessageReceptionBuffLen: Int
    public var MessageReceptionWorkerPoolSize: Int
    public var MaxChecksInProcessMessage: Int
    public var InProcessMessageWait: Int
    public var RealtimeOnly: Bool
}

public struct HistoricalParams: Codable {
    public var MaxHistoricalRounds: Int
    public var HistoricalRoundsPeriod: Int
    public var HistoricalRoundsBufferLen: Int
    public var MaxHistoricalRoundsRetries: Int
}

public struct CMixCoreParams: Codable {
    public var RoundTries: Int
    public var Timeout: Int
    public var RetryDelay: Int
    public var SendTimeout: Int
    public var DebugTag: String
    public var BlacklistedNodes: [String: Bool]?
    public var Critical: Bool

    public init(
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

public enum Parser {
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

    public static func decodeIsReadyInfo(from data: Data) throws -> IsReadyInfoJSON {
        try decoder.decode(IsReadyInfoJSON.self, from: data)
    }

    public static func decodeIdentity(from data: Data) throws -> IdentityJSON {
        try decoder.decode(IdentityJSON.self, from: data)
    }

    public static func decodeChannel(from data: Data) throws -> ChannelJSON {
        try decoder.decode(ChannelJSON.self, from: data)
    }

    public static func decodeChannelSendReport(from data: Data) throws -> ChannelSendReportJSON {
        try decoder.decode(ChannelSendReportJSON.self, from: data)
    }

    public static func decodeString(from data: Data) throws -> String {
        try decoder.decode(String.self, from: data)
    }

    public static func encodeIdentity(_ identity: IdentityJSON) throws -> Data {
        try encoder.encode(identity)
    }

    public static func encodeModelMessage(_ message: ModelMessageJSON) throws -> Data {
        try encoder.encode(message)
    }

    public static func encodeRemoteKVEntry(_ entry: RemoteKVEntry) throws -> Data {
        try encoder.encode(entry)
    }

    public static func decodeRemoteKVEntry(from data: Data) throws -> RemoteKVEntry {
        try decoder.decode(RemoteKVEntry.self, from: data)
    }

    public static func encodeString(_ entry: String) throws -> Data {
        try encoder.encode(entry)
    }

    public static func decodeCMixParams(from data: Data) throws -> CMixParamsJSON {
        try decoder.decode(CMixParamsJSON.self, from: data)
    }

    public static func encodeCMixParams(_ params: CMixParamsJSON) throws -> Data {
        try encoder.encode(params)
    }

    public static func decodeShareURL(from data: Data) throws -> ShareURLJSON {
        try decoder.decode(ShareURLJSON.self, from: data)
    }

    public static func decodeMessageUpdateInfo(from data: Data) throws -> MessageUpdateInfoJSON {
        try decoder.decode(MessageUpdateInfoJSON.self, from: data)
    }

    public static func decodeFtSentProgress(from data: Data) throws -> FtSentProgressJSON {
        try decoder.decode(FtSentProgressJSON.self, from: data)
    }

    public static func decodeFileLink(from data: Data) throws -> FileLinkJSON {
        try decoder.decode(FileLinkJSON.self, from: data)
    }

    public static func decodeFileInfo(from data: Data) throws -> FileInfoJSON {
        try decoder.decode(FileInfoJSON.self, from: data)
    }

    public static func encodeFileTransferParams(_ params: FileTransferParamsJSON) throws -> Data {
        try encoder.encode(params)
    }
}

/// File transfer params for InitChannelsFileTransfer
public struct FileTransferParamsJSON: Codable {
    public var maxThroughput: Int
    public var sendTimeout: Int64
    public var resendWait: Int64
    public var cmix: CMixCoreParams

    private enum CodingKeys: String, CodingKey {
        case maxThroughput = "MaxThroughput"
        case sendTimeout = "SendTimeout"
        case resendWait = "ResendWait"
        case cmix = "Cmix"
    }

    public init(
        maxThroughput: Int = 150_000,
        sendTimeout: Int64 = 500_000_000,
        resendWait: Int64 = 500_000_000,
        cmix: CMixCoreParams = CMixCoreParams.fileTransferDefaults
    ) {
        self.maxThroughput = maxThroughput
        self.sendTimeout = sendTimeout
        self.resendWait = resendWait
        self.cmix = cmix
    }
}

public extension CMixCoreParams {
    /// Default cMix params for file transfer
    static var fileTransferDefaults: CMixCoreParams {
        CMixCoreParams(
            RoundTries: 10,
            Timeout: 30_000_000_000, // 30 seconds in nanoseconds
            RetryDelay: 1_000_000_000, // 1 second in nanoseconds
            SendTimeout: 500_000_000, // 500ms in nanoseconds
            DebugTag: "FT",
            BlacklistedNodes: [:],
            Critical: false
        )
    }
}

/// Progress info passed to FtSentProgressCallback during upload
public struct FtSentProgressJSON: Decodable {
    public let id: String
    public let completed: Bool
    public let sent: Int
    public let received: Int
    public let total: Int

    private enum CodingKeys: String, CodingKey {
        case id
        case completed
        case sent
        case received
        case total
    }
}

/// FileLink stored in event model after upload completes
public struct FileLinkJSON: Codable {
    public let fileID: String
    public let recipientID: String
    public let sentTimestamp: String
    public let key: String
    public let mac: String
    public let size: Int
    public let numParts: Int

    private enum CodingKeys: String, CodingKey {
        case fileID
        case recipientID
        case sentTimestamp
        case key
        case mac
        case size
        case numParts
    }
}

/// FileInfo received by channel members
public struct FileInfoJSON: Decodable {
    public let name: String
    public let type: String
    public let preview: Data?
    public let fileID: String
    public let recipientID: String
    public let sentTimestamp: String
    public let key: [UInt8] // Encryption key as byte array
    public let mac: String
    public let size: Int
    public let numParts: Int
    public let retry: Float?

    private enum CodingKeys: String, CodingKey {
        case name
        case type
        case preview
        case fileID
        case recipientID
        case sentTimestamp
        case key
        case mac
        case size
        case retry
        case numParts
    }
}

/// File part status values
public enum FilePartStatus: Int {
    case unsent = 0
    case sent = 1
    case arrived = 2
    case received = 3
}
