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
            print("ERROR: cmix is not available")
            fatalError("cmix is not available")
        }

        await progress(.loadingIdentity)

        let privateIdentity: Data
        if let _privateIdentity {
            do {
                try cmix.ekvSet("MyPrivateIdentity", value: _privateIdentity)
            } catch {
                print("ERROR: could not set ekv: " + error.localizedDescription)
                fatalError("could not set ekv: " + error.localizedDescription)
            }
            privateIdentity = _privateIdentity
        } else {
            do {
                privateIdentity = try cmix.ekvGet("MyPrivateIdentity")
            } catch {
                print("ERROR: could not set ekv: " + error.localizedDescription)
                fatalError("could not set ekv: " + error.localizedDescription)
            }
        }

        let publicIdentity: Data?
        publicIdentity = Bindings.BindingsGetPublicChannelIdentityFromPrivate(
            privateIdentity,
            &err
        )
        if let err {
            print(
                "ERROR: could not derive public identity: "
                    + err.localizedDescription
            )
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
                print(
                    "failed to decode public identity json: \(error.localizedDescription)"
                )
            }
        }

        await progress(.creatingIdentity)

        let notifications = Bindings.BindingsLoadNotifications(
            cmix.getID(),
            &err
        )
        if let err {
            print(
                "ERROR: could not load notifications: "
                    + err.localizedDescription
            )
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
            print(
                "ERROR: could not load dm client: " + err.localizedDescription
            )
            fatalError("could not load dm client: " + err.localizedDescription)
        }

        await progress(.connectingToNodes)

        remoteKV = cmix.getRemoteKV()

        await progress(.settingUpRemoteKV)

        let storageTagListener: RemoteKVKeyChangeListener
        do {
            storageTagListener = try RemoteKVKeyChangeListener(
                key: "channels-storage-tag",
                remoteKV: remoteKV!,
                version: 0,
                localEvents: true
            )
        } catch {
            print("ERROR: failed to set storageTagListener \(error)")
            fatalError("failed to set storageTagListener \(error)")
        }

        await progress(.waitingForNetwork)

        self.storageTagListener = storageTagListener

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
                print("ERROR: BindingsLoadNotificationsDummy returned nil")
                fatalError("BindingsLoadNotificationsDummy returned nil")
            }

            await MainActor.run {
                eventModelBuilder = EventModelBuilder(
                    model: EventModel()
                )
            }

            if let actor = modelActor {
                eventModelBuilder?.configure(modelActor: actor)
            }

            await progress(.creatingE2e)
            let receptionIdentity = try cmix.makeReceptionIdentity()
            var e2eErr: NSError?
            guard let e2eObj = BindingsLogin(
                cmix.getID(),
                nil,
                receptionIdentity,
                nil,
                &e2eErr
            ) else {
                print("[FT] ERROR: Failed to create E2e: \(e2eErr?.localizedDescription ?? "unknown")")
                throw e2eErr ?? MyError.runtimeError("[FT] Failed to create E2e")
            }
            e2e = e2eObj

            channelsFileTransfer = try ChannelsFileTransfer.initialize(
                e2eID: Int(e2eObj.getID()),
                paramsJson: nil
            )

            let extensionIDs = [channelsFileTransfer!.getExtensionBuilderID()]
            let extensionJSON = try JSONEncoder().encode(extensionIDs)

            if !(sm?.isSetupComplete ?? false) {
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
                    print("ERROR: no cm")
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
                self.storageTagListener!.data = cm.getStorageTag().data
            } else {
                let storageTagString = self.storageTagListener!.data!.utf8
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

            if sm?.isSetupComplete ?? false {
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
            print("ERROR: codename/DM/modelContainer not there")
            fatalError("codename/DM/modelContainer not there")
        }
        if !codename.isEmpty {
            guard let selfPubKeyData = DM.getPublicKey() else {
                print("ERROR: self pub key data is nil")
                fatalError("self pub key data is nil")
            }
            let selfPubKeyB64 = selfPubKeyData.base64EncodedString()
            do {
                try await MainActor.run {
                    guard let actor = self.modelActor else {
                        print("ERROR: modelActor not available")
                        return
                    }
                    let descriptor = FetchDescriptor<ChatModel>(
                        predicate: #Predicate { $0.id == selfPubKeyB64 }
                    )
                    let existing = try actor.fetch(descriptor)
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
                        actor.insert(chat)
                        try actor.save()
                    }
                }
            } catch {
                print(
                    "HomeView: Failed to create self chat for \(codename): \(error)"
                )
            }
        }
        do {
            let cd = try await joinChannel(XX_GENERAL_CHAT)
            let channelId = cd.channelId ?? "xxGeneralChat"
            try await MainActor.run {
                guard let actor = self.modelActor else {
                    print("ERROR: modelActor not available")
                    return
                }
                let check = FetchDescriptor<ChatModel>(
                    predicate: #Predicate { $0.id == channelId }
                )
                let existingChannel = try actor.fetch(check)
                if existingChannel.isEmpty {
                    let channelChat = ChatModel(channelId: channelId, name: cd.name)
                    actor.insert(channelChat)
                    try actor.save()
                }
            }
        } catch {
            print(
                "HomeView: Failed to ensure initial channel xxGeneralChat: \(error)"
            )
        }

        sm!.isSetupComplete = true

        await progress(.ready)
    }

    /// Generate multiple channel identities
    func generateIdentities(amountOfIdentities: Int) -> [GeneratedIdentity] {
        guard let cmix else {
            print("ERROR: cmix is not available")
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
                print("ERROR: Failed to generate private identity")
                if let error = err {
                    print("Error: \(error.localizedDescription)")
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
                print("ERROR: Failed to derive public identity")
                if let error = err {
                    print("Error: \(error.localizedDescription)")
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
                print(
                    "ERROR: Failed to decode identity JSON: \(error.localizedDescription)"
                )
            }
        }

        return identities
    }

    /// Export identity with password encryption
    public func exportIdentity(password _: String) throws -> Data {
        guard let cmix = cmix else {
            throw MyError.runtimeError("cMix not initialized")
        }
        return try cmix.ekvGet("MyPrivateIdentity")
    }

    /// Import a private identity using a password
    public func importIdentity(password: String, data: Data) throws -> Data {
        var err: NSError?
        let imported = Bindings.BindingsImportPrivateIdentity(password, data, &err)

        if let error = err {
            throw error
        }

        guard let result = imported else {
            throw MyError.runtimeError("Import returned nil")
        }

        return result
    }
}
