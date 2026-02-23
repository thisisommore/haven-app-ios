//
//  XXDK+Identity.swift
//  iOSExample
//

import Bindings
import Foundation
import SwiftData

extension XXDK {
    func load(privateIdentity _privateIdentity: Data?) async {
        lockTask()
        defer { unlockTask() }
        var err: NSError?
        guard let cmix else {
            AppLogger.identity.critical("cmix is not available")
            fatalError("cmix is not available")
        }

        await progress(.loadingIdentity)

        let privateIdentity: Data
        if let _privateIdentity {
            do {
                try cmix.ekvSet("MyPrivateIdentity", value: _privateIdentity)
            } catch {
                AppLogger.identity.critical("could not set ekv: \(error.localizedDescription, privacy: .public)")
                fatalError("could not set ekv: " + error.localizedDescription)
            }
            privateIdentity = _privateIdentity
        } else {
            do {
                privateIdentity = try cmix.ekvGet("MyPrivateIdentity")
            } catch {
                AppLogger.identity.critical("could not get ekv: \(error.localizedDescription, privacy: .public)")
                fatalError("could not set ekv: " + error.localizedDescription)
            }
        }

        let publicIdentity: Data?
        publicIdentity = Bindings.BindingsGetPublicChannelIdentityFromPrivate(
            privateIdentity,
            &err
        )
        if let err {
            AppLogger.identity.critical("could not derive public identity: \(err.localizedDescription, privacy: .public)")
            fatalError(
                "could not derive public identity: " + err.localizedDescription
            )
        }
        if let pubId = publicIdentity {
            do {
                let identity = try Parser.decodeIdentity(from: pubId)

                await MainActor.run {
                    self.codeset = identity.codeset
                    self.codename = identity.codename
                }

                if let nameData = identity.codename.data(using: .utf8) {
                    do { try cmix.ekvSet("MyCodename", value: nameData) } catch {}
                }
            } catch {
                AppLogger.identity.error("failed to decode public identity json: \(error.localizedDescription, privacy: .public)")
            }
        }

        await progress(.creatingIdentity)

        let notifications = Bindings.BindingsLoadNotifications(
            cmix.getID(),
            &err
        )
        if let err {
            AppLogger.identity.critical("could not load notifications: \(err.localizedDescription, privacy: .public)")
            fatalError(
                "could not load notifications: " + err.localizedDescription
            )
        }

        await progress(.syncingNotifications)

        let receiverBuilder = DMReceiverBuilder(receiver: dmReceiver)

        let dmClient = Bindings.BindingsNewDMClient(
            cmix.getID(),
            (notifications?.getID())!,
            privateIdentity,
            receiverBuilder,
            dmReceiver,
            &err
        )
        DM = dmClient
        if let err {
            AppLogger.identity.critical("could not load dm client: \(err.localizedDescription, privacy: .public)")
            fatalError("could not load dm client: " + err.localizedDescription)
        }

        await progress(.connectingToNodes)

        remoteKV = cmix.getRemoteKV()

        await progress(.settingUpRemoteKV)

        do {
            storageTagListener = try RemoteKVKeyChangeListener(
                key: "channels-storage-tag",
                remoteKV: remoteKV!,
                version: 0,
                localEvents: true
            )
        } catch {
            AppLogger.identity.critical("failed to set storageTagListener: \(error.localizedDescription, privacy: .public)")
            fatalError("failed to set storageTagListener \(error)")
        }

        await progress(.waitingForNetwork)

        do {
            let cmixId = cmix.getID()
            var err: NSError?

            await progress(.preparingChannelsManager)

            guard
                let noti = Bindings.BindingsLoadNotificationsDummy(
                    cmixId,
                    &err
                )
            else {
                AppLogger.identity.critical("BindingsLoadNotificationsDummy returned nil")
                fatalError("BindingsLoadNotificationsDummy returned nil")
            }

            await MainActor.run {
                eventModelBuilder = EventModelBuilder(
                    model: EventModel()
                )
            }

            if let modelActor {
                eventModelBuilder?.configure(modelActor: modelActor)
            }

            let extensionJSON = try JSONEncoder().encode([String]())

            if !(appStorage?.isSetupComplete ?? false) {
                guard
                    let cm = Bindings.BindingsNewChannelsManager(
                        cmix.getID(),
                        privateIdentity,
                        eventModelBuilder,
                        extensionJSON,
                        noti.getID(),
                        channelUICallbacks,
                        &err
                    )
                else {
                    AppLogger.identity.critical("no cm")
                    fatalError("no cm")
                }
                channelsManager = cm
                let timestamp = ISO8601DateFormatter().string(from: Date())
                let storageTagDataJson = try Parser.encodeString(cm.getStorageTag())
                let storageTagData = storageTagDataJson.base64EncodedString()
                let entry = RemoteKVEntry(
                    version: 0,
                    data: storageTagData,
                    timestamp: timestamp
                )
                let entryData = try Parser.encodeRemoteKVEntry(entry)
                try remoteKV!.set("channels-storage-tag", objectJSON: entryData)
                storageTagListener!.data = cm.getStorageTag().data
            } else {
                let storageTagString = storageTagListener!.data!.utf8
                let cm = Bindings.BindingsLoadChannelsManager(
                    cmix.getID(),
                    storageTagString,
                    eventModelBuilder,
                    extensionJSON,
                    noti.getID(),
                    channelUICallbacks,
                    &err
                )
                channelsManager = cm
            }

            if appStorage?.isSetupComplete ?? false {
                await progress(.readyExistingUser)
                return
            }

            await progress(.joiningChannels)
            while true {
                let readyData = try cmix.isReady(0.1)
                let readinessInfo = try Parser.decodeIsReadyInfo(
                    from: readyData
                )
                if !readinessInfo.isReady {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    continue
                } else {
                    break
                }
            }
        } catch {
            fatalError("err \(error)")
        }

        guard let codename, let DM else {
            AppLogger.identity.critical("codename/DM/modelContainer not there")
            fatalError("codename/DM/modelContainer not there")
        }
        if !codename.isEmpty {
            guard let selfPubKeyData = DM.getPublicKey() else {
                AppLogger.identity.critical("self pub key data is nil")
                fatalError("self pub key data is nil")
            }
            let selfPubKeyB64 = selfPubKeyData.base64EncodedString()
            do {
                try await MainActor.run {
                    guard let modelActor else {
                        AppLogger.identity.error("modelActor not available")
                        return
                    }
                    let descriptor = FetchDescriptor<ChatModel>(
                        predicate: #Predicate { $0.id == selfPubKeyB64 }
                    )
                    let existing = try modelActor.fetch(descriptor)
                    if existing.isEmpty {
                        let token64 = DM.getToken()
                        let tokenU32 = UInt32(truncatingIfNeeded: token64)
                        let selfToken = Int32(bitPattern: tokenU32)
                        let chat = ChatModel(
                            pubKey: selfPubKeyData,
                            name: "<self>",
                            dmToken: selfToken,
                            color: 0xE97451
                        )
                        modelActor.insert(chat)
                        try modelActor.save()
                    }
                }
            } catch {
                AppLogger.home.error("Failed to create self chat for \(codename, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
        do {
            let cd = try await joinChannelFromURL(XX_IOS_CHAT)
            let channelId = cd.channelId ?? "xxIOS"
            try await MainActor.run {
                guard let modelActor else {
                    AppLogger.identity.error("modelActor not available")
                    return
                }
                let check = FetchDescriptor<ChatModel>(
                    predicate: #Predicate { $0.id == channelId }
                )
                let existingChannel = try modelActor.fetch(check)
                if existingChannel.isEmpty {
                    let channelChat = ChatModel(channelId: channelId, name: cd.name)
                    modelActor.insert(channelChat)
                    try modelActor.save()
                }
            }
        } catch {
            AppLogger.home.error("Failed to ensure initial channel xxIOS: \(error.localizedDescription, privacy: .public)")
        }

        await MainActor.run {
            appStorage!.isSetupComplete = true
        }

        await progress(.ready)
    }

    /// Generate multiple channel identities
    func generateIdentities(amountOfIdentities: Int) -> [GeneratedIdentity] {
        guard let cmix else {
            AppLogger.identity.error("cmix is not available")
            return []
        }

        var identities: [GeneratedIdentity] = []
        var err: NSError?

        for _ in 0 ..< amountOfIdentities {
            let privateIdentity = Bindings.BindingsGenerateChannelIdentity(
                cmix.getID(),
                &err
            )

            guard privateIdentity != nil else {
                AppLogger.identity.error("Failed to generate private identity")
                if let err {
                    AppLogger.identity.error("Error: \(err.localizedDescription, privacy: .public)")
                }
                continue
            }

            guard err == nil else {
                fatalError(
                    "ERROR: Failed to generate private identity: \(err!.localizedDescription)"
                )
            }

            let publicIdentity =
                Bindings.BindingsGetPublicChannelIdentityFromPrivate(
                    privateIdentity!,
                    &err
                )

            guard publicIdentity != nil else {
                AppLogger.identity.error("Failed to derive public identity")
                if let err {
                    AppLogger.identity.error("Error: \(err.localizedDescription, privacy: .public)")
                }
                continue
            }

            guard err == nil else {
                fatalError(
                    "ERROR: Failed to derive public identity: \(err!.localizedDescription)"
                )
            }

            do {
                let identity = try Parser.decodeIdentity(from: publicIdentity!)

                let generatedIdentity = GeneratedIdentity(
                    privateIdentity: privateIdentity!,
                    codename: identity.codename,
                    codeset: identity.codeset,
                    pubkey: identity.pubkey
                )

                identities.append(generatedIdentity)

            } catch {
                AppLogger.identity.error("Failed to decode identity JSON: \(error.localizedDescription, privacy: .public)")
            }
        }

        return identities
    }

    /// Export identity with password encryption
    public func exportIdentity(password _: String) throws -> Data {
        guard let cmix else {
            throw XXDKError.cmixNotInitialized
        }
        return try cmix.ekvGet("MyPrivateIdentity")
    }

    /// Import a private identity using a password
    public func importIdentity(password: String, data: Data) throws -> Data {
        var err: NSError?
        let imported = Bindings.BindingsImportPrivateIdentity(password, data, &err)

        if let err {
            throw err
        }

        guard let imported else {
            throw XXDKError.importReturnedNil
        }

        return imported
    }
}
