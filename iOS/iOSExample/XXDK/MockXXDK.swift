//
//  MockXXDK.swift
//  iOSExample
//
//  Created by Om More on 24/09/25.
//

import Bindings
import Foundation
import Kronos
import SQLiteData
import SwiftUI

private struct MockChannelsMessaging: ChannelsMessagingP {
  func send(msg _: String, channelId _: String) {}
  func reply(msg _: String, channelId _: String, replyToMessageIdB64 _: String) {}
  func react(emoji _: String, toMessageIdB64 _: String, inChannelId _: String) {}
  func delete(channelId _: String, messageId _: String) {}
}

final class MockChannels: ChannelsP {
  let msg: ChannelsMessagingP

  init() {
    self.msg = MockChannelsMessaging()
  }

  func joinChannelFromURL(_: String) async throws -> ChannelJSON {
    try await self.joinChannel("")
  }

  func joinChannel(_: String) async throws -> ChannelJSON {
    try await Task.sleep(for: .seconds(1))
    return ChannelJSON(
      ChannelID: "mock-channel-id-\(UUID().uuidString)",
      Name: "Mock Joined Channel",
      Description: "This is a mock joined channel"
    )
  }

  func createChannel(
    name _: String,
    description _: String,
    privacyLevel _: PrivacyLevel,
    enableDms _: Bool
  ) async throws -> ChannelJSON {
    try await Task.sleep(for: .seconds(1))
    return ChannelJSON(
      ChannelID: "mock-channel-id-\(UUID().uuidString)",
      Name: "Mock Joined Channel",
      Description: "This is a mock joined channel"
    )
  }

  func leaveChannel(channelId _: String) throws {}

  func getShareURL(channelId: String, host: String) throws -> ShareURLJSON {
    return ShareURLJSON(url: "\(host)?channelId=\(channelId)", password: "")
  }

  func getChannelPrivacyLevel(url _: String) throws -> PrivacyLevel {
    // Mock: return public by default
    return .publicChannel
  }

  func getChannelFromURL(url _: String) throws -> ChannelJSON {
    return ChannelJSON(
      ChannelID: "mock-channel-id-\(UUID().uuidString)",
      Name: "Mock Joined Channel",
      Description: "This is a mock joined channel"
    )
  }

  func decodePrivateURL(url _: String, password _: String) throws -> String {
    ""
  }

  func getPrivateChannelFromURL(url _: String, password _: String) throws -> ChannelJSON {
    return ChannelJSON(
      ChannelID: "mock-channel-id-\(UUID().uuidString)",
      Name: "Mock Joined Channel",
      Description: "This is a mock joined channel"
    )
  }

  func enableDirectMessages(channelId _: String) throws {}

  func disableDirectMessages(channelId _: String) throws {}

  func areDMsEnabled(channelId _: String) throws -> Bool {
    true
  }

  func isChannelAdmin(channelId _: String) -> Bool {
    true
  }

  func exportChannelAdminKey(channelId _: String, encryptionPassword _: String) throws -> Data {
    Data()
  }

  func importChannelAdminKey(
    channelId _: String, encryptionPassword _: String, privateKey _: String
  ) throws {}

  func getMutedUsers(channelId _: String) throws -> [Data] {
    []
  }

  func muteUser(channelId _: String, pubKey _: Data, mute _: Bool) throws {}

  func isMuted(channelId _: String) -> Bool {
    true
  }

  func getChannelNickname(channelId _: String) throws -> String {
    ""
  }

  func setChannelNickname(channelId _: String, nickname _: String) throws {}
}

final class XXDKMock: XXDKP {
  let channel = MockChannels()

  var dm: DirectMessage?

  func importChannelAdminKey(
    channelId _: String, encryptionPassword _: String, privateKey _: String
  ) throws {}

  func deleteMessage(channelId _: String, messageId _: String) {}

  @Published var status: String = "Initiating"
  @Published var statusPercentage: Double = 0
  func setAppStorage(_: AppStorage) {
    // Retain container and inject into receivers/callbacks
    self.eventModelBuilder = ChannelEventModelBuilder()
  }

  func sendDM(msg _: String, toPubKey _: Data, partnerToken _: Int32) {}

  func sendDM(msg _: String, channelId _: String) {
    // Mock channel send: no-op
  }

  func sendReply(msg _: String, channelId _: String, replyToMessageIdB64 _: String) {
    // Mock channel reply: no-op
  }

  func sendReply(
    msg _: String, toPubKey _: Data, partnerToken _: Int32, replyToMessageIdB64 _: String
  ) {
    // Mock DM reply: no-op
  }

  var codename: String? = "Manny"
  var codeset: Int = 0

  func getChannelFromURL(url _: String) throws -> ChannelJSON {
    // Mock: return sample channel data
    return ChannelJSON(
      ChannelID: "mock-channel-id",
      Name: "Mock Channel",
      Description: "This is a mock channel for testing"
    )
  }

  func decodePrivateURL(url: String, password _: String) throws -> String {
    // Mock: return the URL as prettyPrint
    return url
  }

  func getPrivateChannelFromURL(url _: String, password _: String) throws -> ChannelJSON {
    // Mock: return sample private channel data
    return ChannelJSON(
      ChannelID: "mock-private-channel-id",
      Name: "Mock Private Channel",
      Description: "This is a mock private channel for testing"
    )
  }

  func enableDirectMessages(channelId _: String) throws {
    // Mock: no-op
  }

  func disableDirectMessages(channelId _: String) throws {
    // Mock: no-op
  }

  func areDMsEnabled(channelId _: String) throws -> Bool {
    // Mock: return true by default
    return true
  }

  func leaveChannel(channelId _: String) throws {
    // Mock: no-op
  }

  func createChannel(
    name: String, description: String, privacyLevel _: PrivacyLevel, enableDms _: Bool
  ) async throws -> ChannelJSON {
    // Mock: simulate channel creation
    try await Task.sleep(for: .seconds(1))
    let channelId = "mock-channel-\(UUID().uuidString)"
    return ChannelJSON(
      ChannelID: channelId,
      Name: name,
      Description: description
    )
  }

  func downloadNdf() async -> Data {
    withAnimation {
      self.statusPercentage = 5
      self.status = "Downloading NDF"
    }
    return Data("mock-ndf".utf8)
  }

  func newCmix(downloadedNdf _: Data) async {
    withAnimation {
      self.statusPercentage = 10
      self.status = "Setting cmix"
    }
  }

  func loadCmix() async {
    withAnimation {
      self.statusPercentage = 10
      self.status = "Loading cmix"
    }
  }

  func startNetworkFollower() async {
    withAnimation {
      self.statusPercentage = 20
      self.status = "Starting network follower"
    }
  }

  func loadClients(privateIdentity _: Data) async {
    do {
      try await Task.sleep(nanoseconds: 2_000_000_000) // Reduced to 2 seconds for testing
      withAnimation {
        self.statusPercentage = 30
        self.status = "Connecting to network"
      }

      try await Task.sleep(nanoseconds: 2_000_000_000) // Reduced to 2 seconds for testing
      withAnimation {
        self.statusPercentage = 40
        self.status = "Joining xxNetwork channel"
      }

      try await Task.sleep(nanoseconds: 2_000_000_000) // Reduced to 2 seconds for testing
      withAnimation {
        self.statusPercentage = 60
        self.status = "Setting up KV"
      }

      try await Task.sleep(nanoseconds: 2_000_000_000) // Reduced to 2 seconds for testing
      withAnimation {
        self.statusPercentage = 100
      }
    } catch {
      fatalError("error in load fake sleep: \(error)")
    }
  }

  func setupClients(privateIdentity: Data, successCallback: () -> Void) async {
    await self.loadClients(privateIdentity: privateIdentity)
    successCallback()
  }

  func savePrivateIdentity(privateIdentity _: Data) throws {}

  func loadSavedPrivateIdentity() throws -> Data {
    "mock-private-identity".data
  }

  var cmix: Bindings.BindingsCmix?
  var channelsManager: BindingsChannelsManagerWrapper?
  private var eventModelBuilder: ChannelEventModelBuilder?
  private var remoteKV: Bindings.BindingsRemoteKV?
  private var storageTagListener: RemoteKVKeyChangeListener?
  private let channelUICallbacks: ChannelUICallbacks

  init() {
    self.channelUICallbacks = ChannelUICallbacks()
  }

  private var ndf: Data?
  var DM: BindingsDMClientWrapper?

  /// Mock implementation of generateIdentities
  /// - Parameter amountOfIdentities: Number of identities to generate
  /// - Returns: Array of mock GeneratedIdentity objects
  func generateIdentities(amountOfIdentities: Int) -> [GeneratedIdentity] {
    var identities: [GeneratedIdentity] = []
    for i in 0 ..< amountOfIdentities {
      identities.append(GeneratedIdentity(
        privateIdentity: "mock_private_identity_\(i)_\(UUID().uuidString)".data,
        codename: "MockUser\(i)_\(UUID().uuidString.prefix(8))",
        codeset: 1,
        pubkey: "mock_pubkey_\(i)_\(UUID().uuidString)"
      ))
    }

    return identities
  }

  func isChannelAdmin(channelId _: String) -> Bool {
    // Mock: return true for testing
    return true
  }

  func exportChannelAdminKey(channelId: String, encryptionPassword: String) throws -> Data {
    // Mock: return a mock encrypted admin key
    return "mock-encrypted-admin-key-\(channelId)-\(encryptionPassword.hashValue)".data
  }

  func exportIdentity(password: String) throws -> Data {
    // Mock: return mock encrypted identity data
    return "mock-encrypted-identity-\(password.hashValue)".data
  }

  func importIdentity(password _: String, data _: Data) throws -> Data {
    // Mock: return mock private identity data
    return "mock-private-identity".data
  }

  func logout() async throws {
    // Mock: reset state
    self.codename = nil
    self.codeset = 0
    self.status = "..."
    self.statusPercentage = 0
  }

  func getMutedUsers(channelId _: String) throws -> [Data] {
    // Mock: return empty array
    return []
  }

  func muteUser(channelId _: String, pubKey _: Data, mute _: Bool) throws {
    // Mock: no-op
  }

  func isMuted(channelId _: String) -> Bool {
    // Mock: return false
    return false
  }

  func getChannelNickname(channelId _: String) throws -> String {
    return ""
  }

  func setChannelNickname(channelId _: String, nickname _: String) throws {
    // Mock: do nothing
  }

  func getDMNickname() throws -> String {
    return ""
  }

  func setDMNickname(_: String) throws {
    // Mock: do nothing
  }
}
