//
//  XXDK.swift
//  iOSExample
//
//  Created by Richard Carback on 3/6/24.
//

import Bindings
import Foundation
import Kronos
import SwiftData
import SwiftUI

class XXDK: XXDKP {
    @Published var status: String = "..."
    @Published var statusPercentage: Double = 0
    @Published var codename: String?
    @Published var codeset: Int = 0

    var downloadedNdf: Data?
    var nsLock = NSLock()
    var stateDir: URL

    var storageTagListener: RemoteKVKeyChangeListener?
    var remoteKV: Bindings.BindingsRemoteKV?
    var cmix: Bindings.BindingsCmix?
    var DM: BindingsDMClientWrapper?
    var dmReceiver = DMReceiver()
    var eventModelBuilder = ChannelEventModelBuilder(
        model: ChannelEventModel()
    )
    var channelsManager: BindingsChannelsManagerWrapper?
    var channelUICallbacks: ChannelUICallbacks
    var appStorage: AppStorage?
    var modelActor: SwiftDataActor?

    // MARK: - Init

    init() {
        channelUICallbacks = ChannelUICallbacks()

        Bindings.BindingsSetTimeSource(NetTime())

        do {
            stateDir = try XXDK.setupStateDirectories()
        } catch {
            fatalError("failed to get documents directory: " + error.localizedDescription)
        }
    }

    /// Creates (or recreates) the xxAppState directory and returns its path.
    static func setupStateDirectories() throws -> URL {
        let baseDir = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        do {
            let dir = baseDir.appendingPathComponent("xxAppState")
            if !FileManager.default.fileExists(atPath: dir.path) {
                AppLogger.xxdk.info("Creating state directory: \(dir.path)")
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

    func setStates(mActor: SwiftDataActor, appStorage: AppStorage) {
        self.appStorage = appStorage
        modelActor = mActor
        dmReceiver.modelActor = mActor
        channelUICallbacks.configure(modelActor: mActor)
        eventModelBuilder.configure(modelActor: mActor)
    }

    // MARK: - Logout

    func logout() async throws {
        // 1. Stop network follower
        try! cmix?.stopNetworkFollower()

        // 2. Wait for all running processes to finish
        var retryCount = 0
        while cmix?.hasRunningProcessies() == true {
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
        channelsManager = nil
        DM = nil
        cmix = nil
        remoteKV = nil
        storageTagListener = nil

        // 5. Clear caches
        ReceiverHelpers.clearSelfChatCache()

        // 6. Delete stateDir and recreate it
        guard FileManager.default.fileExists(atPath: stateDir.path) else {
            throw XXDKError.appStateDirNotFound
        }
        try FileManager.default.removeItem(at: stateDir)
        // this is created in init and therefore should be called here or else app will crash during setup
        stateDir = try XXDK.setupStateDirectories()

        await MainActor.run {
            self.codename = nil
            self.codeset = 0
            self.status = "..."
            self.statusPercentage = 0
        }
    }

    func getDMNickname() throws -> String {
        guard let DM else {
            throw XXDKError.dmClientNotInitialized
        }
        return try DM.getNickname()
    }

    func setDMNickname(_ nickname: String) throws {
        guard let DM else {
            throw XXDKError.dmClientNotInitialized
        }
        try DM.setNickname(nickname)
    }
}
