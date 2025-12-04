//
//  MockXXDK.swift
//  iOSExample
//
//  Created by Om More on 24/09/25.
//

import Kronos
import Bindings
import SwiftData
import SwiftUI
import Foundation
public class XXDKMock: XXDKP {
    @Published var status: String = "Initiating";
    @Published var statusPercentage: Double = 0;
    public func setModelContainer(mActor: SwiftDataActor, sm: SecretManager) {
        // Retain container and inject into receivers/callbacks
    
        self.dmReceiver.modelActor = mActor
        self.channelUICallbacks.configure(modelActor: mActor)
        self.eventModelBuilder = EventModelBuilder(model: EventModel())
        self.eventModelBuilder?.configure(modelActor: mActor)
    }
    
    func sendDM(msg: String, toPubKey: Data, partnerToken: Int32) {
        
    }
    func sendDM(msg: String, channelId: String) {
        // Mock channel send: no-op
    }
    func sendReply(msg: String, channelId: String, replyToMessageIdB64: String) {
        // Mock channel reply: no-op
    }
    func sendReply(msg: String, toPubKey: Data, partnerToken: Int32, replyToMessageIdB64: String) {
        // Mock DM reply: no-op
    }
    var codename: String? = "Manny"
    var codeset: Int = 0
    
    func joinChannelFromURL(_ url: String) async throws -> ChannelJSON {
        // Mock: simulate URL decode and join
        return try await joinChannel(url) // For mock, treat URL as prettyPrint
    }
    
    func joinChannel(_ prettyPrint: String) async throws -> ChannelJSON {
        // Mock: return sample joined channel data after a short delay
        try await Task.sleep(for: .seconds(1))
        return ChannelJSON(
            receptionId: "mock-reception-id",
            channelId: "mock-channel-id-\(UUID().uuidString)",
            name: "Mock Joined Channel",
            description: "This is a mock joined channel"
        )
    }
    
    func getChannelPrivacyLevel(url: String) throws -> PrivacyLevel {
        // Mock: return public by default
        return .publicChannel
    }
    
    func getChannelFromURL(url: String) throws -> ChannelJSON {
        // Mock: return sample channel data
        return ChannelJSON(
            receptionId: "mock-reception-id",
            channelId: "mock-channel-id",
            name: "Mock Channel",
            description: "This is a mock channel for testing"
        )
    }
    
    func decodePrivateURL(url: String, password: String) throws -> String {
        // Mock: return the URL as prettyPrint
        return url
    }
    
    func getPrivateChannelFromURL(url: String, password: String) throws -> ChannelJSON {
        // Mock: return sample private channel data
        return ChannelJSON(
            receptionId: "mock-reception-id",
            channelId: "mock-private-channel-id",
            name: "Mock Private Channel",
            description: "This is a mock private channel for testing"
        )
    }
    
    func enableDirectMessages(channelId: String) throws {
        // Mock: no-op
        print("Mock: Enabled direct messages for channel: \(channelId)")
    }
    
    func disableDirectMessages(channelId: String) throws {
        // Mock: no-op
        print("Mock: Disabled direct messages for channel: \(channelId)")
    }
    
    func areDMsEnabled(channelId: String) throws -> Bool {
        // Mock: return true by default
        return true
    }
    
    func leaveChannel(channelId: String) throws {
        // Mock: no-op
        print("Mock: Left channel: \(channelId)")
    }
    
    func getShareURL(channelId: String, host: String) throws -> String? {
        // Mock: return a mock share URL
        return "\(host)?channelId=\(channelId)"
    }
    
    func createChannel(name: String, description: String, privacyLevel: PrivacyLevel, enableDms: Bool) async throws -> ChannelJSON {
        // Mock: simulate channel creation
        try await Task.sleep(for: .seconds(1))
        let channelId = "mock-channel-\(UUID().uuidString)"
        print("Mock: Created channel: \(name)")
        return ChannelJSON(
            receptionId: "mock-reception-id",
            channelId: channelId,
            name: name,
            description: description
        )
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
    
    func load(privateIdentity _privateIdentity: Data?) async {
        do {
            print("starting wait")
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
                print("wait done")
            }
            
        } catch {
            fatalError("error in load fake sleep: \(error)")
        }
        
    }
    var cmix: Bindings.BindingsCmix?
    var channelsManager: Bindings.BindingsChannelsManager?
    var eventModelBuilder: EventModelBuilder?
    var remoteKV: Bindings.BindingsRemoteKV?
    var storageTagListener: RemoteKVKeyChangeListener?
    private var modelContainer: ModelContainer?
    private let channelUICallbacks: ChannelUICallbacks

    init() {
        self.channelUICallbacks = ChannelUICallbacks()
    }

    var ndf: Data?
    var DM: Bindings.BindingsDMClient?
    var dmReceiver: DMReceiver = DMReceiver()

    /// Mock implementation of generateIdentities
    /// - Parameter amountOfIdentities: Number of identities to generate
    /// - Returns: Array of mock GeneratedIdentity objects
    func generateIdentities(amountOfIdentities: Int) -> [GeneratedIdentity] {
        var identities: [GeneratedIdentity] = []

        for i in 0..<amountOfIdentities {
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
    
    func isChannelAdmin(channelId: String) -> Bool {
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
    
    func logout() async {
        // Mock: reset state
        codename = nil
        codeset = 0
        status = "..."
        statusPercentage = 0
    }
}
