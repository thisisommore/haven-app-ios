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

// MARK: - Models

public struct IsReadyInfoJSON: Decodable {
  public let IsReady: Bool
  public let HowClose: Double

  private enum CodingKeys: String, CodingKey {
    case IsReady, HowClose
  }

  /// Custom init retained to be tolerant of number-like strings or integers
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.IsReady = try container.decode(Bool.self, forKey: .IsReady)

    if let d = try? container.decode(Double.self, forKey: .HowClose) {
      self.HowClose = d
    } else if let i = try? container.decode(Int.self, forKey: .HowClose) {
      self.HowClose = Double(i)
    } else if let s = try? container.decode(String.self, forKey: .HowClose),
              let d = Double(s) {
      self.HowClose = d
    } else {
      throw DecodingError.dataCorruptedError(
        forKey: .HowClose,
        in: container,
        debugDescription: "Expected Double/Int/String convertible to Double for HowClose"
      )
    }
  }
}

public struct IdentityJSON: Codable {
  public let PubKey: String
  public let Codename: String
  public let Color: String
  public let Extension: String
  public let CodesetVersion: Int

  enum CodingKeys: String, CodingKey {
    case PubKey, Codename, Color, Extension, CodesetVersion
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.PubKey = try container.decode(String.self, forKey: .PubKey)
    self.Codename = try container.decode(String.self, forKey: .Codename)
    self.Color = try container.decode(String.self, forKey: .Color)
    self.Extension = try container.decode(String.self, forKey: .Extension)
    self.CodesetVersion = try container.decode(Int.self, forKey: .CodesetVersion)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(self.PubKey, forKey: .PubKey)
    try container.encode(self.Codename, forKey: .Codename)
    try container.encode(self.Color, forKey: .Color)
    try container.encode(self.Extension, forKey: .Extension)
    try container.encode(self.CodesetVersion, forKey: .CodesetVersion)
  }
}

public struct ChannelJSON: Decodable {
  public let ChannelID: String?
  public let Name: String
  public let Description: String

  enum CodingKeys: String, CodingKey {
    case ChannelID, Name, Description
  }

  #if DEBUG
    public init(ChannelID: String?, Name: String, Description: String) {
      self.ChannelID = ChannelID
      self.Name = Name
      self.Description = Description
    }
  #endif

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.ChannelID = try container.decodeIfPresent(String.self, forKey: .ChannelID)
    self.Name = try container.decode(String.self, forKey: .Name)
    self.Description = try container.decode(String.self, forKey: .Description)
  }
}

public struct RoundsListJSON: Decodable {
  public let Rounds: [UInt64]?

  enum CodingKeys: String, CodingKey {
    case Rounds
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.Rounds = try container.decodeIfPresent([UInt64].self, forKey: .Rounds)
  }
}

public struct ChannelSendReportJSON: Decodable {
  public let messageID: Data?
  public let ephId: Int64?
  public var roundsList: RoundsListJSON?

  enum CodingKeys: String, CodingKey {
    case messageID, ephId, roundsList
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.messageID = try container.decodeIfPresent(Data.self, forKey: .messageID)
    self.ephId = try container.decodeIfPresent(Int64.self, forKey: .ephId)
    self.roundsList = try container.decodeIfPresent(RoundsListJSON.self, forKey: .roundsList)
  }
}

public struct ModelMessageJSON: Codable {
  public let pubKey: Data
  public let messageID: Data

  enum CodingKeys: String, CodingKey {
    case pubKey, messageID
  }

  public init(pubKey: Data, messageID: Data) {
    self.pubKey = pubKey
    self.messageID = messageID
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.pubKey = try container.decode(Data.self, forKey: .pubKey)
    self.messageID = try container.decode(Data.self, forKey: .messageID)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(self.pubKey, forKey: .pubKey)
    try container.encode(self.messageID, forKey: .messageID)
  }
}

public struct RemoteKVEntry: Codable {
  public let Version: Int
  public let Data: String
  public let Timestamp: String

  enum CodingKeys: String, CodingKey {
    case Version, Data, Timestamp
  }

  public init(Version: Int, Data: String, Timestamp: String) {
    self.Version = Version
    self.Data = Data
    self.Timestamp = Timestamp
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.Version = try container.decode(Int.self, forKey: .Version)
    self.Data = try container.decode(String.self, forKey: .Data)
    self.Timestamp = try container.decode(String.self, forKey: .Timestamp)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(self.Version, forKey: .Version)
    try container.encode(self.Data, forKey: .Data)
    try container.encode(self.Timestamp, forKey: .Timestamp)
  }
}

public struct ShareURLJSON: Decodable {
  public let url: String
  public let password: String

  enum CodingKeys: String, CodingKey {
    case url, password
  }

  #if DEBUG
    public init(url: String, password: String) {
      self.url = url
      self.password = password
    }
  #endif

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.url = try container.decode(String.self, forKey: .url)
    self.password = try container.decode(String.self, forKey: .password)
  }
}

public struct MessageUpdateInfoJSON: Decodable {
  public let MessageID: String?
  public let MessageIDSet: Bool
  public let Timestamp: Int64?
  public let TimestampSet: Bool
  public let RoundID: Int64?
  public let RoundIDSet: Bool
  public let Pinned: Bool?
  public let PinnedSet: Bool
  public let Hidden: Bool?
  public let HiddenSet: Bool
  public let Status: Int?
  public let StatusSet: Bool

  enum CodingKeys: String, CodingKey {
    case MessageID, MessageIDSet, Timestamp, TimestampSet, RoundID, RoundIDSet
    case Pinned, PinnedSet, Hidden, HiddenSet, Status, StatusSet
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.MessageID = try container.decodeIfPresent(String.self, forKey: .MessageID)
    self.MessageIDSet = try container.decode(Bool.self, forKey: .MessageIDSet)
    self.Timestamp = try container.decodeIfPresent(Int64.self, forKey: .Timestamp)
    self.TimestampSet = try container.decode(Bool.self, forKey: .TimestampSet)
    self.RoundID = try container.decodeIfPresent(Int64.self, forKey: .RoundID)
    self.RoundIDSet = try container.decode(Bool.self, forKey: .RoundIDSet)
    self.Pinned = try container.decodeIfPresent(Bool.self, forKey: .Pinned)
    self.PinnedSet = try container.decode(Bool.self, forKey: .PinnedSet)
    self.Hidden = try container.decodeIfPresent(Bool.self, forKey: .Hidden)
    self.HiddenSet = try container.decode(Bool.self, forKey: .HiddenSet)
    self.Status = try container.decodeIfPresent(Int.self, forKey: .Status)
    self.StatusSet = try container.decode(Bool.self, forKey: .StatusSet)
  }
}

// MARK: - CMix Params

public struct CMixParamsJSON: Codable {
  public var Network: NetworkParams
  public var CMIX: CMixCoreParams

  enum CodingKeys: String, CodingKey {
    case Network, CMIX
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.Network = try container.decode(NetworkParams.self, forKey: .Network)
    self.CMIX = try container.decode(CMixCoreParams.self, forKey: .CMIX)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(self.Network, forKey: .Network)
    try container.encode(self.CMIX, forKey: .CMIX)
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

  enum CodingKeys: String, CodingKey {
    case TrackNetworkPeriod, MaxCheckedRounds, RegNodesBufferLen, NetworkHealthTimeout
    case ParallelNodeRegistrations, KnownRoundsThreshold, FastPolling, VerboseRoundTracking
    case RealtimeOnly, ReplayRequests, EnableImmediateSending, MaxParallelIdentityTracks
    case Rounds, Pickup, Message, Historical
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.TrackNetworkPeriod = try container.decode(Int.self, forKey: .TrackNetworkPeriod)
    self.MaxCheckedRounds = try container.decode(Int.self, forKey: .MaxCheckedRounds)
    self.RegNodesBufferLen = try container.decode(Int.self, forKey: .RegNodesBufferLen)
    self.NetworkHealthTimeout = try container.decode(Int.self, forKey: .NetworkHealthTimeout)
    self.ParallelNodeRegistrations = try container.decode(Int.self, forKey: .ParallelNodeRegistrations)
    self.KnownRoundsThreshold = try container.decode(Int.self, forKey: .KnownRoundsThreshold)
    self.FastPolling = try container.decode(Bool.self, forKey: .FastPolling)
    self.VerboseRoundTracking = try container.decode(Bool.self, forKey: .VerboseRoundTracking)
    self.RealtimeOnly = try container.decode(Bool.self, forKey: .RealtimeOnly)
    self.ReplayRequests = try container.decode(Bool.self, forKey: .ReplayRequests)
    self.EnableImmediateSending = try container.decode(Bool.self, forKey: .EnableImmediateSending)
    self.MaxParallelIdentityTracks = try container.decode(Int.self, forKey: .MaxParallelIdentityTracks)
    self.Rounds = try container.decode(RoundsParams.self, forKey: .Rounds)
    self.Pickup = try container.decode(PickupParams.self, forKey: .Pickup)
    self.Message = try container.decode(MessageParams.self, forKey: .Message)
    self.Historical = try container.decode(HistoricalParams.self, forKey: .Historical)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(self.TrackNetworkPeriod, forKey: .TrackNetworkPeriod)
    try container.encode(self.MaxCheckedRounds, forKey: .MaxCheckedRounds)
    try container.encode(self.RegNodesBufferLen, forKey: .RegNodesBufferLen)
    try container.encode(self.NetworkHealthTimeout, forKey: .NetworkHealthTimeout)
    try container.encode(self.ParallelNodeRegistrations, forKey: .ParallelNodeRegistrations)
    try container.encode(self.KnownRoundsThreshold, forKey: .KnownRoundsThreshold)
    try container.encode(self.FastPolling, forKey: .FastPolling)
    try container.encode(self.VerboseRoundTracking, forKey: .VerboseRoundTracking)
    try container.encode(self.RealtimeOnly, forKey: .RealtimeOnly)
    try container.encode(self.ReplayRequests, forKey: .ReplayRequests)
    try container.encode(self.EnableImmediateSending, forKey: .EnableImmediateSending)
    try container.encode(self.MaxParallelIdentityTracks, forKey: .MaxParallelIdentityTracks)
    try container.encode(self.Rounds, forKey: .Rounds)
    try container.encode(self.Pickup, forKey: .Pickup)
    try container.encode(self.Message, forKey: .Message)
    try container.encode(self.Historical, forKey: .Historical)
  }
}

public struct RoundsParams: Codable {
  public var MaxHistoricalRounds: Int
  public var HistoricalRoundsPeriod: Int
  public var HistoricalRoundsBufferLen: Int
  public var MaxHistoricalRoundsRetries: Int

  enum CodingKeys: String, CodingKey {
    case MaxHistoricalRounds, HistoricalRoundsPeriod, HistoricalRoundsBufferLen, MaxHistoricalRoundsRetries
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.MaxHistoricalRounds = try container.decode(Int.self, forKey: .MaxHistoricalRounds)
    self.HistoricalRoundsPeriod = try container.decode(Int.self, forKey: .HistoricalRoundsPeriod)
    self.HistoricalRoundsBufferLen = try container.decode(Int.self, forKey: .HistoricalRoundsBufferLen)
    self.MaxHistoricalRoundsRetries = try container.decode(Int.self, forKey: .MaxHistoricalRoundsRetries)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(self.MaxHistoricalRounds, forKey: .MaxHistoricalRounds)
    try container.encode(self.HistoricalRoundsPeriod, forKey: .HistoricalRoundsPeriod)
    try container.encode(self.HistoricalRoundsBufferLen, forKey: .HistoricalRoundsBufferLen)
    try container.encode(self.MaxHistoricalRoundsRetries, forKey: .MaxHistoricalRoundsRetries)
  }
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

  enum CodingKeys: String, CodingKey {
    case NumMessageRetrievalWorkers, LookupRoundsBufferLen, MaxHistoricalRoundsRetries
    case UncheckRoundPeriod, ForceMessagePickupRetry, SendTimeout, RealtimeOnly, ForceHistoricalRounds
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.NumMessageRetrievalWorkers = try container.decode(Int.self, forKey: .NumMessageRetrievalWorkers)
    self.LookupRoundsBufferLen = try container.decode(Int.self, forKey: .LookupRoundsBufferLen)
    self.MaxHistoricalRoundsRetries = try container.decode(Int.self, forKey: .MaxHistoricalRoundsRetries)
    self.UncheckRoundPeriod = try container.decode(Int.self, forKey: .UncheckRoundPeriod)
    self.ForceMessagePickupRetry = try container.decode(Bool.self, forKey: .ForceMessagePickupRetry)
    self.SendTimeout = try container.decode(Int.self, forKey: .SendTimeout)
    self.RealtimeOnly = try container.decode(Bool.self, forKey: .RealtimeOnly)
    self.ForceHistoricalRounds = try container.decode(Bool.self, forKey: .ForceHistoricalRounds)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(self.NumMessageRetrievalWorkers, forKey: .NumMessageRetrievalWorkers)
    try container.encode(self.LookupRoundsBufferLen, forKey: .LookupRoundsBufferLen)
    try container.encode(self.MaxHistoricalRoundsRetries, forKey: .MaxHistoricalRoundsRetries)
    try container.encode(self.UncheckRoundPeriod, forKey: .UncheckRoundPeriod)
    try container.encode(self.ForceMessagePickupRetry, forKey: .ForceMessagePickupRetry)
    try container.encode(self.SendTimeout, forKey: .SendTimeout)
    try container.encode(self.RealtimeOnly, forKey: .RealtimeOnly)
    try container.encode(self.ForceHistoricalRounds, forKey: .ForceHistoricalRounds)
  }
}

public struct MessageParams: Codable {
  public var MessageReceptionBuffLen: Int
  public var MessageReceptionWorkerPoolSize: Int
  public var MaxChecksInProcessMessage: Int
  public var InProcessMessageWait: Int
  public var RealtimeOnly: Bool

  enum CodingKeys: String, CodingKey {
    case MessageReceptionBuffLen, MessageReceptionWorkerPoolSize, MaxChecksInProcessMessage
    case InProcessMessageWait, RealtimeOnly
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.MessageReceptionBuffLen = try container.decode(Int.self, forKey: .MessageReceptionBuffLen)
    self.MessageReceptionWorkerPoolSize = try container.decode(Int.self, forKey: .MessageReceptionWorkerPoolSize)
    self.MaxChecksInProcessMessage = try container.decode(Int.self, forKey: .MaxChecksInProcessMessage)
    self.InProcessMessageWait = try container.decode(Int.self, forKey: .InProcessMessageWait)
    self.RealtimeOnly = try container.decode(Bool.self, forKey: .RealtimeOnly)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(self.MessageReceptionBuffLen, forKey: .MessageReceptionBuffLen)
    try container.encode(self.MessageReceptionWorkerPoolSize, forKey: .MessageReceptionWorkerPoolSize)
    try container.encode(self.MaxChecksInProcessMessage, forKey: .MaxChecksInProcessMessage)
    try container.encode(self.InProcessMessageWait, forKey: .InProcessMessageWait)
    try container.encode(self.RealtimeOnly, forKey: .RealtimeOnly)
  }
}

public struct HistoricalParams: Codable {
  public var MaxHistoricalRounds: Int
  public var HistoricalRoundsPeriod: Int
  public var HistoricalRoundsBufferLen: Int
  public var MaxHistoricalRoundsRetries: Int

  enum CodingKeys: String, CodingKey {
    case MaxHistoricalRounds, HistoricalRoundsPeriod, HistoricalRoundsBufferLen, MaxHistoricalRoundsRetries
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.MaxHistoricalRounds = try container.decode(Int.self, forKey: .MaxHistoricalRounds)
    self.HistoricalRoundsPeriod = try container.decode(Int.self, forKey: .HistoricalRoundsPeriod)
    self.HistoricalRoundsBufferLen = try container.decode(Int.self, forKey: .HistoricalRoundsBufferLen)
    self.MaxHistoricalRoundsRetries = try container.decode(Int.self, forKey: .MaxHistoricalRoundsRetries)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(self.MaxHistoricalRounds, forKey: .MaxHistoricalRounds)
    try container.encode(self.HistoricalRoundsPeriod, forKey: .HistoricalRoundsPeriod)
    try container.encode(self.HistoricalRoundsBufferLen, forKey: .HistoricalRoundsBufferLen)
    try container.encode(self.MaxHistoricalRoundsRetries, forKey: .MaxHistoricalRoundsRetries)
  }
}

public struct CMixCoreParams: Codable {
  public var RoundTries: Int
  public var Timeout: Int
  public var RetryDelay: Int
  public var SendTimeout: Int
  public var DebugTag: String
  public var BlacklistedNodes: [String: Bool]?
  public var Critical: Bool
  public var RpcMinTimeout: Int

  enum CodingKeys: String, CodingKey {
    case RoundTries, Timeout, RetryDelay, SendTimeout, DebugTag, BlacklistedNodes, Critical, RpcMinTimeout
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.RoundTries = try container.decode(Int.self, forKey: .RoundTries)
    self.Timeout = try container.decode(Int.self, forKey: .Timeout)
    self.RetryDelay = try container.decode(Int.self, forKey: .RetryDelay)
    self.SendTimeout = try container.decode(Int.self, forKey: .SendTimeout)
    self.DebugTag = try container.decode(String.self, forKey: .DebugTag)
    self.BlacklistedNodes = try container.decodeIfPresent([String: Bool].self, forKey: .BlacklistedNodes)
    self.Critical = try container.decode(Bool.self, forKey: .Critical)
    self.RpcMinTimeout = try container.decode(Int.self, forKey: .RpcMinTimeout)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(self.RoundTries, forKey: .RoundTries)
    try container.encode(self.Timeout, forKey: .Timeout)
    try container.encode(self.RetryDelay, forKey: .RetryDelay)
    try container.encode(self.SendTimeout, forKey: .SendTimeout)
    try container.encode(self.DebugTag, forKey: .DebugTag)
    try container.encodeIfPresent(self.BlacklistedNodes, forKey: .BlacklistedNodes)
    try container.encode(self.Critical, forKey: .Critical)
    try container.encode(self.RpcMinTimeout, forKey: .RpcMinTimeout)
  }
}

// MARK: - Universal Parser

public enum Parser {
  // Shared JSONDecoder and JSONEncoder for consistency
  private static let decoder = JSONDecoder()
  private static let encoder = JSONEncoder()

  /// Decodes any Decodable object from Data
  public static func decode<T: Decodable>(_: T.Type, from data: Data) throws -> T {
    try self.decoder.decode(T.self, from: data)
  }

  /// Encodes any Encodable object to Data
  public static func encode<T: Encodable>(_ value: T) throws -> Data {
    try self.encoder.encode(value)
  }
}

public struct DmNotificationUpdateJSON: Decodable {
  public let notificationFilter: DmNotificationFilterJSON
  public let changed: [DmNotificationStateJSON]
  public let deleted: [Data]

  enum CodingKeys: String, CodingKey {
    case notificationFilter, changed, deleted
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.notificationFilter = try container.decode(DmNotificationFilterJSON.self, forKey: .notificationFilter)
    self.changed = try container.decode([DmNotificationStateJSON].self, forKey: .changed)
    self.deleted = try container.decode([Data].self, forKey: .deleted)
  }
}

public struct DmNotificationFilterJSON: Decodable {
  public let identifier: Data
  public let myID: Data?
  public let tags: [String]
  public let publicKeys: [String: Data]
  public let allowedTypes: [String: DmEmptyJSONObject]

  enum CodingKeys: String, CodingKey {
    case identifier, myID, tags, publicKeys, allowedTypes
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.identifier = try container.decode(Data.self, forKey: .identifier)
    self.myID = try container.decodeIfPresent(Data.self, forKey: .myID)
    self.tags = try container.decode([String].self, forKey: .tags)
    self.publicKeys = try container.decode([String: Data].self, forKey: .publicKeys)
    self.allowedTypes = try container.decode([String: DmEmptyJSONObject].self, forKey: .allowedTypes)
  }
}

public struct DmNotificationStateJSON: Decodable {
  public let pubKey: Data
  public let level: Int

  enum CodingKeys: String, CodingKey {
    case pubKey, level
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.pubKey = try container.decode(Data.self, forKey: .pubKey)
    self.level = try container.decode(Int.self, forKey: .level)
  }
}

public struct DmBlockedUserJSON: Decodable {
  public let user: Data
  public let blocked: Bool

  enum CodingKeys: String, CodingKey {
    case user, blocked
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.user = try container.decode(Data.self, forKey: .user)
    self.blocked = try container.decode(Bool.self, forKey: .blocked)
  }
}

public struct DmMessageReceivedJSON: Decodable {
  public let uuid: UInt64
  public let pubKey: Data
  public let messageUpdate: Bool
  public let conversationUpdate: Bool

  enum CodingKeys: String, CodingKey {
    case uuid, pubKey, messageUpdate, conversationUpdate
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.uuid = try container.decode(UInt64.self, forKey: .uuid)
    self.pubKey = try container.decode(Data.self, forKey: .pubKey)
    self.messageUpdate = try container.decode(Bool.self, forKey: .messageUpdate)
    self.conversationUpdate = try container.decode(Bool.self, forKey: .conversationUpdate)
  }
}

public struct DmMessageDeletedJSON: Decodable {
  public let messageID: Data

  enum CodingKeys: String, CodingKey {
    case messageID
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.messageID = try container.decode(Data.self, forKey: .messageID)
  }
}

public struct DmEmptyJSONObject: Decodable {
  private enum EmptyKeys: CodingKey {}

  public init(from decoder: Decoder) throws {
    _ = try decoder.container(keyedBy: EmptyKeys.self)
  }
}

public struct DMNotificationReport: Decodable {
  public let partner: Data
  public let type: DMMessageType
}

public enum DMMessageType: Int, Decodable {
  case text = 1
  case reply = 2
  case reaction = 3
  case silent = 4
  case invitation = 5
  case delete = 6
}

public enum ChannelsMessageType: Int, Decodable {
  case text = 1
  case adminText = 2
  case reaction = 3
  case silent = 4
  case invitation = 5
  case delete = 6
  case pinned = 7
  case mute = 8
  case adminReplay = 9
  case fileTransfer = 10
}

public struct ChannelNotificationReport: Decodable {
  public let channel: Data
  public let type: ChannelsMessageType
  public let pingType: ChannelPingType?
}

public enum ChannelPingType: String, Decodable {
  case generic = ""
  case reply = "usrReply"
  case mention = "usrMention"
}
