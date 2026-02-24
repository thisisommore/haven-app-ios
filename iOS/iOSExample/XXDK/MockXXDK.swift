//
//  MockXXDK.swift
//  iOSExample
//
//  Created by Om More on 24/09/25.
//

import Bindings
import Foundation
import Kronos
import SwiftData
import SwiftUI

public class XXDKMock: XXDKP {
    func importChannelAdminKey(channelId _: String, encryptionPassword _: String, privateKey _: String) throws {}

    func deleteMessage(channelId _: String, messageId _: String) {}

    @Published var status: String = "Initiating"
    @Published var statusPercentage: Double = 0
    public func setStates(mActor: SwiftDataActor, appStorage _: AppStorage) {
        // Retain container and inject into receivers/callbacks

        dmReceiver.modelActor = mActor
        channelUICallbacks.configure(modelActor: mActor)
        eventModelBuilder = EventModelBuilder(model: EventModel())
        eventModelBuilder?.configure(modelActor: mActor)
    }

    func sendDM(msg _: String, toPubKey _: Data, partnerToken _: Int32) {}

    func sendDM(msg _: String, channelId _: String) {
        // Mock channel send: no-op
    }

    func sendReply(msg _: String, channelId _: String, replyToMessageIdB64 _: String) {
        // Mock channel reply: no-op
    }

    func sendReply(msg _: String, toPubKey _: Data, partnerToken _: Int32, replyToMessageIdB64 _: String) {
        // Mock DM reply: no-op
    }

    var codename: String? = "Manny"
    var codeset: Int = 0

    func joinChannelFromURL(_ url: String) async throws -> ChannelJSON {
        // Mock: simulate URL decode and join
        return try await joinChannel(url) // For mock, treat URL as prettyPrint
    }

    func joinChannel(_: String) async throws -> ChannelJSON {
        // Mock: return sample joined channel data after a short delay
        try await Task.sleep(for: .seconds(1))
        return ChannelJSON(
            receptionId: "mock-reception-id",
            channelId: "mock-channel-id-\(UUID().uuidString)",
            name: "Mock Joined Channel",
            description: "This is a mock joined channel"
        )
    }

    func getChannelPrivacyLevel(url _: String) throws -> PrivacyLevel {
        // Mock: return public by default
        return .publicChannel
    }

    func getChannelFromURL(url _: String) throws -> ChannelJSON {
        // Mock: return sample channel data
        return ChannelJSON(
            receptionId: "mock-reception-id",
            channelId: "mock-channel-id",
            name: "Mock Channel",
            description: "This is a mock channel for testing"
        )
    }

    func decodePrivateURL(url: String, password _: String) throws -> String {
        // Mock: return the URL as prettyPrint
        return url
    }

    func getPrivateChannelFromURL(url _: String, password _: String) throws -> ChannelJSON {
        // Mock: return sample private channel data
        return ChannelJSON(
            receptionId: "mock-reception-id",
            channelId: "mock-private-channel-id",
            name: "Mock Private Channel",
            description: "This is a mock private channel for testing"
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

    func getShareURL(channelId: String, host: String) throws -> ShareURLJSON {
        // Mock: return a mock share URL
        return ShareURLJSON(url: "\(host)?channelId=\(channelId)", password: "")
    }

    func createChannel(name: String, description: String, privacyLevel _: PrivacyLevel, enableDms _: Bool) async throws -> ChannelJSON {
        // Mock: simulate channel creation
        try await Task.sleep(for: .seconds(1))
        let channelId = "mock-channel-\(UUID().uuidString)"
        return ChannelJSON(
            receptionId: "mock-reception-id",
            channelId: channelId,
            name: name,
            description: description
        )
    }

    func downloadNdf() async {
        // Mock: no-op
    }

    func setUpCmix() async {
        withAnimation {
            statusPercentage = 10
            status = "Setting cmix"
        }
    }

    func startNetworkFollower() async {
        withAnimation {
            statusPercentage = 20
            status = "Starting network follower"
        }
    }

    func load(privateIdentity _: Data?) async {
        do {
            try await Task.sleep(nanoseconds: 2_000_000_000) // Reduced to 2 seconds for testing
            withAnimation {
                statusPercentage = 30
                status = "Connecting to network"
            }

            try await Task.sleep(nanoseconds: 2_000_000_000) // Reduced to 2 seconds for testing
            withAnimation {
                statusPercentage = 40
                status = "Joining xxNetwork channel"
            }

            try await Task.sleep(nanoseconds: 2_000_000_000) // Reduced to 2 seconds for testing
            withAnimation {
                statusPercentage = 60
                status = "Setting up KV"
            }

            try await Task.sleep(nanoseconds: 2_000_000_000) // Reduced to 2 seconds for testing
            withAnimation {
                statusPercentage = 100
            }

        } catch {
            fatalError("error in load fake sleep: \(error)")
        }
    }

    var cmix: Bindings.BindingsCmix?
    var channelsManager: BindingsChannelsManagerWrapper?
    var eventModelBuilder: EventModelBuilder?
    var remoteKV: Bindings.BindingsRemoteKV?
    var storageTagListener: RemoteKVKeyChangeListener?
    private var modelContainer: ModelContainer?
    private let channelUICallbacks: ChannelUICallbacks

    init() {
        channelUICallbacks = ChannelUICallbacks()
    }

    var ndf: Data?
    var DM: BindingsDMClientWrapper?
    var dmReceiver: DMReceiver = .init()

    /// Mock implementation of generateIdentities
    /// - Parameter amountOfIdentities: Number of identities to generate
    /// - Returns: Array of mock GeneratedIdentity objects
    func generateIdentities(amountOfIdentities: Int) -> [GeneratedIdentity] {
        var identities: [GeneratedIdentity] = []

        for i in 0 ..< amountOfIdentities {
            // Generate mock private identity data
            let mockPrivateIdentity = "mock_private_identity_\(i)_\(UUID().uuidString)".data(using: .utf8) ?? Data()

            // Generate mock identity details
            let mockCodename = "MockUser\(i)_\(UUID().uuidString.prefix(8))"
            let mockCodeset = 1
            let mockPubkey = "mock_pubkey_\(i)_\(UUID().uuidString)"

            let mockIdentity = GeneratedIdentity(
                privateIdentity: mockPrivateIdentity,
                codename: mockCodename,
                codeset: mockCodeset,
                pubkey: mockPubkey
            )

            identities.append(mockIdentity)
        }

        return identities
    }

    func isChannelAdmin(channelId _: String) -> Bool {
        // Mock: return true for testing
        return true
    }

    func exportChannelAdminKey(channelId: String, encryptionPassword: String) throws -> String {
        // Mock: return a mock encrypted admin key
        return "mock-encrypted-admin-key-\(channelId)-\(encryptionPassword.hashValue)"
    }

    func exportIdentity(password: String) throws -> Data {
        // Mock: return mock encrypted identity data
        return "mock-encrypted-identity-\(password.hashValue)".data(using: .utf8) ?? Data()
    }

    func importIdentity(password _: String, data _: Data) throws -> Data {
        // Mock: return mock private identity data
        return "mock-private-identity".data(using: .utf8) ?? Data()
    }

    func logout() async throws {
        // Mock: reset state
        codename = nil
        codeset = 0
        status = "..."
        statusPercentage = 0
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
