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

        // Cmix
        guard let cmix else {
            AppLogger.identity.critical("cmix is not available")
            fatalError("cmix is not available")
        }

        await progress(.loadingIdentity)

        // Notifications

        // Identity

        // Use provided private identity if available or use from ekv
        // Identity is usually provided for new user
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

        let publicIdentity: IdentityJSON?
        do {
            publicIdentity = try BindingsStatic.getPublicChannelIdentityFromPrivate(privateIdentity)
        } catch {
            AppLogger.identity.critical("could not derive public identity: \(error.localizedDescription, privacy: .public)")
            fatalError("could not derive public identity: " + error.localizedDescription)
        }
        if let identity = publicIdentity {
            await MainActor.run {
                self.codeset = identity.codeset
                self.codename = identity.codename
            }
        }

        await progress(.creatingIdentity)

        //

        // Notifications
        let notifications: Bindings.BindingsNotifications?
        do {
            notifications = try BindingsStatic.loadNotifications(cmix.getID())
        } catch {
            AppLogger.identity.critical("could not load notifications: \(error.localizedDescription, privacy: .public)")
            fatalError("could not load notifications: " + error.localizedDescription)
        }
        guard let notifications else {
            AppLogger.identity.critical("could not load notifications: returned nil")
            fatalError("could not load notifications: returned nil")
        }

        await progress(.syncingNotifications)

        //

        // Receivers

        do {
            guard let dmClient = try BindingsStatic.newDMClient(
                cmixId: cmix.getID(),
                notifications: notifications,
                privateIdentity: privateIdentity,
                receiverBuilder: DMReceiverBuilder(receiver: dmReceiver),
                dmReceiver: dmReceiver
            ) else {
                AppLogger.identity.critical("could not load dm client: returned nil")
                fatalError("could not load dm client: returned nil")
            }
            DM = BindingsDMClientWrapper(dmClient)
        } catch {
            AppLogger.identity.critical("could not load dm client: \(error.localizedDescription, privacy: .public)")
            fatalError("could not load dm client: " + error.localizedDescription)
        }

        //
        await progress(.connectingToNodes)
        await progress(.settingUpRemoteKV)

        do {
            storageTagListener = try RemoteKVKeyChangeListener(
                key: "channels-storage-tag",
                remoteKV: cmix.getRemoteKV()!,
                version: 0,
                localEvents: true
            )
        } catch {
            AppLogger.identity.critical("failed to set storageTagListener: \(error.localizedDescription, privacy: .public)")
            fatalError("failed to set storageTagListener \(error)")
        }

        await progress(.waitingForNetwork)

        do {
            await progress(.preparingChannelsManager)

            let noti: Bindings.BindingsNotifications?
            do {
                noti = try BindingsStatic.loadNotificationsDummy(cmix.getID())
            } catch {
                AppLogger.identity.critical("BindingsLoadNotificationsDummy failed: \(error.localizedDescription, privacy: .public)")
                fatalError("BindingsLoadNotificationsDummy failed: \(error.localizedDescription)")
            }
            guard let noti else {
                AppLogger.identity.critical("BindingsLoadNotificationsDummy returned nil")
                fatalError("BindingsLoadNotificationsDummy returned nil")
            }

            if let modelActor {
                eventModelBuilder.configure(modelActor: modelActor)
            }

            let extensionJSON = try JSONEncoder().encode([String]())

            if !(appStorage?.isSetupComplete ?? false) {
                let cm: Bindings.BindingsChannelsManager?
                do {
                    cm = try BindingsStatic.newChannelsManager(
                        cmixId: cmix.getID(),
                        privateIdentity: privateIdentity,
                        eventModelBuilder: eventModelBuilder,
                        extensionJSON: extensionJSON,
                        notiId: noti.getID(),
                        channelUICallbacks: channelUICallbacks
                    )
                } catch {
                    AppLogger.identity.critical("BindingsNewChannelsManager failed: \(error.localizedDescription, privacy: .public)")
                    fatalError("BindingsNewChannelsManager failed: \(error.localizedDescription)")
                }
                guard let cm else {
                    AppLogger.identity.critical("BindingsNewChannelsManager returned nil")
                    fatalError("BindingsNewChannelsManager returned nil")
                }
                channelsManager = BindingsChannelsManagerWrapper(cm)
                let timestamp = ISO8601DateFormatter().string(from: Date())
                let storageTagDataJson = try Parser.encodeString(channelsManager!.getStorageTag())
                let storageTagData = storageTagDataJson.base64EncodedString()
                let entry = RemoteKVEntry(
                    version: 0,
                    data: storageTagData,
                    timestamp: timestamp
                )
                let entryData = try Parser.encodeRemoteKVEntry(entry)
                try remoteKV!.set("channels-storage-tag", objectJSON: entryData)
                // the data sometimes is not available in the listener immediately so we set it manually
                storageTagListener!.data = channelsManager!.getStorageTag().data
            } else {
                let storageTagString = storageTagListener!.data!.utf8
                let cm: Bindings.BindingsChannelsManager?
                do {
                    cm = try BindingsStatic.loadChannelsManager(
                        cmixId: cmix.getID(),
                        storageTag: storageTagString,
                        eventModelBuilder: eventModelBuilder,
                        extensionJSON: extensionJSON,
                        notiId: noti.getID(),
                        channelUICallbacks: channelUICallbacks
                    )
                } catch {
                    AppLogger.identity.critical("BindingsLoadChannelsManager failed: \(error.localizedDescription, privacy: .public)")
                    fatalError("BindingsLoadChannelsManager failed: \(error.localizedDescription)")
                }
                guard let cm else {
                    AppLogger.identity.critical("BindingsLoadChannelsManager returned nil")
                    fatalError("BindingsLoadChannelsManager returned nil")
                }
                channelsManager = BindingsChannelsManagerWrapper(cm)
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

        for _ in 0 ..< amountOfIdentities {
            let privateIdentity: Data?
            do {
                privateIdentity = try BindingsStatic.generateChannelIdentity(cmix.getID())
            } catch {
                AppLogger.identity.error("Failed to generate private identity: \(error.localizedDescription, privacy: .public)")
                continue
            }

            guard let privateIdentity else {
                AppLogger.identity.error("Failed to generate private identity: returned nil")
                continue
            }

            let publicIdentity: IdentityJSON?
            do {
                publicIdentity = try BindingsStatic.getPublicChannelIdentityFromPrivate(privateIdentity)
            } catch {
                AppLogger.identity.error("Failed to derive public identity: \(error.localizedDescription, privacy: .public)")
                continue
            }

            guard let identity = publicIdentity else {
                AppLogger.identity.error("Failed to derive public identity: returned nil")
                continue
            }

            let generatedIdentity = GeneratedIdentity(
                privateIdentity: privateIdentity,
                codename: identity.codename,
                codeset: identity.codeset,
                pubkey: identity.pubkey
            )

            identities.append(generatedIdentity)
        }

        return identities
    }

    /// Export identity with password encryption
    func exportIdentity(password _: String) throws -> Data {
        guard let cmix else {
            throw XXDKError.cmixNotInitialized
        }
        return try cmix.ekvGet("MyPrivateIdentity")
    }

    /// Import a private identity using a password
    func importIdentity(password: String, data: Data) throws -> Data {
        guard let imported = try BindingsStatic.importPrivateIdentity(password: password, data: data) else {
            throw XXDKError.importReturnedNil
        }
        return imported
    }
}
