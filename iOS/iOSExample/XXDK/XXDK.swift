//
//  XXDK.swift
//  iOSExample
//
//  Created by Richard Carback on 3/6/24.
//

import Bindings
import Foundation
import Kronos
import SQLiteData
import SwiftUI

final class XXDK: XXDKP {
  @Published var status: String = "..."
  @Published var statusPercentage: Double = 0
  @Published var codename: String?
  @Published var codeset: Int = 0
  @Dependency(\.defaultDatabase) var database
  var _channels: Channel?
  var channel: Channel {
    if let _channels {
      return _channels
    }
    fatalError("Channels is not defined")
  }

  var _dm: DirectMessage?
  var dm: DirectMessage? {
    if let _dm {
      return _dm
    }
    return nil
  }

  var downloadedNdf: Data?
  var stateDir: URL

  var storageTagListener: RemoteKVKeyChangeListener?
  var remoteKV: Bindings.BindingsRemoteKV?
  var cmix: Bindings.BindingsCmix?
  var eventModelBuilder = ChannelEventModelBuilder()
  var channelUICallbacks: ChannelUICallbacks
  var appStorage: AppStorage?

  // MARK: - Init

  init() {
    self.channelUICallbacks = ChannelUICallbacks()

    Bindings.BindingsSetTimeSource(NetTime())

    do {
      self.stateDir = try XXDK.setupStateDirectories()
    } catch {
      fatalError("failed to get documents directory: " + error.localizedDescription)
    }
  }
}


extension XXDK {
    /// Creates (or recreates) the xxAppState directory and returns its path.
    private static func setupStateDirectories() throws -> URL {
      let baseDir = try FileManager.default.url(
        for: .documentDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: false
      )
      do {
        let dir = baseDir.appendingPathComponent("xxAppState")
        if !FileManager.default.fileExists(atPath: dir.path) {
          try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
          )
        }
        return dir
      } catch let err {
        fatalError(
          "failed to get state directory: " + err.localizedDescription
        )
      }
    }

    // MARK: - Model Container Setup

    func setStates(appStorage: AppStorage) {
      self.appStorage = appStorage
    }

    // MARK: - Logout

    func logout() async throws {
      // 1. Stop network follower
      try! self.cmix?.stopNetworkFollower()

      // 2. Wait for all running processes to finish
      var retryCount = 0
      while self.cmix?.hasRunningProcessies() == true {
        if retryCount > 30 { // 3 seconds timeout
          AppLogger.xxdk.warning("Force stopping processes after timeout")
          break
        }
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        retryCount += 1
      }

      // 3. Remove cmix from Go-side tracker to release references
      if let cmixId = cmix?.getID() {
        try BindingsStatic.deleteCmixInstance(cmixId)
      }

      // 4. Nil all binding objects
      self._channels = nil
      self._dm = nil
      self.cmix = nil
      self.remoteKV = nil
      self.storageTagListener = nil

      // 5. Clear caches
      ReceiverHelpers.clearSelfChatCache()

      // 6. Delete stateDir and recreate it
      guard FileManager.default.fileExists(atPath: self.stateDir.path)
      else {
        throw XXDKError.appStateDirNotFound
      }
      try FileManager.default.removeItem(at: self.stateDir)
      // this is created in init and therefore should be called here or else app will crash during setup
      self.stateDir = try XXDK.setupStateDirectories()

      await MainActor.run {
        self.codename = nil
        self.codeset = 0
        self.status = "..."
        self.statusPercentage = 0
      }
    }
    
    func downloadNdf() async {
      await progress(.downloadingNDF)

      downloadedNdf = self.downloadNDF(
        url: MAINNET_URL,
        certFilePath: MAINNET_CERT
      )
    }

    func setUpCmix() async {
      guard let appStorage
      else {
        fatalError("no secret manager")
      }
      let secret = try! appStorage.getPassword().data

      let defaultParamsJSON = Bindings.BindingsGetDefaultCMixParams()
      var params = try! Parser.decode(CMixParamsJSON.self, from: defaultParamsJSON ?? Data())

      params.Network.EnableImmediateSending = true
      let cmixParamsJSON = try! Parser.encode(params)
      if !(appStorage.isSetupComplete) {
        guard let downloadedNdf
        else {
          fatalError("no ndf downloaded yet")
        }
        await progress(.settingUpCmix)
        do {
          try BindingsStatic.newCmix(
            ndf: downloadedNdf, stateDir: stateDir.path, secret: secret, backup: ""
          )
        } catch {
          AppLogger.network.error(
            "could not create new Cmix: \(error.localizedDescription, privacy: .public)"
          )
          fatalError("could not create new Cmix: " + error.localizedDescription)
        }
      }

      await progress(.loadingCmix)
      let loadedCmix: Bindings.BindingsCmix?
      do {
        loadedCmix = try BindingsStatic.loadCmix(
          stateDir: stateDir.path, secret: secret, paramsJSON: cmixParamsJSON
        )
      } catch {
        AppLogger.network.error(
          "could not load Cmix: \(error.localizedDescription, privacy: .public)"
        )
        fatalError("could not load Cmix: " + error.localizedDescription)
      }
      await MainActor.run {
        cmix = loadedCmix
      }
    }

    func startNetworkFollower() async {
      guard let cmix
      else {
        AppLogger.network.error("cmix is not available")
        fatalError("cmix is not available")
      }
      await progress(.startingNetworkFollower)

      do {
        try cmix.startNetworkFollower(50000)
        cmix.wait(forNetwork: 10 * 60 * 1000)
      } catch {
        AppLogger.network.error(
          "cannot start network: \(error.localizedDescription, privacy: .public)"
        )
        fatalError("cannot start network: " + error.localizedDescription)
      }

      await progress(.networkFollowerComplete)
    }

    /// downloadNdf uses the mainnet URL to download and verify the
    /// network definition file for the xx network.
    private func downloadNDF(url: String, certFilePath: String) -> Data {
      let certString: String
      do {
        certString = try String(contentsOfFile: certFilePath)
      } catch {
        AppLogger.network.error(
          "Missing network certificate: \(error.localizedDescription, privacy: .public)"
        )
        fatalError(
          "Missing network certificate, please include a mainnet, testnet,"
            + "or localnet certificate in the Resources folder: "
            + error.localizedDescription
        )
      }

      do {
        guard
          let ndf = try BindingsStatic.downloadAndVerifySignedNdf(url: url, cert: certString)
        else {
          AppLogger.network.error("DownloadAndVerifySignedNdfWithUrl returned nil")
          fatalError("DownloadAndVerifySignedNdfWithUrl returned nil")
        }
        return ndf
      } catch {
        AppLogger.network.error(
          "DownloadAndVerifySignedNdfWithUrl failed: \(error.localizedDescription, privacy: .public)"
        )
        fatalError("DownloadAndVerifySignedNdfWithUrl failed: " + error.localizedDescription)
      }
    }

}
