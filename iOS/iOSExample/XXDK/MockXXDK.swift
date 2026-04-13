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

struct MockDirectMessage: DirectMessageP {
  func getPublicKey() -> Data? {
    "mock-dm-pubkey".data
  }

  func send(msg _: String, toPubKey _: Data, partnerToken _: Int32) {}

  func reply(
    msg _: String,
    toPubKey _: Data,
    partnerToken _: Int32,
    replyToMessageIdB64 _: String
  ) {}

  func react(
    emoji _: String,
    toMessageIdB64 _: String,
    toPubKey _: Data,
    partnerToken _: Int32
  ) {}

  func getToken() -> Int64 {
    0
  }

  func getNickname() throws -> String {
    ""
  }

  func setNickname(_: String) throws {}
}

final class MockChannels: ChannelsP {
  let msg: ChannelsMessagingP

  init() {
    self.msg = MockChannelsMessaging()
  }

  func join(url _: String) async throws -> ChannelJSON {
    try await self.join(prettyPrint: "")
  }

  func join(prettyPrint _: String) async throws -> ChannelJSON {
    try await Task.sleep(for: .seconds(1))
    return ChannelJSON(
      ChannelID: "mock-channel-id-\(UUID().uuidString)",
      Name: "Mock Joined Channel",
      Description: "This is a mock joined channel"
    )
  }

  func create(
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

  func leave(channelId _: String) throws {}

  func getShareURL(channelId: String, host: String) throws -> ShareURLJSON {
    return ShareURLJSON(url: "\(host)?channelId=\(channelId)", password: "")
  }

  func getPrivacyLevel(url _: String) throws -> PrivacyLevel {
    // Mock: return public by default
    return .publicChannel
  }

  func getFrom(url _: String) throws -> ChannelJSON {
    return ChannelJSON(
      ChannelID: "mock-channel-id-\(UUID().uuidString)",
      Name: "Mock Joined Channel",
      Description: "This is a mock joined channel"
    )
  }

  func decodePrivateURL(url _: String, password _: String) throws -> String {
    ""
  }

  func getPrivateChannelFrom(url _: String, password _: String) throws -> ChannelJSON {
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

  func isAdmin(channelId _: String) -> Bool {
    true
  }

  func exportAdminKey(channelId _: String, encryptionPassword _: String) throws -> Data {
    Data()
  }

  func importAdminKey(
    channelId _: String, encryptionPassword _: String, privateKey _: String
  ) throws {}

  func getMutedUsers(channelId _: String) throws -> [Data] {
    []
  }

  func muteUser(channelId _: String, pubKey _: Data, mute _: Bool) throws {}

  func isMuted(channelId _: String) -> Bool {
    true
  }

  func getNickname(channelId _: String) throws -> String {
    ""
  }

  func setNickname(channelId _: String, nickname _: String) throws {}
}

final class XXDKMock: XXDKP {
  let channel = MockChannels()
  let dm = MockDirectMessage()

  func importChannelAdminKey(
    channelId _: String, encryptionPassword _: String, privateKey _: String
  ) throws {}

  func deleteMessage(channelId _: String, messageId _: String) {}

  @Published var status: XXDKProgressStatus = .none

  var codename: String? = "Manny"
  var codeset: Int = 0

  func downloadNdf() async -> Data {
    withAnimation {
      self.status = .downloadingNDF
    }
    return Data("mock-ndf".utf8)
  }

  func newCmix(downloadedNdf _: Data) async {
    withAnimation {
      self.status = .settingUpCmix
    }
  }

  func loadCmix() async {
    withAnimation {
      self.status = .loadingCmix
    }
  }

  func startNetworkFollower() async {
    withAnimation {
      self.status = .startingNetworkFollower
    }
  }

  func loadClients(privateIdentity _: Data) async {
    do {
      try await Task.sleep(nanoseconds: 2_000_000_000) // Reduced to 2 seconds for testing
      withAnimation {
        self.status = .joiningChannels
      }

      try await Task.sleep(nanoseconds: 2_000_000_000) // Reduced to 2 seconds for testing
      withAnimation {
        self.status = .settingUpRemoteKV
      }

      try await Task.sleep(nanoseconds: 2_000_000_000) // Reduced to 2 seconds for testing
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
    self.status = .none
  }
}
