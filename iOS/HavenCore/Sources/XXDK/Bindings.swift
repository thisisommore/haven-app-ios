//
//  Bindings.swift
//  iOSExample
//
//  Swift-style wrappers for C/ObjC bindings that use NSError pointers.
//  Handles error propagation internally so callers can use throws.
//

import Bindings
import Foundation

public extension DataProtocol {
  func utf8() throws -> String {
    let result = String(bytes: self, encoding: .utf8)
    guard let result else {
      throw XXDKError.invalidUTF8
    }
    return result
  }
}

// MARK: - Static Bindings (no instance required)

public enum BindingsStatic {
  /// Channel URL / JSON
  public static func decodePublicURL(_ url: String) throws -> String {
    var err: NSError?
    let result = Bindings.BindingsDecodePublicURL(url, &err)
    if let err { throw err }
    return result
  }

  public static func decodePrivateURL(url: String, password: String) throws -> String {
    var err: NSError?
    let result = Bindings.BindingsDecodePrivateURL(url, password, &err)
    if let err { throw err }
    return result
  }

  public static func getChannelJSON(_ prettyPrint: String) throws -> ChannelJSON? {
    var err: NSError?
    let result = Bindings.BindingsGetChannelJSON(prettyPrint, &err)
    if let err { throw err }
    guard let data = result else { return nil }
    return try Parser.decode(ChannelJSON.self, from: data)
  }

  public static func getShareUrlType(_ url: String) throws -> Int {
    var err: NSError?
    var typeValue = 0
    Bindings.BindingsGetShareUrlType(url, &typeValue, &err)
    if let err { throw err }
    return typeValue
  }

  /// Identity
  public static func getPublicChannelIdentityFromPrivate(_ privateIdentity: Data) throws -> IdentityJSON? {
    var err: NSError?
    let result = Bindings.BindingsGetPublicChannelIdentityFromPrivate(privateIdentity, &err)
    if let err { throw err }
    guard let data = result else { return nil }
    return try Parser.decode(IdentityJSON.self, from: data)
  }

  public static func constructIdentity(pubKey: Data?, codeset: Int) throws -> IdentityJSON? {
    var err: NSError?
    let result = Bindings.BindingsConstructIdentity(pubKey, codeset, &err)
    if let err { throw err }
    guard let data = result else { return nil }
    return try Parser.decode(IdentityJSON.self, from: data)
  }

  public static func generateChannelIdentity(_ cmixId: Int) throws -> Data? {
    var err: NSError?
    let result = Bindings.BindingsGenerateChannelIdentity(cmixId, &err)
    if let err { throw err }
    return result
  }

  public static func importPrivateIdentity(password: String, data: Data) throws -> Data? {
    var err: NSError?
    let result = Bindings.BindingsImportPrivateIdentity(password, data, &err)
    if let err { throw err }
    return result
  }

  /// Notifications
  public static func loadNotifications(_ cmixId: Int) throws -> Bindings.BindingsNotifications? {
    var err: NSError?
    let result = Bindings.BindingsLoadNotifications(cmixId, &err)
    if let err { throw err }
    return result
  }

  public static func loadNotificationsDummy(_ cmixId: Int) throws -> Bindings.BindingsNotifications? {
    var err: NSError?
    let result = Bindings.BindingsLoadNotificationsDummy(cmixId, &err)
    if let err { throw err }
    return result
  }

  /// DM
  public static func newDMClient(
    cmixId: Int,
    notifications: Bindings.BindingsNotifications,
    privateIdentity: Data,
    receiverBuilder: Bindings.BindingsDMReceiverBuilderProtocol,
    dmReceiver: Bindings.BindingsDmCallbacksProtocol
  ) throws -> Bindings.BindingsDMClient? {
    var err: NSError?
    let result = Bindings.BindingsNewDMClient(
      cmixId, notifications.getID(), privateIdentity, receiverBuilder, dmReceiver, &err
    )
    if let err { throw err }
    return result
  }

  /// ChannelsManager
  public static func newChannelsManager(
    cmixId: Int,
    privateIdentity: Data,
    eventModelBuilder: Bindings.BindingsEventModelBuilderProtocol,
    extensionJSON: Data,
    notiId: Int,
    channelUICallbacks: Bindings.BindingsChannelUICallbacksProtocol
  ) throws -> Bindings.BindingsChannelsManager? {
    var err: NSError?
    let result = Bindings.BindingsNewChannelsManager(
      cmixId, privateIdentity, eventModelBuilder, extensionJSON, notiId, channelUICallbacks,
      &err
    )
    if let err { throw err }
    return result
  }

  public static func loadChannelsManager(
    cmixId: Int,
    storageTag: String,
    eventModelBuilder: Bindings.BindingsEventModelBuilderProtocol,
    extensionJSON: Data,
    notiId: Int,
    channelUICallbacks: Bindings.BindingsChannelUICallbacksProtocol
  ) throws -> Bindings.BindingsChannelsManager? {
    var err: NSError?
    let result = Bindings.BindingsLoadChannelsManager(
      cmixId, storageTag, eventModelBuilder, extensionJSON, notiId, channelUICallbacks, &err
    )
    if let err { throw err }
    return result
  }

  /// Cmix
  public static func newCmix(ndf: Data, stateDir: String, secret: Data, backup: String) throws {
    var err: NSError?
    try Bindings.BindingsNewCmix(ndf.utf8(), stateDir, secret, backup, &err)
    if let err { throw err }
  }

  public static func loadCmix(stateDir: String, secret: Data, paramsJSON: Data) throws -> Bindings
    .BindingsCmix? {
    var err: NSError?
    let result = Bindings.BindingsLoadCmix(stateDir, secret, paramsJSON, &err)
    if let err { throw err }
    return result
  }

  public static func deleteCmixInstance(_ cmixId: Int) throws {
    var err: NSError?
    Bindings.BindingsDeleteCmixInstance(cmixId, &err)
    if let err { throw err }
  }

  /// Network
  public static func downloadAndVerifySignedNdf(url: String, cert: String) throws -> Data? {
    var err: NSError?
    let result = Bindings.BindingsDownloadAndVerifySignedNdfWithUrl(url, cert, &err)
    if let err { throw err }
    return result
  }
}

// MARK: - ChannelsManager

public final class BindingsChannelsManagerWrapper {
  private let inner: Bindings.BindingsChannelsManager

  public init(_ inner: Bindings.BindingsChannelsManager) {
    self.inner = inner
  }

  public func generateChannel(name: String, description: String, privacyLevel: Int) throws -> String {
    var err: NSError?
    let result = self.inner.generateChannel(
      name, description: description, privacyLevel: privacyLevel, error: &err
    )
    if let err { throw err }
    return result
  }

  public func getNickname(_ channelIdBytes: Data) throws -> String {
    var err: NSError?
    let result = self.inner.getNickname(channelIdBytes, error: &err)
    if let err { throw err }
    return result
  }

  public func areDMsEnabled(_ channelIdData: Data) throws -> Bool {
    var result = ObjCBool(false)
    try inner.areDMsEnabled(channelIdData, ret0_: &result)
    return result.boolValue
  }

  public func isChannelAdmin(_ channelIdData: Data) throws -> Bool {
    var result = ObjCBool(false)
    try inner.isChannelAdmin(channelIdData, ret0_: &result)
    return result.boolValue
  }

  public func muted(_ channelIdData: Data) throws -> Bool {
    var result = ObjCBool(false)
    try inner.muted(channelIdData, ret0_: &result)
    return result.boolValue
  }

  /// Pass-through to inner (already use Swift throws)
  public func joinChannel(_ prettyPrint: String) throws -> ChannelJSON? {
    let data = try inner.joinChannel(prettyPrint)
    return try Parser.decode(ChannelJSON.self, from: data)
  }

  public func leaveChannel(_ channelIdData: Data) throws {
    try self.inner.leaveChannel(channelIdData)
  }

  public func getShareURL(_ cmixId: Int, host: String, maxUses: Int, channelIdBytes: Data) throws
    -> ShareURLJSON? {
    let data = try inner.getShareURL(
      cmixId, host: host, maxUses: maxUses, channelIdBytes: channelIdBytes
    )
    return try Parser.decode(ShareURLJSON.self, from: data)
  }

  public func enableDirectMessages(_ channelIdData: Data) throws {
    try self.inner.enableDirectMessages(channelIdData)
  }

  public func disableDirectMessages(_ channelIdData: Data) throws {
    try self.inner.disableDirectMessages(channelIdData)
  }

  public func exportChannelAdminKey(_ channelIdData: Data, encryptionPassword: String) throws -> Data {
    try self.inner.exportChannelAdminKey(channelIdData, encryptionPassword: encryptionPassword)
  }

  public func importChannelAdminKey(
    _ channelIdData: Data, encryptionPassword: String, encryptedPrivKey: Data
  ) throws {
    try self.inner.importChannelAdminKey(
      channelIdData, encryptionPassword: encryptionPassword,
      encryptedPrivKey: encryptedPrivKey
    )
  }

  public func getMutedUsers(_ channelIdData: Data) throws -> Data {
    try self.inner.getMutedUsers(channelIdData)
  }

  public func muteUser(
    _ channelIdData: Data, mutedUserPubKeyBytes: Data, undoAction: Bool, validUntilMS: Int,
    cmixParamsJSON: Data
  ) throws {
    try self.inner.muteUser(
      channelIdData, mutedUserPubKeyBytes: mutedUserPubKeyBytes, undoAction: undoAction,
      validUntilMS: validUntilMS, cmixParamsJSON: cmixParamsJSON
    )
  }

  public func setNickname(_ nickname: String, channelIDBytes: Data) throws {
    try self.inner.setNickname(nickname, channelIDBytes: channelIDBytes)
  }

  public func getStorageTag() -> String {
    self.inner.getStorageTag()
  }

  public func sendMessage(
    _ channelIdData: Data, message: String, validUntilMS: Int64, cmixParamsJSON: Data,
    pingsJSON: Data?
  ) throws {
    try self.inner.sendMessage(
      channelIdData, message: message, validUntilMS: validUntilMS,
      cmixParamsJSON: cmixParamsJSON, pingsJSON: pingsJSON
    )
  }

  public func sendReply(
    _ channelIdData: Data, message: String, messageToReactTo: Data, validUntilMS: Int64,
    cmixParamsJSON: Data, pingsJSON: Data?
  ) throws -> ChannelSendReportJSON? {
    let data = try inner.sendReply(
      channelIdData, message: message, messageToReactTo: messageToReactTo,
      validUntilMS: validUntilMS, cmixParamsJSON: cmixParamsJSON, pingsJSON: pingsJSON
    )
    return try Parser.decode(ChannelSendReportJSON.self, from: data)
  }

  @discardableResult
  public func sendReaction(
    _ channelIdData: Data, reaction: String, messageToReactTo: Data, validUntilMS: Int64,
    cmixParamsJSON: Data
  ) throws -> ChannelSendReportJSON? {
    let data = try inner.sendReaction(
      channelIdData, reaction: reaction, messageToReactTo: messageToReactTo,
      validUntilMS: validUntilMS, cmixParamsJSON: cmixParamsJSON
    )
    return try Parser.decode(ChannelSendReportJSON.self, from: data)
  }

  public func deleteMessage(_ channelIdData: Data, targetMessageIdBytes: Data, cmixParamsJSON: Data)
    throws {
    try self.inner.deleteMessage(
      channelIdData, targetMessageIdBytes: targetMessageIdBytes,
      cmixParamsJSON: cmixParamsJSON
    )
  }

  public func exportPrivateIdentity(password: String) throws -> Data {
    try self.inner.exportPrivateIdentity(password)
  }
}

// MARK: - DMClient

public final class BindingsDMClientWrapper {
  private let inner: Bindings.BindingsDMClient

  public init(_ inner: Bindings.BindingsDMClient) {
    self.inner = inner
  }

  public func getNickname() throws -> String {
    var err: NSError?
    let result = self.inner.getNickname(&err)
    if let err { throw err }
    return result
  }

  public func getPublicKey() -> Data? {
    self.inner.getPublicKey()
  }

  public func getToken() -> Int64 {
    self.inner.getToken()
  }

  public func setNickname(_ nickname: String) throws {
    try self.inner.setNickname(nickname)
  }

  public func sendText(
    _ toPubKey: Data, partnerToken: Int32, message: String, leaseTimeMS: Int64,
    cmixParamsJSON: Data
  ) throws -> ChannelSendReportJSON? {
    let data = try inner.sendText(
      toPubKey, partnerToken: partnerToken, message: message, leaseTimeMS: leaseTimeMS,
      cmixParamsJSON: cmixParamsJSON
    )
    return try Parser.decode(ChannelSendReportJSON.self, from: data)
  }

  public func sendReply(
    _ toPubKey: Data, partnerToken: Int32, replyMessage: String, replyToBytes: Data,
    leaseTimeMS: Int64, cmixParamsJSON: Data
  ) throws -> ChannelSendReportJSON? {
    let data = try inner.sendReply(
      toPubKey, partnerToken: partnerToken, replyMessage: replyMessage,
      replyToBytes: replyToBytes, leaseTimeMS: leaseTimeMS, cmixParamsJSON: cmixParamsJSON
    )
    return try Parser.decode(ChannelSendReportJSON.self, from: data)
  }

  public func sendReaction(
    _ toPubKey: Data, partnerToken: Int32, reaction: String, reactToBytes: Data,
    cmixParamsJSON: Data
  ) throws -> ChannelSendReportJSON? {
    let data = try inner.sendReaction(
      toPubKey, partnerToken: partnerToken, reaction: reaction, reactToBytes: reactToBytes,
      cmixParamsJSON: cmixParamsJSON
    )
    return try Parser.decode(ChannelSendReportJSON.self, from: data)
  }
}
