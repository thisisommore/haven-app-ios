//
//  Channel.swift
//  iOSExample
//

import Bindings
import Foundation
import SQLiteData

protocol ChannelsP {
  var msg: ChannelsMessagingP { get }
  func joinChannelFromURL(_ url: String) async throws -> ChannelJSON
  func joinChannel(_ prettyPrint: String) async throws -> ChannelJSON
  func createChannel(
    name: String,
    description: String,
    privacyLevel: PrivacyLevel,
    enableDms: Bool
  ) async throws -> ChannelJSON
  func leaveChannel(channelId: String) throws
  func getShareURL(channelId: String, host: String) throws -> ShareURLJSON
  func getChannelPrivacyLevel(url: String) throws -> PrivacyLevel
  func getChannelFromURL(url: String) throws -> ChannelJSON
  func decodePrivateURL(url: String, password: String) throws -> String
  func getPrivateChannelFromURL(url: String, password: String) throws -> ChannelJSON
  func enableDirectMessages(channelId: String) throws
  func disableDirectMessages(channelId: String) throws
  func areDMsEnabled(channelId: String) throws -> Bool
  func isChannelAdmin(channelId: String) -> Bool
  func exportChannelAdminKey(channelId: String, encryptionPassword: String) throws -> String
  func importChannelAdminKey(channelId: String, encryptionPassword: String, privateKey: String)
    throws
  func getMutedUsers(channelId: String) throws -> [Data]
  func muteUser(channelId: String, pubKey: Data, mute: Bool) throws
  func isMuted(channelId: String) -> Bool
  func getChannelNickname(channelId: String) throws -> String
  func setChannelNickname(channelId: String, nickname: String) throws
}

class Channel: ChannelsP {
  @Dependency(\.defaultDatabase) private var database
  private let channelsManager: BindingsChannelsManagerWrapper?
  private let cmixId: Int
  let msg: ChannelsMessagingP
  init(channelsManager: BindingsChannelsManagerWrapper, cmixId: Int) {
    self.channelsManager = channelsManager
    self.cmixId = cmixId
    self.msg = ChannelsMessaging(channelsManager: channelsManager)
  }

  /// Join a channel using a URL (public share link)
  func joinChannelFromURL(_ url: String) async throws -> ChannelJSON {
    let prettyPrint = try BindingsStatic.decodePublicURL(url)
    return try await self.joinChannel(prettyPrint)
  }

  /// Join a channel using pretty print format
  func joinChannel(_ prettyPrint: String) async throws -> ChannelJSON {
    // channelsManager can be nil
    if let channelsManager {
      guard let channel = try channelsManager.joinChannel(prettyPrint)
      else {
        throw XXDKError.channelJsonNil
      }
      return channel
    } else {
      throw XXDKError.channelManagerNotInitialized
    }
  }

  /// Create a new channel
  func createChannel(
    name: String,
    description: String,
    privacyLevel: PrivacyLevel,
    enableDms: Bool = true
  ) async throws -> ChannelJSON {
    guard let channelsManager
    else {
      throw XXDKError.channelManagerNotInitialized
    }

    let prettyPrint = try channelsManager.generateChannel(
      name: name,
      description: description,
      privacyLevel: privacyLevel.rawValue
    )

    let channel = try await joinChannel(prettyPrint)

    guard let channelId = channel.ChannelID
    else {
      throw XXDKError.channelIdNotFound
    }

    if enableDms {
      try self.enableDirectMessages(channelId: channelId)
    } else {
      try self.disableDirectMessages(channelId: channelId)
    }

    return channel
  }

  /// Leave a channel
  func leaveChannel(channelId: String) throws {
    guard let channelsManager
    else {
      throw XXDKError.channelManagerNotInitialized
    }

    let channelIdData =
      Data(base64Encoded: channelId) ?? channelId.data

    do {
      try channelsManager.leaveChannel(channelIdData)
    } catch {
      fatalError("failed to leave channel \(error)")
    }
  }

  /// Get the share URL for a channel
  func getShareURL(channelId: String, host: String) throws -> ShareURLJSON {
    guard let channelsManager
    else {
      throw XXDKError.channelManagerNotInitialized
    }

    let channelIdData =
      Data(base64Encoded: channelId) ?? channelId.data

    guard
      let shareURL = try channelsManager.getShareURL(
        cmixId, host: host, maxUses: 0, channelIdBytes: channelIdData
      )
    else {
      throw XXDKError.channelJsonNil
    }
    return shareURL
  }

  /// Get the privacy level for a given channel URL
  func getChannelPrivacyLevel(url: String) throws -> PrivacyLevel {
    let typeValue = try BindingsStatic.getShareUrlType(url)
    return typeValue == 2 ? .secret : .publicChannel
  }

  /// Get channel data from a channel URL
  func getChannelFromURL(url: String) throws -> ChannelJSON {
    let prettyPrint = try BindingsStatic.decodePublicURL(url)
    guard let channel = try BindingsStatic.getChannelJSON(prettyPrint)
    else {
      throw XXDKError.channelJsonNil
    }
    return channel
  }

  /// Decode a private channel URL with password
  func decodePrivateURL(url: String, password: String) throws -> String {
    try BindingsStatic.decodePrivateURL(url: url, password: password)
  }

  /// Get channel data from a private channel URL with password
  func getPrivateChannelFromURL(url: String, password: String) throws -> ChannelJSON {
    let prettyPrint = try decodePrivateURL(url: url, password: password)
    guard let channel = try BindingsStatic.getChannelJSON(prettyPrint)
    else {
      throw XXDKError.channelJsonNil
    }
    return channel
  }

  /// Enable direct messages for a channel
  func enableDirectMessages(channelId: String) throws {
    guard let channelsManager
    else {
      throw XXDKError.channelManagerNotInitialized
    }

    let channelIdData =
      Data(base64Encoded: channelId) ?? channelId.data

    do {
      try channelsManager.enableDirectMessages(channelIdData)
    } catch {
      fatalError("failed to enable direct messages \(error)")
    }
  }

  /// Disable direct messages for a channel
  func disableDirectMessages(channelId: String) throws {
    guard let channelsManager
    else {
      throw XXDKError.channelManagerNotInitialized
    }

    let channelIdData =
      Data(base64Encoded: channelId) ?? channelId.data

    do {
      try channelsManager.disableDirectMessages(channelIdData)
    } catch {
      fatalError("failed to disable direct messages \(error)")
    }
  }

  /// Check if direct messages are enabled for a channel
  func areDMsEnabled(channelId: String) throws -> Bool {
    guard let channelsManager
    else {
      throw XXDKError.channelManagerNotInitialized
    }

    let channelIdData =
      Data(base64Encoded: channelId) ?? channelId.data

    return try channelsManager.areDMsEnabled(channelIdData)
  }

  /// Check if current user is admin of a channel
  func isChannelAdmin(channelId: String) -> Bool {
    guard let channelsManager
    else {
      return false
    }

    let channelIdData = Data(base64Encoded: channelId) ?? channelId.data

    do {
      return try channelsManager.isChannelAdmin(channelIdData)
    } catch {
      AppLogger.channels.error(
        "isChannelAdmin failed: \(error.localizedDescription, privacy: .public)"
      )
      return false
    }
  }

  /// Export the admin key for a channel
  func exportChannelAdminKey(channelId: String, encryptionPassword: String) throws -> String {
    guard let channelsManager
    else {
      throw XXDKError.channelManagerNotInitialized
    }

    guard let channelIdData = Data(base64Encoded: channelId) else {
      throw XXDKError.channelIDIsNotBase64Encoded
    }

    let result = try channelsManager.exportChannelAdminKey(
      channelIdData, encryptionPassword: encryptionPassword
    )
    return try result.utf8()
  }

  /// Import an admin key for a channel
  func importChannelAdminKey(channelId: String, encryptionPassword: String, privateKey: String)
    throws {
    guard let channelsManager
    else {
      throw XXDKError.channelManagerNotInitialized
    }

    let channelIdData = Data(base64Encoded: channelId) ?? channelId.data
    let privateKeyData = privateKey.data

    try channelsManager.importChannelAdminKey(
      channelIdData, encryptionPassword: encryptionPassword, encryptedPrivKey: privateKeyData
    )
  }

  /// Get muted users for a channel
  func getMutedUsers(channelId: String) throws -> [Data] {
    guard let channelsManager
    else {
      throw XXDKError.channelManagerNotInitialized
    }

    let channelIdData = Data(base64Encoded: channelId) ?? channelId.data

    let resultData = try channelsManager.getMutedUsers(channelIdData)

    guard let jsonArray = try? JSONSerialization.jsonObject(with: resultData) as? [String]
    else {
      return []
    }

    return jsonArray.compactMap { Data(base64Encoded: $0) }
  }

  /// Mute or unmute a user in a channel
  func muteUser(channelId: String, pubKey: Data, mute: Bool) throws {
    guard let channelsManager
    else {
      throw XXDKError.channelManagerNotInitialized
    }

    let channelIdData = Data(base64Encoded: channelId) ?? channelId.data

    try channelsManager.muteUser(
      channelIdData, mutedUserPubKeyBytes: pubKey, undoAction: !mute,
      validUntilMS: Int(Bindings.BindingsValidForeverBindings), cmixParamsJSON: "".data
    )
  }

  /// Check if current user is muted in a channel
  func isMuted(channelId: String) -> Bool {
    guard let channelsManager
    else {
      return false
    }

    let channelIdData = Data(base64Encoded: channelId) ?? channelId.data

    do {
      return try channelsManager.muted(channelIdData)
    } catch {
      AppLogger.channels.error("isMuted failed: \(error.localizedDescription, privacy: .public)")
      return false
    }
  }

  func getChannelNickname(channelId: String) throws -> String {
    guard let channelsManager
    else {
      throw XXDKError.channelManagerNotInitialized
    }
    guard let channelIdBytes = Data(base64Encoded: channelId)
    else {
      throw XXDKError.invalidChannelId
    }
    return try channelsManager.getNickname(channelIdBytes)
  }

  func setChannelNickname(channelId: String, nickname: String) throws {
    guard let channelsManager
    else {
      throw XXDKError.channelManagerNotInitialized
    }
    guard let channelIdBytes = Data(base64Encoded: channelId)
    else {
      throw XXDKError.invalidChannelId
    }
    try channelsManager.setNickname(nickname, channelIDBytes: channelIdBytes)
  }
}
