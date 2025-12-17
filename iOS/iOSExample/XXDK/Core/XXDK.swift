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
    var DM: Bindings.BindingsDMClient?
    var dmReceiver = DMReceiver()
    var eventModelBuilder: EventModelBuilder?
    var channelsManager: Bindings.BindingsChannelsManager?
    var channelUICallbacks: ChannelUICallbacks
    var sm: SecretManager?
    var modelActor: SwiftDataActor?
    var e2e: BindingsE2e?
    var channelsFileTransfer: ChannelsFileTransfer?

    private var fileDownloadObserver: Any?

    // MARK: - Init

    init() {
        channelUICallbacks = ChannelUICallbacks()

        let netTime = NetTime()
        Bindings.BindingsSetTimeSource(netTime)

        do {
            let basePath = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
            stateDir = basePath.appendingPathComponent("xxAppState")
            if !FileManager.default.fileExists(atPath: stateDir.path) {
                try FileManager.default.createDirectory(
                    at: stateDir,
                    withIntermediateDirectories: true
                )
            }
            stateDir = stateDir.appendingPathComponent("ekv")
            if !FileManager.default.fileExists(atPath: stateDir.path) {
                try FileManager.default.createDirectory(
                    at: stateDir,
                    withIntermediateDirectories: true
                )
                print("📂 Created ekv directory: \(stateDir.path)")
            }

            print("📂 Using ekv directory: \(stateDir.path)")
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

        setupFileDownloadObserver()
    }

    private func setupFileDownloadObserver() {
        fileDownloadObserver = NotificationCenter.default.addObserver(
            forName: .fileDownloadNeeded,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleFileDownloadNeeded(notification)
        }
    }

    // MARK: - Logout

    public func logout() async {
        try! cmix?.stopNetworkFollower()

        channelsManager = nil
        DM = nil
        cmix = nil
        remoteKV = nil
        storageTagListener = nil
        eventModelBuilder = nil
        e2e = nil

        let basePath = try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )

        if let basePath {
            let appStateDir = basePath.appendingPathComponent("xxAppState")
            try? FileManager.default.removeItem(at: appStateDir)

            let contents = try? FileManager.default.contentsOfDirectory(at: basePath, includingPropertiesForKeys: nil)
            contents?.forEach { url in
                let name = url.lastPathComponent
                if name.contains("channel") || name.contains("dm") || name.hasPrefix("xx") {
                    try? FileManager.default.removeItem(at: url)
                }
            }
        }

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
