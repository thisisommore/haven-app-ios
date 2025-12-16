import Foundation
import Bindings
import SwiftData

// NOTE:
// This is a stub implementation of the Channels UI callbacks used by the
// Bindings Channels Manager. The exact API surface of
// `BindingsChannelUICallbacksProtocol` depends on the version of the
// generated Bindings you have integrated. If any method signatures here do not
// match your local generated interface, Xcode will show errors — in that case,
// adjust the signatures to the ones your Bindings expect.
//
// For initial integration and testing, these callbacks simply print/log that
// they were invoked. Replace with your app logic as needed.

// Mirrors the JS ChannelEvents enum for readable event types.
enum ChannelEvent: Int64, CustomStringConvertible {
    case nicknameUpdate      = 1000
    case notificationUpdate  = 2000
    case messageReceived     = 3000
    case userMuted           = 4000
    case messageDeleted      = 5000
    case adminKeyUpdate      = 6000
    case dmTokenUpdate       = 7000
    case channelUpdate       = 8000

    var description: String {
        switch self {
        case .nicknameUpdate:     return "NICKNAME_UPDATE"
        case .notificationUpdate: return "NOTIFICATION_UPDATE"
        case .messageReceived:    return "MESSAGE_RECEIVED"
        case .userMuted:          return "USER_MUTED"
        case .messageDeleted:     return "MESSAGE_DELETED"
        case .adminKeyUpdate:     return "ADMIN_KEY_UPDATE"
        case .dmTokenUpdate:      return "DM_TOKEN_UPDATE"
        case .channelUpdate:      return "CHANNEL_UPDATE"
        }
    }
}

final class ChannelUICallbacks: NSObject, Bindings.BindingsChannelUICallbacksProtocol {

    // MARK: - Properties
    public var modelActor: SwiftDataActor?

    // MARK: - Debug Logging
    private let logPrefix = "[ChannelUICallbacks]"
    private func log(_ message: String) {
        print("\(logPrefix) \(message)")
    }

    private func short(_ data: Data?) -> String {
        guard let d = data else { return "nil" }
        let b64 = d.base64EncodedString()
        return b64.count > 16 ? String(b64.prefix(16)) + "…" : b64
    }

    // Pretty-print JSON from Data. If the data isn't valid JSON, try to interpret it
    // as a UTF-8 base64 string that itself contains JSON. Falls back to a short base64 preview.
    private func prettyJSONString(from data: Data?) -> String {
        guard let data = data else { return "nil" }

        // 1) Try raw JSON bytes first
        if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
           JSONSerialization.isValidJSONObject(jsonObject) == false || true { // allow any JSON object
            if let pretty = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted]),
               let prettyStr = String(data: pretty, encoding: .utf8) {
                return prettyStr
            }
        }

        // 2) If that failed, try to interpret the data as a UTF-8 string that is base64 of JSON
        if let asString = String(data: data, encoding: .utf8) {
            // Attempt base64 decode
            if let b64Data = Data(base64Encoded: asString) {
                if let jsonObject = try? JSONSerialization.jsonObject(with: b64Data, options: []),
                   let pretty = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted]),
                   let prettyStr = String(data: pretty, encoding: .utf8) {
                    return prettyStr
                }
            }
            // 3) If it's already UTF-8 JSON string, pretty print it by reparsing
            if let strData = asString.data(using: .utf8),
               let jsonObject = try? JSONSerialization.jsonObject(with: strData, options: []),
               let pretty = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted]),
               let prettyStr = String(data: pretty, encoding: .utf8) {
                return prettyStr
            }
        }

        // 4) Fallback
        return short(data)
    }

    override init() {
        super.init()
        log("init()")
    }

    public func configure(modelActor: SwiftDataActor? = nil) {
        log("configure(modelActor set: \(modelActor != nil))")
        self.modelActor = modelActor
    }

    public var modelContainer: ModelContainer?

    private func fetchOrCreateChannelChat(channelId: String, channelName: String, ctx: SwiftDataActor) throws -> ChatModelModel {
        log("fetchOrCreateChannelChat channelId=\(channelId) channelName=\(channelName)")
        let descriptor = FetchDescriptor<ChatModelModel>(predicate: #Predicate { $0.id == channelId })
        if let existing = try ctx.fetch(descriptor).first {
            log("found existing Chat id=\(existing.id) name=\(existing.name) messages=\(existing.messages.count)")
            return existing
        } else {
            let newChat = ChatModelModel(channelId: channelId, name: channelName)
            ctx.insert(newChat)
            log("inserting new Chat id=\(newChat.id) name=\(newChat.name)")
            try ctx.save()
            return newChat
        }
    }

    // Event notifications (generic JSON payloads)
    func eventUpdate(_ eventType: Int64, jsonData: Data?) {
        let eventName = ChannelEvent(rawValue: eventType)?.description ?? "UNKNOWN(\(eventType))"
        let utf8String = jsonData.flatMap { String(data: $0, encoding: .utf8) }
        if let s = utf8String {
            log("eventUpdate eventType=\(eventType) name=\(eventName) json(utf8)=\(s)")
        } else {
            log("eventUpdate eventType=\(eventType) name=\(eventName) json(fallback)=\(short(jsonData))")
        }
    }
}
