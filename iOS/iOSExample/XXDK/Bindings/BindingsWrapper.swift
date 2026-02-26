//
//  BindingsWrapper.swift
//  iOSExample
//
//  Swift-style wrappers for C/ObjC bindings that use NSError pointers.
//  Handles error propagation internally so callers can use throws.
//

import Bindings
import Foundation

// MARK: - Static Bindings (no instance required)

enum BindingsStatic {
    // Channel URL / JSON
    static func decodePublicURL(_ url: String) throws -> String {
        var err: NSError?
        let result = Bindings.BindingsDecodePublicURL(url, &err)
        if let err { throw err }
        return result
    }

    static func decodePrivateURL(url: String, password: String) throws -> String {
        var err: NSError?
        let result = Bindings.BindingsDecodePrivateURL(url, password, &err)
        if let err { throw err }
        return result
    }

    static func getChannelJSON(_ prettyPrint: String) throws -> ChannelJSON? {
        var err: NSError?
        let result = Bindings.BindingsGetChannelJSON(prettyPrint, &err)
        if let err { throw err }
        guard let data = result else { return nil }
        return try Parser.decode(ChannelJSON.self, from: data)
    }

    static func getShareUrlType(_ url: String) throws -> Int {
        var err: NSError?
        var typeValue = 0
        Bindings.BindingsGetShareUrlType(url, &typeValue, &err)
        if let err { throw err }
        return typeValue
    }

    // Identity
    static func getPublicChannelIdentityFromPrivate(_ privateIdentity: Data) throws -> IdentityJSON? {
        var err: NSError?
        let result = Bindings.BindingsGetPublicChannelIdentityFromPrivate(privateIdentity, &err)
        if let err { throw err }
        guard let data = result else { return nil }
        return try Parser.decode(IdentityJSON.self, from: data)
    }

    static func constructIdentity(pubKey: Data?, codeset: Int) throws -> IdentityJSON? {
        var err: NSError?
        let result = Bindings.BindingsConstructIdentity(pubKey, codeset, &err)
        if let err { throw err }
        guard let data = result else { return nil }
        return try Parser.decode(IdentityJSON.self, from: data)
    }

    static func generateChannelIdentity(_ cmixId: Int) throws -> Data? {
        var err: NSError?
        let result = Bindings.BindingsGenerateChannelIdentity(cmixId, &err)
        if let err { throw err }
        return result
    }

    static func importPrivateIdentity(password: String, data: Data) throws -> Data? {
        var err: NSError?
        let result = Bindings.BindingsImportPrivateIdentity(password, data, &err)
        if let err { throw err }
        return result
    }

    // Notifications
    static func loadNotifications(_ cmixId: Int) throws -> Bindings.BindingsNotifications? {
        var err: NSError?
        let result = Bindings.BindingsLoadNotifications(cmixId, &err)
        if let err { throw err }
        return result
    }

    static func loadNotificationsDummy(_ cmixId: Int) throws -> Bindings.BindingsNotifications? {
        var err: NSError?
        let result = Bindings.BindingsLoadNotificationsDummy(cmixId, &err)
        if let err { throw err }
        return result
    }

    // DM
    static func newDMClient(
        cmixId: Int,
        notifications: Bindings.BindingsNotifications,
        privateIdentity: Data,
        receiverBuilder: Bindings.BindingsDMReceiverBuilderProtocol,
        dmReceiver: Bindings.BindingsDmCallbacksProtocol
    ) throws -> Bindings.BindingsDMClient? {
        var err: NSError?
        let result = Bindings.BindingsNewDMClient(cmixId, notifications.getID(), privateIdentity, receiverBuilder, dmReceiver, &err)
        if let err { throw err }
        return result
    }

    // ChannelsManager
    static func newChannelsManager(
        cmixId: Int,
        privateIdentity: Data,
        eventModelBuilder: Bindings.BindingsEventModelBuilderProtocol,
        extensionJSON: Data,
        notiId: Int,
        channelUICallbacks: Bindings.BindingsChannelUICallbacksProtocol
    ) throws -> Bindings.BindingsChannelsManager? {
        var err: NSError?
        let result = Bindings.BindingsNewChannelsManager(cmixId, privateIdentity, eventModelBuilder, extensionJSON, notiId, channelUICallbacks, &err)
        if let err { throw err }
        return result
    }

    static func loadChannelsManager(
        cmixId: Int,
        storageTag: String,
        eventModelBuilder: Bindings.BindingsEventModelBuilderProtocol,
        extensionJSON: Data,
        notiId: Int,
        channelUICallbacks: Bindings.BindingsChannelUICallbacksProtocol
    ) throws -> Bindings.BindingsChannelsManager? {
        var err: NSError?
        let result = Bindings.BindingsLoadChannelsManager(cmixId, storageTag, eventModelBuilder, extensionJSON, notiId, channelUICallbacks, &err)
        if let err { throw err }
        return result
    }

    // Cmix
    static func newCmix(ndf: Data, stateDir: String, secret: Data, backup: String) throws {
        var err: NSError?
        Bindings.BindingsNewCmix(ndf.utf8, stateDir, secret, backup, &err)
        if let err { throw err }
    }

    static func loadCmix(stateDir: String, secret: Data, paramsJSON: Data) throws -> Bindings.BindingsCmix? {
        var err: NSError?
        let result = Bindings.BindingsLoadCmix(stateDir, secret, paramsJSON, &err)
        if let err { throw err }
        return result
    }

    static func deleteCmixInstance(_ cmixId: Int) throws {
        var err: NSError?
        Bindings.BindingsDeleteCmixInstance(cmixId, &err)
        if let err { throw err }
    }

    // Network
    static func downloadAndVerifySignedNdf(url: String, cert: String) throws -> Data? {
        var err: NSError?
        let result = Bindings.BindingsDownloadAndVerifySignedNdfWithUrl(url, cert, &err)
        if let err { throw err }
        return result
    }
}

// MARK: - ChannelsManager

final class BindingsChannelsManagerWrapper {
    private let inner: Bindings.BindingsChannelsManager

    init(_ inner: Bindings.BindingsChannelsManager) {
        self.inner = inner
    }

    func generateChannel(name: String, description: String, privacyLevel: Int) throws -> String {
        var err: NSError?
        let result = inner.generateChannel(name, description: description, privacyLevel: privacyLevel, error: &err)
        if let err { throw err }
        return result
    }

    func getNickname(_ channelIdBytes: Data) throws -> String {
        var err: NSError?
        let result = inner.getNickname(channelIdBytes, error: &err)
        if let err { throw err }
        return result
    }

    func areDMsEnabled(_ channelIdData: Data) throws -> Bool {
        var result = ObjCBool(false)
        try inner.areDMsEnabled(channelIdData, ret0_: &result)
        return result.boolValue
    }

    func isChannelAdmin(_ channelIdData: Data) throws -> Bool {
        var result = ObjCBool(false)
        try inner.isChannelAdmin(channelIdData, ret0_: &result)
        return result.boolValue
    }

    func muted(_ channelIdData: Data) throws -> Bool {
        var result = ObjCBool(false)
        try inner.muted(channelIdData, ret0_: &result)
        return result.boolValue
    }

    // Pass-through to inner (already use Swift throws)
    func joinChannel(_ prettyPrint: String) throws -> ChannelJSON? {
        let data = try inner.joinChannel(prettyPrint)
        return try Parser.decode(ChannelJSON.self, from: data)
    }

    func leaveChannel(_ channelIdData: Data) throws { try inner.leaveChannel(channelIdData) }
    func getShareURL(_ cmixId: Int, host: String, maxUses: Int, channelIdBytes: Data) throws -> ShareURLJSON? {
        let data = try inner.getShareURL(cmixId, host: host, maxUses: maxUses, channelIdBytes: channelIdBytes)
        return try Parser.decode(ShareURLJSON.self, from: data)
    }

    func enableDirectMessages(_ channelIdData: Data) throws { try inner.enableDirectMessages(channelIdData) }
    func disableDirectMessages(_ channelIdData: Data) throws { try inner.disableDirectMessages(channelIdData) }
    func exportChannelAdminKey(_ channelIdData: Data, encryptionPassword: String) throws -> Data {
        try inner.exportChannelAdminKey(channelIdData, encryptionPassword: encryptionPassword)
    }

    func importChannelAdminKey(_ channelIdData: Data, encryptionPassword: String, encryptedPrivKey: Data) throws {
        try inner.importChannelAdminKey(channelIdData, encryptionPassword: encryptionPassword, encryptedPrivKey: encryptedPrivKey)
    }

    func getMutedUsers(_ channelIdData: Data) throws -> Data { try inner.getMutedUsers(channelIdData) }
    func muteUser(_ channelIdData: Data, mutedUserPubKeyBytes: Data, undoAction: Bool, validUntilMS: Int, cmixParamsJSON: Data) throws {
        try inner.muteUser(channelIdData, mutedUserPubKeyBytes: mutedUserPubKeyBytes, undoAction: undoAction, validUntilMS: validUntilMS, cmixParamsJSON: cmixParamsJSON)
    }

    func setNickname(_ nickname: String, channelIDBytes: Data) throws {
        try inner.setNickname(nickname, channelIDBytes: channelIDBytes)
    }

    func getStorageTag() -> String { inner.getStorageTag() }
    func sendMessage(_ channelIdData: Data, message: String, validUntilMS: Int64, cmixParamsJSON: Data, pingsJSON: Data?) throws -> ChannelSendReportJSON? {
        let data = try inner.sendMessage(channelIdData, message: message, validUntilMS: validUntilMS, cmixParamsJSON: cmixParamsJSON, pingsJSON: pingsJSON)
        return try Parser.decode(ChannelSendReportJSON.self, from: data)
    }

    func sendReply(_ channelIdData: Data, message: String, messageToReactTo: Data, validUntilMS: Int64, cmixParamsJSON: Data, pingsJSON: Data?) throws -> ChannelSendReportJSON? {
        let data = try inner.sendReply(channelIdData, message: message, messageToReactTo: messageToReactTo, validUntilMS: validUntilMS, cmixParamsJSON: cmixParamsJSON, pingsJSON: pingsJSON)
        return try Parser.decode(ChannelSendReportJSON.self, from: data)
    }

    func sendReaction(_ channelIdData: Data, reaction: String, messageToReactTo: Data, validUntilMS: Int64, cmixParamsJSON: Data) throws -> ChannelSendReportJSON? {
        let data = try inner.sendReaction(channelIdData, reaction: reaction, messageToReactTo: messageToReactTo, validUntilMS: validUntilMS, cmixParamsJSON: cmixParamsJSON)
        return try Parser.decode(ChannelSendReportJSON.self, from: data)
    }

    func deleteMessage(_ channelIdData: Data, targetMessageIdBytes: Data, cmixParamsJSON: Data) throws {
        try inner.deleteMessage(channelIdData, targetMessageIdBytes: targetMessageIdBytes, cmixParamsJSON: cmixParamsJSON)
    }
}

// MARK: - DMClient

final class BindingsDMClientWrapper {
    private let inner: Bindings.BindingsDMClient

    init(_ inner: Bindings.BindingsDMClient) {
        self.inner = inner
    }

    func getNickname() throws -> String {
        var err: NSError?
        let result = inner.getNickname(&err)
        if let err { throw err }
        return result
    }

    func getPublicKey() -> Data? { inner.getPublicKey() }
    func getToken() -> Int64 { inner.getToken() }
    func setNickname(_ nickname: String) throws { try inner.setNickname(nickname) }
    func sendText(_ toPubKey: Data, partnerToken: Int32, message: String, leaseTimeMS: Int64, cmixParamsJSON: Data) throws -> ChannelSendReportJSON? {
        let data = try inner.sendText(toPubKey, partnerToken: partnerToken, message: message, leaseTimeMS: leaseTimeMS, cmixParamsJSON: cmixParamsJSON)
        return try Parser.decode(ChannelSendReportJSON.self, from: data)
    }

    func sendReply(_ toPubKey: Data, partnerToken: Int32, replyMessage: String, replyToBytes: Data, leaseTimeMS: Int64, cmixParamsJSON: Data) throws -> ChannelSendReportJSON? {
        let data = try inner.sendReply(toPubKey, partnerToken: partnerToken, replyMessage: replyMessage, replyToBytes: replyToBytes, leaseTimeMS: leaseTimeMS, cmixParamsJSON: cmixParamsJSON)
        return try Parser.decode(ChannelSendReportJSON.self, from: data)
    }

    func sendReaction(_ toPubKey: Data, partnerToken: Int32, reaction: String, reactToBytes: Data, cmixParamsJSON: Data) throws -> ChannelSendReportJSON? {
        let data = try inner.sendReaction(toPubKey, partnerToken: partnerToken, reaction: reaction, reactToBytes: reactToBytes, cmixParamsJSON: cmixParamsJSON)
        return try Parser.decode(ChannelSendReportJSON.self, from: data)
    }
}
