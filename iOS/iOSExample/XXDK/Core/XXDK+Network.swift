//
//  XXDK+Network.swift
//  iOSExample
//

import Bindings
import Foundation

extension XXDK {
    func downloadNdf() async {
        lockTask()
        defer { unlockTask() }
        await progress(.downloadingNDF)

        downloadedNdf = downloadNDF(
            url: MAINNET_URL,
            certFilePath: MAINNET_CERT
        )
    }

    func setUpCmix() async {
        lockTask()
        defer { unlockTask() }

        guard let appStorage else {
            fatalError("no secret manager")
        }
        let secret = try! appStorage.getPassword().data
        let defaultParamsJSON = Bindings.BindingsGetDefaultCMixParams()
        var params = try! Parser.decode(CMixParamsJSON.self, from: defaultParamsJSON ?? Data())

        params.Network.EnableImmediateSending = true
        let cmixParamsJSON = try! Parser.encode(params)
        if !(appStorage.isSetupComplete) {
            guard let downloadedNdf else {
                fatalError("no ndf downloaded yet")
            }
            await progress(.settingUpCmix)
            do {
                try BindingsStatic.newCmix(ndf: downloadedNdf, stateDir: stateDir.path, secret: secret, backup: "")
            } catch {
                AppLogger.network.critical("could not create new Cmix: \(error.localizedDescription, privacy: .public)")
                fatalError("could not create new Cmix: " + error.localizedDescription)
            }
        }

        await progress(.loadingCmix)
        let loadedCmix: Bindings.BindingsCmix?
        do {
            loadedCmix = try BindingsStatic.loadCmix(stateDir: stateDir.path, secret: secret, paramsJSON: cmixParamsJSON)
        } catch {
            AppLogger.network.critical("could not load Cmix: \(error.localizedDescription, privacy: .public)")
            fatalError("could not load Cmix: " + error.localizedDescription)
        }
        await MainActor.run {
            cmix = loadedCmix
        }
    }

    func startNetworkFollower() async {
        lockTask()
        defer { unlockTask() }
        guard let cmix else {
            AppLogger.network.critical("cmix is not available")
            fatalError("cmix is not available")
        }
        await progress(.startingNetworkFollower)

        do {
            try cmix.startNetworkFollower(50000)
            cmix.wait(forNetwork: 10 * 60 * 1000)
        } catch {
            AppLogger.network.critical("cannot start network: \(error.localizedDescription, privacy: .public)")
            fatalError("cannot start network: " + error.localizedDescription)
        }

        await progress(.networkFollowerComplete)
    }

    // downloadNdf uses the mainnet URL to download and verify the
    // network definition file for the xx network.
    func downloadNDF(url: String, certFilePath: String) -> Data {
        let certString: String
        do {
            certString = try String(contentsOfFile: certFilePath)
        } catch {
            AppLogger.network.critical("Missing network certificate: \(error.localizedDescription, privacy: .public)")
            fatalError(
                "Missing network certificate, please include a mainnet, testnet,"
                    + "or localnet certificate in the Resources folder: "
                    + error.localizedDescription
            )
        }

        do {
            guard let ndf = try BindingsStatic.downloadAndVerifySignedNdf(url: url, cert: certString) else {
                AppLogger.network.critical("DownloadAndVerifySignedNdfWithUrl returned nil")
                fatalError("DownloadAndVerifySignedNdfWithUrl returned nil")
            }
            return ndf
        } catch {
            AppLogger.network.critical("DownloadAndVerifySignedNdfWithUrl failed: \(error.localizedDescription, privacy: .public)")
            fatalError("DownloadAndVerifySignedNdfWithUrl failed: " + error.localizedDescription)
        }
    }
}
