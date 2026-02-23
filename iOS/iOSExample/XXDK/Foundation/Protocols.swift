//
//  Protocols.swift
//  iOSExample
//
//  Created by Om More on 24/09/25.
//

import Bindings
import Foundation
import Kronos
import SwiftData

protocol XXDKP: ObservableObject, AnyObject {
    var status: String { get }
    var statusPercentage: Double { get }
    var codename: String? { get }
    var codeset: Int { get }
    var DM: BindingsDMClientWrapper? { get set }
    var dmReceiver: DMReceiver { get set }
    var cmix: Bindings.BindingsCmix? { get set }
    func load(privateIdentity _privateIdentity: Data?) async
    func setUpCmix() async
    func startNetworkFollower() async
    func downloadNdf() async
    func generateIdentities(amountOfIdentities: Int) -> [GeneratedIdentity]
    func sendDM(msg: String, toPubKey: Data, partnerToken: Int32)
    func sendDM(msg: String, channelId: String)
    func sendReply(msg: String, channelId: String, replyToMessageIdB64: String)
    func sendReply(msg: String, toPubKey: Data, partnerToken: Int32, replyToMessageIdB64: String)
    func joinChannelFromURL(_ url: String) async throws -> ChannelJSON
    func joinChannel(_ prettyPrint: String) async throws -> ChannelJSON
    func getChannelPrivacyLevel(url: String) throws -> PrivacyLevel
    func getChannelFromURL(url: String) throws -> ChannelJSON
    func decodePrivateURL(url: String, password: String) throws -> String
    func getPrivateChannelFromURL(url: String, password: String) throws -> ChannelJSON
    func enableDirectMessages(channelId: String) throws
    func disableDirectMessages(channelId: String) throws
    func areDMsEnabled(channelId: String) throws -> Bool
    func leaveChannel(channelId: String) throws
    func createChannel(name: String, description: String, privacyLevel: PrivacyLevel, enableDms: Bool) async throws -> ChannelJSON
    func getShareURL(channelId: String, host: String) throws -> ShareURLJSON
    func setModelContainer(mActor: SwiftDataActor, sm: AppStorage)
    func isChannelAdmin(channelId: String) -> Bool
    func exportChannelAdminKey(channelId: String, encryptionPassword: String) throws -> String
    func importChannelAdminKey(channelId: String, encryptionPassword: String, privateKey: String) throws
    func exportIdentity(password: String) throws -> Data
    func importIdentity(password: String, data: Data) throws -> Data
    func deleteMessage(channelId: String, messageId: String)
    func logout() async throws
    func getMutedUsers(channelId: String) throws -> [Data]
    func muteUser(channelId: String, pubKey: Data, mute: Bool) throws
    func isMuted(channelId: String) -> Bool
    // Channel Nickname API
    func getChannelNickname(channelId: String) throws -> String
    func setChannelNickname(channelId: String, nickname: String) throws
    // DM Nickname API (global nickname for all DM conversations)
    func getDMNickname() throws -> String
    func setDMNickname(_ nickname: String) throws
}

// These are common helpers extending the string class which are essential for working with XXDK
extension StringProtocol {
    var data: Data { .init(utf8) }
    var bytes: [UInt8] { .init(utf8) }
}

extension DataProtocol {
    var utf8: String { String(decoding: self, as: UTF8.self) }
}
