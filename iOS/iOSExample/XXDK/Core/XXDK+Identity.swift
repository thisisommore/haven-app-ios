//
//  XXDK+Identity.swift
//  iOSExample
//

import Bindings
import Foundation
import SQLiteData

extension XXDK {
  func load(privateIdentity _privateIdentity: Data?) async {
    lockTask()
    defer { unlockTask() }

    // Cmix
    guard let cmix
    else {
      AppLogger.identity.error("cmix is not available")
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
        AppLogger.identity.error(
          "could not set ekv: \(error.localizedDescription, privacy: .public)"
        )
        fatalError("could not set ekv: " + error.localizedDescription)
      }
      privateIdentity = _privateIdentity
    } else {
      do {
        privateIdentity = try cmix.ekvGet("MyPrivateIdentity")
      } catch {
        AppLogger.identity.error(
          "could not get ekv: \(error.localizedDescription, privacy: .public)"
        )
        fatalError("could not set ekv: " + error.localizedDescription)
      }
    }

    let publicIdentity: IdentityJSON?
    do {
      publicIdentity = try BindingsStatic.getPublicChannelIdentityFromPrivate(privateIdentity)
    } catch {
      AppLogger.identity.error(
        "could not derive public identity: \(error.localizedDescription, privacy: .public)"
      )
      fatalError("could not derive public identity: " + error.localizedDescription)
    }
    if let identity = publicIdentity {
      await MainActor.run {
        self.codeset = identity.CodesetVersion
        self.codename = identity.Codename
      }
    }

    await progress(.creatingIdentity)

    //

    // Notifications
    let notifications: Bindings.BindingsNotifications?
    do {
      notifications = try BindingsStatic.loadNotifications(cmix.getID())
    } catch {
      AppLogger.identity.error(
        "could not load notifications: \(error.localizedDescription, privacy: .public)"
      )
      fatalError("could not load notifications: " + error.localizedDescription)
    }
    guard let notifications
    else {
      AppLogger.identity.error("could not load notifications: returned nil")
      fatalError("could not load notifications: returned nil")
    }

    await progress(.syncingNotifications)

    //

    // Receivers

    do {
      let dmReceiver = DMReceiverBuilder()
      guard
        let dmClient = try BindingsStatic.newDMClient(
          cmixId: cmix.getID(),
          notifications: notifications,
          privateIdentity: privateIdentity,
          receiverBuilder: dmReceiver,
          dmReceiver: dmReceiver
        )
      else {
        AppLogger.identity.error("could not load dm client: returned nil")
        fatalError("could not load dm client: returned nil")
      }
      DM = BindingsDMClientWrapper(dmClient)
    } catch {
      AppLogger.identity.error(
        "could not load dm client: \(error.localizedDescription, privacy: .public)"
      )
      fatalError("could not load dm client: " + error.localizedDescription)
    }

    //
    await progress(.connectingToNodes)
    await progress(.settingUpRemoteKV)

    do {
      guard let kv = cmix.getRemoteKV()
      else {
        AppLogger.identity.error("getRemoteKV returned nil")
        fatalError("getRemoteKV returned nil")
      }
      remoteKV = kv
      storageTagListener = try RemoteKVKeyChangeListener(
        key: "channels-storage-tag",
        remoteKV: kv,
        version: 0,
        localEvents: true
      )
    } catch {
      AppLogger.identity.error(
        "failed to set storageTagListener: \(error.localizedDescription, privacy: .public)"
      )
      fatalError("failed to set storageTagListener \(error)")
    }

    await progress(.waitingForNetwork)

    do {
      await progress(.preparingChannelsManager)

      let extensionJSON = try JSONEncoder().encode([String]())

      if !(appStorage?.isSetupComplete ?? false) {
        let cm: Bindings.BindingsChannelsManager?
        do {
          cm = try BindingsStatic.newChannelsManager(
            cmixId: cmix.getID(),
            privateIdentity: privateIdentity,
            eventModelBuilder: eventModelBuilder,
            extensionJSON: extensionJSON,
            notiId: notifications.getID(),
            channelUICallbacks: channelUICallbacks
          )
        } catch {
          AppLogger.identity.error(
            "BindingsNewChannelsManager failed: \(error.localizedDescription, privacy: .public)"
          )
          fatalError("BindingsNewChannelsManager failed: \(error.localizedDescription)")
        }
        guard let cm
        else {
          AppLogger.identity.error("BindingsNewChannelsManager returned nil")
          fatalError("BindingsNewChannelsManager returned nil")
        }
        channelsManager = BindingsChannelsManagerWrapper(cm)
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let storageTagDataJson = try Parser.encode(channelsManager!.getStorageTag())
        let storageTagData = storageTagDataJson.base64EncodedString()
        let entry = RemoteKVEntry(
          Version: 0,
          Data: storageTagData,
          Timestamp: timestamp
        )
        let entryData = try Parser.encode(entry)
        guard let remoteKV, let channelsManager, let storageTagListener
        else {
          AppLogger.identity.error(
            "remoteKV/channelsManager/storageTagListener is nil"
          )
          fatalError("remoteKV/channelsManager/storageTagListener is nil")
        }
        try remoteKV.set("channels-storage-tag", objectJSON: entryData)
        // the data sometimes is not available in the listener immediately so we set it manually
        storageTagListener.data = channelsManager.getStorageTag().data
      } else {
        guard let storageTagListener, let storageTagData = storageTagListener.data
        else {
          AppLogger.identity.error("storageTagListener or its data is nil")
          fatalError("storageTagListener or its data is nil")
        }
        let storageTagString = try storageTagData.utf8()
        let cm: Bindings.BindingsChannelsManager?
        do {
          cm = try BindingsStatic.loadChannelsManager(
            cmixId: cmix.getID(),
            storageTag: storageTagString,
            eventModelBuilder: eventModelBuilder,
            extensionJSON: extensionJSON,
            notiId: notifications.getID(),
            channelUICallbacks: channelUICallbacks
          )
        } catch {
          AppLogger.identity.error(
            "BindingsLoadChannelsManager failed: \(error.localizedDescription, privacy: .public)"
          )
          fatalError("BindingsLoadChannelsManager failed: \(error.localizedDescription)")
        }
        guard let cm
        else {
          AppLogger.identity.error("BindingsLoadChannelsManager returned nil")
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
        let readinessInfo = try Parser.decode(IsReadyInfoJSON.self, from: readyData)
        if !readinessInfo.IsReady {
          try? await Task.sleep(nanoseconds: 2_000_000_000)
          continue
        } else {
          break
        }
      }
    } catch {
      fatalError("err \(error)")
    }

    guard let codename, let DM
    else {
      AppLogger.identity.error("codename/DM/modelContainer not there")
      fatalError("codename/DM/modelContainer not there")
    }
    if !codename.isEmpty {
      guard let selfPubKeyData = DM.getPublicKey()
      else {
        AppLogger.identity.error("self pub key data is nil")
        fatalError("self pub key data is nil")
      }
      let selfPubKeyB64 = selfPubKeyData.base64EncodedString()
      do {
        let existing = try await database.read { db in
          try ChatModel.where { $0.id.eq(selfPubKeyB64) }.fetchAll(db)
        }
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
          try await database.write { db in
            try ChatModel.insert { chat }.execute(db)
          }
        }
      } catch {
        AppLogger.home.error(
          "Failed to create self chat for \(codename, privacy: .public): \(error.localizedDescription, privacy: .public)"
        )
      }
    }
    do {
      let cd = try await joinChannelFromURL(XX_IOS_CHAT)
      let channelId = cd.ChannelID ?? "xxIOS"
      let existingChannel = try await database.read { db in
        try ChatModel.where { $0.id.eq(channelId) }.fetchAll(db)
      }
      if existingChannel.isEmpty {
        let channelChat = ChatModel(channelId: channelId, name: cd.Name)
        try await database.write { db in
          try ChatModel.insert { channelChat }.execute(db)
        }
      }
    } catch {
      AppLogger.home.error(
        "Failed to ensure initial channel xxIOS: \(error.localizedDescription, privacy: .public)"
      )
    }

    await MainActor.run {
      appStorage!.isSetupComplete = true
    }

    await progress(.ready)
  }

  /// Generate multiple channel identities
  func generateIdentities(amountOfIdentities: Int) -> [GeneratedIdentity] {
    guard let cmix
    else {
      AppLogger.identity.error("cmix is not available")
      return []
    }

    var identities: [GeneratedIdentity] = []

    for _ in 0 ..< amountOfIdentities {
      let privateIdentity: Data?
      do {
        privateIdentity = try BindingsStatic.generateChannelIdentity(cmix.getID())
      } catch {
        AppLogger.identity.error(
          "Failed to generate private identity: \(error.localizedDescription, privacy: .public)"
        )
        continue
      }

      guard let privateIdentity
      else {
        AppLogger.identity.error("Failed to generate private identity: returned nil")
        continue
      }

      let publicIdentity: IdentityJSON?
      do {
        publicIdentity = try BindingsStatic.getPublicChannelIdentityFromPrivate(
          privateIdentity
        )
      } catch {
        AppLogger.identity.error(
          "Failed to derive public identity: \(error.localizedDescription, privacy: .public)"
        )
        continue
      }

      guard let identity = publicIdentity
      else {
        AppLogger.identity.error("Failed to derive public identity: returned nil")
        continue
      }

      let generatedIdentity = GeneratedIdentity(
        privateIdentity: privateIdentity,
        codename: identity.Codename,
        codeset: identity.CodesetVersion,
        pubkey: identity.PubKey
      )

      identities.append(generatedIdentity)
    }

    return identities
  }

  /// Export identity with password encryption
  func exportIdentity(password _: String) throws -> Data {
    guard let cmix
    else {
      throw XXDKError.cmixNotInitialized
    }
    return try cmix.ekvGet("MyPrivateIdentity")
  }

  /// Import a private identity using a password
  func importIdentity(password: String, data: Data) throws -> Data {
    guard
      let imported = try BindingsStatic.importPrivateIdentity(password: password, data: data)
    else {
      throw XXDKError.importReturnedNil
    }
    return imported
  }
}
