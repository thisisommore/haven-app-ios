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

        do {
        } catch {
            print(
                "SwiftData: Failed to delete all data at startup: \(error)"
            )
        }

        guard let sm else {
            fatalError("no secret manager")
        }
        let secret = try! sm.getPassword().data
        let defaultParamsJSON = Bindings.BindingsGetDefaultCMixParams()
        var params = try! Parser.decodeCMixParams(from: defaultParamsJSON ?? Data())

        params.Network.EnableImmediateSending = true
        let cmixParamsJSON = try! Parser.encodeCMixParams(params)
        if !(sm.isSetupComplete) {
            guard let downloadedNdf else {
                fatalError("no ndf downloaded yet")
            }
            await progress(.settingUpCmix)
            var err: NSError?
            Bindings.BindingsNewCmix(
                downloadedNdf.utf8,
                stateDir.path,
                secret,
                "",
                &err
            )
            if let err {
                print(
                    "ERROR: could not create new Cmix: "
                        + err.localizedDescription
                )
                fatalError(
                    "could not create new Cmix: " + err.localizedDescription
                )
            }
        }

        await progress(.loadingCmix)
        var err: NSError?
        let loadedCmix = Bindings.BindingsLoadCmix(
            stateDir.path,
            secret,
            cmixParamsJSON,
            &err
        )
        await MainActor.run {
            cmix = loadedCmix
        }
        if let err {
            print("ERROR: could not load Cmix: " + err.localizedDescription)
            fatalError("could not load Cmix: " + err.localizedDescription)
        }
    }

    func startNetworkFollower() async {
        lockTask()
        defer { unlockTask() }
        guard let cmix else {
            print("ERROR: cmix is not available")
            fatalError("cmix is not available")
        }
        await progress(.startingNetworkFollower)

        do {
            try cmix.startNetworkFollower(50000)
            cmix.wait(forNetwork: 10 * 60 * 1000)
        } catch {
            print("ERROR: cannot start network: " + error.localizedDescription)
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
            print(
                "ERROR: Missing network certificate, please include a mainnet, testnet,or localnet certificate in the Resources folder: "
                    + error.localizedDescription
            )
            fatalError(
                "Missing network certificate, please include a mainnet, testnet,"
                    + "or localnet certificate in the Resources folder: "
                    + error.localizedDescription
            )
        }

        var err: NSError?
        let ndf = Bindings.BindingsDownloadAndVerifySignedNdfWithUrl(
            url,
            certString,
            &err
        )
        if let err {
            print(
                "ERROR: DownloadAndverifySignedNdfWithUrl(\(url), \(certString)) error: "
                    + err.localizedDescription
            )
            fatalError(
                "DownloadAndverifySignedNdfWithUrl(\(url), \(certString)) error: "
                    + err.localizedDescription
            )
        }
        return ndf!
    }
}
