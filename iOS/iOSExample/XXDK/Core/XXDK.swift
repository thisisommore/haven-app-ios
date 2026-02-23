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
    var baseDir: URL
    var stateDir: URL

    var storageTagListener: RemoteKVKeyChangeListener?
    var remoteKV: Bindings.BindingsRemoteKV?
    var cmix: Bindings.BindingsCmix?
    var DM: Bindings.BindingsDMClient?
    var dmReceiver = DMReceiver()
    var eventModelBuilder: EventModelBuilder?
    var channelsManager: Bindings.BindingsChannelsManager?
    var channelUICallbacks: ChannelUICallbacks
    var sm: SecretManager?
    var modelActor: SwiftDataActor?
    var e2e: BindingsE2e?

    // MARK: - Init

    init() {
        channelUICallbacks = ChannelUICallbacks()

        let netTime = NetTime()
        Bindings.BindingsSetTimeSource(netTime)

        do {
            baseDir = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
        } catch {
            fatalError("failed to get documents directory: " + error.localizedDescription)
        }
        stateDir = XXDK.setupStateDirectories(baseDir: baseDir)
    }

    /// Creates (or recreates) the xxAppState/ekv directory structure and returns the ekv path.
    static func setupStateDirectories(baseDir: URL) -> URL {
        do {
            var dir = baseDir.appendingPathComponent("xxAppState")
            if !FileManager.default.fileExists(atPath: dir.path) {
                AppLogger.xxdk.info("Creating state directory: \(dir.path)")
                try FileManager.default.createDirectory(
                    at: dir,
                    withIntermediateDirectories: true
                )
            }
            dir = dir.appendingPathComponent("ekv")
            if !FileManager.default.fileExists(atPath: dir.path) {
                AppLogger.xxdk.info("Creating ekv directory: \(dir.path)")
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

    public func setModelContainer(mActor: SwiftDataActor, sm: SecretManager) {
        self.sm = sm
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
            var err: NSError?
            Bindings.BindingsDeleteCmixInstance(cmixId, &err)
            if let err { throw err }
        }

        // 4. Nil all binding objects
        channelsManager = nil
        DM = nil
        cmix = nil
        remoteKV = nil
        storageTagListener = nil
        eventModelBuilder = nil
        e2e = nil

        await MainActor.run { self.status = "Deleting data..." }
        // 5. Delete xxAppState (which contains ekv) and recreate it
        let appStateDir = baseDir.appendingPathComponent("xxAppState")
        guard FileManager.default.fileExists(atPath: appStateDir.path) else {
            throw MyError.appStateDirNotFound
        }
        try FileManager.default.removeItem(at: appStateDir)
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
        guard let dm = DM else {
            throw MyError.runtimeError("DM Client not initialized")
        }
        var err: NSError?
        let nickname = dm.getNickname(&err)
        if let err = err { throw err }
        return nickname
    }

    public func setDMNickname(_ nickname: String) throws {
        guard let dm = DM else {
            throw MyError.runtimeError("DM Client not initialized")
        }
        try dm.setNickname(nickname)
    }
}
