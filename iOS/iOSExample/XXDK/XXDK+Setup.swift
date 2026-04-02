//
//  XXDK+Setup.swift
//  iOSExample
//

import Bindings
import Foundation
import SQLiteData

extension XXDK {
  /// Loads dm and channels manager
  func loadClients(privateIdentity: Data) async {
    // Cmix
    guard let cmix
    else {
      AppLogger.identity.error("cmix is not available")
      fatalError("cmix is not available")
    }

    await progress(.loadingIdentity)

    let publicIdentity: IdentityJSON?
    do {
      publicIdentity = try BindingsStatic.getPublicChannelIdentityFromPrivate(privateIdentity)
    } catch {
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
      fatalError("could not load notifications: " + error.localizedDescription)
    }
    guard let notifications
    else {
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
        fatalError("could not load dm client: returned nil")
      }
      _dm = DirectMessage(DM: BindingsDMClientWrapper(dmClient))
    } catch {
      fatalError("could not load dm client: " + error.localizedDescription)
    }

    //
    await progress(.connectingToNodes)
    await progress(.settingUpRemoteKV)

    do {
      guard let kv = cmix.getRemoteKV()
      else {
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
      fatalError("failed to set storageTagListener \(error)")
    }

    await progress(.waitingForNetwork)

    do {
      await progress(.preparingChannelsManager)

      let extensionJSON = try JSONEncoder().encode([String]())

      guard let storageTagListener, let storageTagData = storageTagListener.data
      else {
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
        fatalError("BindingsLoadChannelsManager failed: \(error.localizedDescription)")
      }
      guard let cm
      else {
        fatalError("BindingsLoadChannelsManager returned nil")
      }
      _channels = Channel(channelsManager: BindingsChannelsManagerWrapper(cm), cmixId: cmix.getID())

      await progress(.readyExistingUser)

    } catch {
      fatalError("err \(error)")
    }
  }

  func setupClients(privateIdentity: Data, successCallback: () -> Void) async {
    defer { successCallback() }
    // Cmix
    guard let cmix
    else {
      AppLogger.identity.error("cmix is not available")
      fatalError("cmix is not available")
    }

    await progress(.loadingIdentity)

    let publicIdentity: IdentityJSON?
    do {
      publicIdentity = try BindingsStatic.getPublicChannelIdentityFromPrivate(privateIdentity)
    } catch {
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
      fatalError("could not load notifications: " + error.localizedDescription)
    }
    guard let notifications
    else {
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
        fatalError("could not load dm client: returned nil")
      }
      _dm = DirectMessage(DM: BindingsDMClientWrapper(dmClient))
    } catch {
      fatalError("could not load dm client: " + error.localizedDescription)
    }

    //
    await progress(.connectingToNodes)
    await progress(.settingUpRemoteKV)

    do {
      guard let kv = cmix.getRemoteKV()
      else {
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
      fatalError("failed to set storageTagListener \(error)")
    }

    await progress(.waitingForNetwork)

    do {
      await progress(.preparingChannelsManager)

      let extensionJSON = try JSONEncoder().encode([String]())

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
        fatalError("BindingsNewChannelsManager failed: \(error.localizedDescription)")
      }
      guard let cm
      else {
        AppLogger.identity.error("BindingsNewChannelsManager returned nil")
        fatalError("BindingsNewChannelsManager returned nil")
      }
      let channelsManager = BindingsChannelsManagerWrapper(cm)
      _channels = Channel(channelsManager: channelsManager, cmixId: cmix.getID())
      let timestamp = ISO8601DateFormatter().string(from: Date())
      let storageTagDataJson = try Parser.encode(channelsManager.getStorageTag())
      let storageTagData = storageTagDataJson.base64EncodedString()
      let entry = RemoteKVEntry(
        Version: 0,
        Data: storageTagData,
        Timestamp: timestamp
      )
      let entryData = try Parser.encode(entry)
      guard let remoteKV, let storageTagListener
      else {
        fatalError("remoteKV/channelsManager/storageTagListener is nil")
      }
      try remoteKV.set("channels-storage-tag", objectJSON: entryData)
      // the data sometimes is not available in the listener immediately so we set it manually
      storageTagListener.data = channelsManager.getStorageTag().data

      if appStorage.isSetupComplete {
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

    guard let codename, let dm
    else {
      fatalError("codename/DM/modelContainer not there")
    }
    if !codename.isEmpty {
      guard let selfPubKeyData = dm.getPublicKey()
      else {
        AppLogger.identity.error("self pub key data is nil")
        fatalError("self pub key data is nil")
      }
      do {
        let existing = try await database.read { db in
          try ChatModel.where { $0.pubKey.eq(selfPubKeyData) }.fetchAll(db)
        }
        if existing.isEmpty {
          let token64 = dm.getToken()
          let tokenU32 = UInt32(truncatingIfNeeded: token64)
          let selfToken = Int32(bitPattern: tokenU32)
          let chat = ChatModel(
            pubKey: selfPubKeyData,
            name: "<self>",
            dmToken: selfToken,
            color: 0xE97451
          )
          let sender = MessageSenderModel.selfSender(pubkey: selfPubKeyData)
          try await database.write { db in
            try ChatModel.insert { chat }.execute(db)
            try MessageSenderModel.insert { sender }.execute(db)
          }
        }
      } catch {
        AppLogger.home.error(
          "Failed to create self chat for \(codename, privacy: .public): \(error.localizedDescription, privacy: .public)"
        )
      }
    }
    do {
      let cd = try await channel.join(url: XX_IOS_CHAT)
      let channelId = cd.ChannelID ?? "xxIOS"
      let existingChannel = try await database.read { db in
        try ChatModel.where { $0.channelId.eq(channelId) }.fetchAll(db)
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
      appStorage.isSetupComplete = true
    }

    await progress(.ready)
  }
}
