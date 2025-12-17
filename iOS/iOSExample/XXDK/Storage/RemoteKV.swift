//
//  RemoteKV.swift
//  iOSExample
//
//  Created by Om More on 24/09/25.
//
import Bindings
import Kronos
import OSLog

final class RemoteKVKeyChangeListener: NSObject, Bindings.BindingsKeyChangedByRemoteCallbackProtocol {
    let key: String
    var data: Data?
    private var handle: Int = 0
    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.example.app",
                             category: "RemoteKV")

    // Convenience initializer that starts listening immediately
    init(key: String, remoteKV: Bindings.BindingsRemoteKV, version: Int64 = 0, localEvents: Bool = true) throws {
        self.key = key
        data = nil
        super.init()
        try remoteKV.listen(onRemoteKey: key, version: version, callback: self, localEvents: localEvents, ret0_: &handle)
        do {
            let v = try remoteKV.get(key, version: version)

            // Decode the initial data and store the decoded entry
            do {
                let entry = try Parser.decodeRemoteKVEntry(from: v)
                data = entry.Data.data
                log.debug("RemoteKV initial get succeeded for key: \(self.key, privacy: .public) - Version: \(entry.Version), Timestamp: \(entry.Timestamp), Data length: \(entry.Data.count)")
            } catch {
                log.warning("Failed to decode initial RemoteKV entry: \(error.localizedDescription)")
                data = nil
            }
        } catch {
            log.warning("RemoteKV initial get failed for key: \(self.key, privacy: .public) — \(String(describing: error), privacy: .public)")
        }
    }

    // Called by the Bindings RemoteKV when the key changes. Adjust the method name/signature
    // if the generated Swift interface differs.
    func callback(_: String?, old: Data?, new: Data?, opType _: Int8) {
        log.info("RemoteKV new data for \(self.key), new: \(new!.base64EncodedString()), old: \(old!.base64EncodedString())")
        if new!.base64EncodedString() == "bnVsbA==", old!.base64EncodedString() == "bnVsbA==" {
            return
        }
        // Decode the new data if available and store the decoded entry
        if let newData = new {
            do {
                let entry = try Parser.decodeRemoteKVEntry(from: newData)
                data = try Parser.decodeString(from: Data(base64Encoded: entry.Data)!).data
                log.debug("Decoded RemoteKV entry - Version: \(entry.Version), Timestamp: \(entry.Timestamp), Data length: \(entry.Data.count)")
            } catch {
                fatalError("Failed to decode RemoteKV entry: \(error.localizedDescription)")
            }
        } else {
            data = nil
        }
    }
}
