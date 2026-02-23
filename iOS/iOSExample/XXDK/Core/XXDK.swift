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

public class XXDK: XXDKP {
    // MARK: - Published Properties

    @Published var status: String = "..."
    @Published var statusPercentage: Double = 0
    @Published var codename: String?
    @Published var codeset: Int = 0

    // MARK: - Internal Properties (accessible by extensions)

    var downloadedNdf: Data?
    var nsLock = NSLock()
    var stateDir: URL

    var storageTagListener: RemoteKVKeyChangeListener?
    var remoteKV: Bindings.BindingsRemoteKV?
    var cmix: Bindings.BindingsCmix?
    var DM: BindingsDMClientWrapper?
    var dmReceiver = DMReceiver()
    var eventModelBuilder: EventModelBuilder?
    var channelsManager: BindingsChannelsManagerWrapper?
    var channelUICallbacks: ChannelUICallbacks
    var appStorage: AppStorage?
    var modelActor: SwiftDataActor?

    // MARK: - Init

    init() {
        channelUICallbacks = ChannelUICallbacks()

        let netTime = NetTime()
        Bindings.BindingsSetTimeSource(netTime)

        do {
            let baseDir = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
            stateDir = XXDK.setupStateDirectories(baseDir: baseDir)
        } catch {
            fatalError("failed to get documents directory: " + error.localizedDescription)
        }
    }

    /// Creates (or recreates) the xxAppState directory and returns its path.
    static func setupStateDirectories(baseDir: URL) -> URL {
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

    public func setModelContainer(mActor: SwiftDataActor, sm: AppStorage) {
        appStorage = sm
        modelActor = mActor
        dmReceiver.modelActor = mActor
        channelUICallbacks.configure(modelActor: mActor)
        eventModelBuilder?.configure(modelActor: mActor)
    }

    // MARK: - Logout

    public func logout() async throws {
        await MainActor.run { self.status = "Stopping network follower..." }
        // 1. Stop network follower
        try! cmix?.stopNetworkFollower()

        await MainActor.run { self.status = "Waiting for processes..." }
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

        await MainActor.run { self.status = "Cleaning up..." }
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
        eventModelBuilder = nil

        await MainActor.run { self.status = "Deleting data..." }
        // 5. Delete stateDir and recreate it
        guard FileManager.default.fileExists(atPath: stateDir.path) else {
            throw XXDKError.appStateDirNotFound
        }
        try FileManager.default.removeItem(at: stateDir)
        let baseDir = stateDir.deletingLastPathComponent()
        stateDir = XXDK.setupStateDirectories(baseDir: baseDir)
        downloadedNdf = nil

        await MainActor.run {
            self.codename = nil
            self.codeset = 0
            self.status = "..."
            self.statusPercentage = 0
        }
    }

    // MARK: - DM Nickname

    public func getDMNickname() throws -> String {
        guard let DM else {
            throw XXDKError.dmClientNotInitialized
        }
        return try DM.getNickname()
    }

    public func setDMNickname(_ nickname: String) throws {
        guard let DM else {
            throw XXDKError.dmClientNotInitialized
        }
        try DM.setNickname(nickname)
    }
}
