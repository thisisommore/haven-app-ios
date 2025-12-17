//
//  XXDK+Channels.swift
//  iOSExample
//

import Bindings
import Foundation

public extension XXDK {
    /// Join a channel using a URL (public share link)
    internal func joinChannelFromURL(_ url: String) async throws -> ChannelJSON {
        var err: NSError?

        let prettyPrint = Bindings.BindingsDecodePublicURL(url, &err)

        if let error = err {
            throw error
        }

        return try await joinChannel(prettyPrint)
    }

    /// Join a channel using pretty print format
    internal func joinChannel(_ prettyPrint: String) async throws -> ChannelJSON {
        try await Task.sleep(for: .seconds(20))
        guard let cmix else { throw MyError.runtimeError("no net") }
        guard let storageTagListener else {
            print("ERROR: no storageTagListener")
            fatalError("no storageTagListener")
        }
        guard let storageTagEntry = storageTagListener.data else {
            print("ERROR: no storageTagListener data")
            fatalError("no storageTagListener data")
        }
        var err: NSError?
        let cmixId = cmix.getID()

        let storageTag = storageTagEntry.utf8

        guard let noti = Bindings.BindingsLoadNotificationsDummy(cmixId, &err)
        else {
            print("ERROR: notifications dummy was nil")
            fatalError("notifications dummy was nil")
        }
        if let e = err {
            throw MyError.runtimeError(
                "could not load notifications dummy: \(e.localizedDescription)"
            )
        }

        let cm: Bindings.BindingsChannelsManager
        if let existingCm = channelsManager {
            cm = existingCm
        } else {
            print("BindingsLoadChannelsManager: tag - \(storageTag)")
            guard let loadedCm = Bindings.BindingsLoadChannelsManager(
                cmixId,
                storageTag,
                eventModelBuilder,
                nil,
                noti.getID(),
                channelUICallbacks,
                &err
            ) else {
                throw MyError.runtimeError(
                    "could not load channels manager: \(err?.localizedDescription ?? "unknown error")"
                )
            }
            cm = loadedCm
            channelsManager = cm
        }

        let raw = try cm.joinChannel(prettyPrint)
        let channel = try Parser.decodeChannel(from: raw)
        print("Joined channel: \(channel.name)")
        return channel
    }

    /// Create a new channel
    func createChannel(
        name: String,
        description: String,
        privacyLevel: PrivacyLevel,
        enableDms: Bool = true
    ) async throws -> ChannelJSON {
        guard let cm = channelsManager else {
            throw MyError.runtimeError("Channels Manager not initialized")
        }

        var err: NSError?

        let prettyPrint = cm.generateChannel(
            name,
            description: description,
            privacyLevel: privacyLevel.rawValue,
            error: &err
        )

        if let error = err {
            throw error
        }

        let channel = try await joinChannel(prettyPrint)

        guard let channelId = channel.channelId else {
            throw MyError.runtimeError("ChannelID was not found")
        }

        if enableDms {
            try enableDirectMessages(channelId: channelId)
        } else {
            try disableDirectMessages(channelId: channelId)
        }

        return channel
    }

    /// Leave a channel
    func leaveChannel(channelId: String) throws {
        guard let cm = channelsManager else {
            throw MyError.runtimeError("Channels Manager not initialized")
        }

        let channelIdData =
            Data(base64Encoded: channelId) ?? channelId.data(using: .utf8)
                ?? Data()

        do {
            try cm.leaveChannel(channelIdData)
        } catch {
            fatalError("failed to leave channel \(error)")
        }

        print("Successfully left channel: \(channelId)")
    }

    /// Get the share URL for a channel
    func getShareURL(channelId: String, host: String) throws -> ShareURLJSON {
        guard let cm = channelsManager else {
            throw MyError.runtimeError("Channels Manager not initialized")
        }
        guard let cmixInstance = cmix else {
            throw MyError.runtimeError("Cmix not initialized")
        }

        let channelIdData =
            Data(base64Encoded: channelId) ?? channelId.data(using: .utf8) ?? Data()

        let resultData = try cm.getShareURL(cmixInstance.getID(), host: host, maxUses: 0, channelIdBytes: channelIdData)
        return try Parser.decodeShareURL(from: resultData)
    }

    /// Get the privacy level for a given channel URL
    func getChannelPrivacyLevel(url: String) throws -> PrivacyLevel {
        var err: NSError?
        var typeValue = 0
        Bindings.BindingsGetShareUrlType(url, &typeValue, &err)

        if let error = err {
            throw error
        }

        return typeValue == 2 ? .secret : .publicChannel
    }

    /// Get channel data from a channel URL
    func getChannelFromURL(url: String) throws -> ChannelJSON {
        var err: NSError?

        let prettyPrint = Bindings.BindingsDecodePublicURL(url, &err)

        if let error = err {
            throw error
        }

        guard
            let channelJSONString = Bindings.BindingsGetChannelJSON(
                prettyPrint,
                &err
            )
        else {
            throw err
                ?? NSError(
                    domain: "XXDK",
                    code: -2,
                    userInfo: [
                        NSLocalizedDescriptionKey: "GetChannelJSON returned nil",
                    ]
                )
        }

        if let error = err {
            throw error
        }

        return try Parser.decodeChannel(from: channelJSONString)
    }

    /// Decode a private channel URL with password
    func decodePrivateURL(url: String, password: String) throws -> String {
        var err: NSError?
        let prettyPrint = Bindings.BindingsDecodePrivateURL(url, password, &err)

        if let error = err {
            throw error
        }

        return prettyPrint
    }

    /// Get channel data from a private channel URL with password
    func getPrivateChannelFromURL(url: String, password: String) throws
        -> ChannelJSON
    {
        var err: NSError?

        let prettyPrint = try decodePrivateURL(url: url, password: password)

        guard
            let channelJSONString = Bindings.BindingsGetChannelJSON(
                prettyPrint,
                &err
            )
        else {
            throw err
                ?? NSError(
                    domain: "XXDK",
                    code: -2,
                    userInfo: [
                        NSLocalizedDescriptionKey: "GetChannelJSON returned nil",
                    ]
                )
        }

        if let error = err {
            throw error
        }

        return try Parser.decodeChannel(from: channelJSONString)
    }

    /// Enable direct messages for a channel
    func enableDirectMessages(channelId: String) throws {
        guard let cm = channelsManager else {
            throw MyError.runtimeError("Channels Manager not initialized")
        }

        let channelIdData =
            Data(base64Encoded: channelId) ?? channelId.data(using: .utf8)
                ?? Data()

        do {
            try cm.enableDirectMessages(channelIdData)
        } catch {
            fatalError("failed to enable direct messages \(error)")
        }

        print("Successfully enabled direct messages for channel: \(channelId)")
    }

    /// Disable direct messages for a channel
    func disableDirectMessages(channelId: String) throws {
        guard let cm = channelsManager else {
            throw MyError.runtimeError("Channels Manager not initialized")
        }

        let channelIdData =
            Data(base64Encoded: channelId) ?? channelId.data(using: .utf8)
                ?? Data()

        do {
            try cm.disableDirectMessages(channelIdData)
        } catch {
            fatalError("failed to disable direct messages \(error)")
        }

        print("Successfully disabled direct messages for channel: \(channelId)")
    }

    /// Check if direct messages are enabled for a channel
    func areDMsEnabled(channelId: String) throws -> Bool {
        guard let cm = channelsManager else {
            throw MyError.runtimeError("Channels Manager not initialized")
        }

        let channelIdData =
            Data(base64Encoded: channelId) ?? channelId.data(using: .utf8)
                ?? Data()

        var result = ObjCBool(false)

        try cm.areDMsEnabled(channelIdData, ret0_: &result)

        return result.boolValue
    }

    /// Check if current user is admin of a channel
    func isChannelAdmin(channelId: String) -> Bool {
        guard let cm = channelsManager else {
            return false
        }

        let channelIdData = Data(base64Encoded: channelId) ?? channelId.data(using: .utf8) ?? Data()

        var result = ObjCBool(false)
        do {
            try cm.isChannelAdmin(channelIdData, ret0_: &result)
            return result.boolValue
        } catch {
            print("isChannelAdmin failed: \(error)")
            return false
        }
    }

    /// Export the admin key for a channel
    func exportChannelAdminKey(channelId: String, encryptionPassword: String) throws -> String {
        guard let cm = channelsManager else {
            throw NSError(domain: "XXDK", code: -1, userInfo: [NSLocalizedDescriptionKey: "Channel manager not initialized"])
        }

        let channelIdData = Data(base64Encoded: channelId) ?? channelId.data(using: .utf8) ?? Data()

        let result = try cm.exportChannelAdminKey(channelIdData, encryptionPassword: encryptionPassword)
        return String(data: result, encoding: .utf8) ?? ""
    }

    /// Import an admin key for a channel
    func importChannelAdminKey(channelId: String, encryptionPassword: String, privateKey: String) throws {
        guard let cm = channelsManager else {
            throw NSError(domain: "XXDK", code: -1, userInfo: [NSLocalizedDescriptionKey: "Channel manager not initialized"])
        }

        let channelIdData = Data(base64Encoded: channelId) ?? channelId.data(using: .utf8) ?? Data()
        let privateKeyData = privateKey.data(using: .utf8) ?? Data()

        try cm.importChannelAdminKey(channelIdData, encryptionPassword: encryptionPassword, encryptedPrivKey: privateKeyData)
    }

    /// Get muted users for a channel
    func getMutedUsers(channelId: String) throws -> [Data] {
        guard let cm = channelsManager else {
            throw MyError.runtimeError("Channels Manager not initialized")
        }

        let channelIdData = Data(base64Encoded: channelId) ?? channelId.data(using: .utf8) ?? Data()

        let resultData = try cm.getMutedUsers(channelIdData)

        print("getMutedUsers raw response: \(resultData.utf8)")

        guard let jsonArray = try? JSONSerialization.jsonObject(with: resultData) as? [String] else {
            print("getMutedUsers: Failed to parse as [String], trying other formats...")
            if let jsonObjects = try? JSONSerialization.jsonObject(with: resultData) {
                print("getMutedUsers parsed object: \(jsonObjects)")
            }
            return []
        }

        print("getMutedUsers parsed \(jsonArray.count) users")
        return jsonArray.compactMap { Data(base64Encoded: $0) }
    }

    /// Mute or unmute a user in a channel
    func muteUser(channelId: String, pubKey: Data, mute: Bool) throws {
        guard let cm = channelsManager else {
            throw MyError.runtimeError("Channels Manager not initialized")
        }

        let channelIdData = Data(base64Encoded: channelId) ?? channelId.data(using: .utf8) ?? Data()

        try cm.muteUser(channelIdData, mutedUserPubKeyBytes: pubKey, undoAction: !mute, validUntilMS: Int(Bindings.BindingsValidForeverBindings), cmixParamsJSON: "".data)

        print("Successfully \(mute ? "muted" : "unmuted") user in channel: \(channelId)")
    }

    /// Check if current user is muted in a channel
    func isMuted(channelId: String) -> Bool {
        guard let cm = channelsManager else {
            return false
        }

        let channelIdData = Data(base64Encoded: channelId) ?? channelId.data(using: .utf8) ?? Data()

        var result = ObjCBool(false)
        do {
            try cm.muted(channelIdData, ret0_: &result)
            return result.boolValue
        } catch {
            print("isMuted failed: \(error)")
            return false
        }
    }

    func getChannelNickname(channelId: String) throws -> String {
        guard let cm = channelsManager else {
            throw MyError.runtimeError("Channels Manager not initialized")
        }
        guard let channelIdBytes = Data(base64Encoded: channelId) else {
            throw NSError(domain: "XXDK", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid channel ID"])
        }
        var err: NSError?
        let nickname = cm.getNickname(channelIdBytes, error: &err)
        if let err = err { throw err }
        return nickname
    }

    func setChannelNickname(channelId: String, nickname: String) throws {
        guard let cm = channelsManager else {
            throw MyError.runtimeError("Channels Manager not initialized")
        }
        guard let channelIdBytes = Data(base64Encoded: channelId) else {
            throw NSError(domain: "XXDK", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid channel ID"])
        }
        try cm.setNickname(nickname, channelIDBytes: channelIdBytes)
    }
}
