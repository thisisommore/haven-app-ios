import Bindings
import Foundation
import HavenCore
import SQLiteData

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

/// Mirrors the JS ChannelEvents enum for readable event types.
enum ChannelEvent: Int64, CustomStringConvertible {
  case nicknameUpdate = 1000
  case notificationUpdate = 2000
  case messageReceived = 3000
  case userMuted = 4000
  case messageDeleted = 5000
  case adminKeyUpdate = 6000
  case dmTokenUpdate = 7000
  case channelUpdate = 8000

  var description: String {
    switch self {
    case .nicknameUpdate: return "NICKNAME_UPDATE"
    case .notificationUpdate: return "NOTIFICATION_UPDATE"
    case .messageReceived: return "MESSAGE_RECEIVED"
    case .userMuted: return "USER_MUTED"
    case .messageDeleted: return "MESSAGE_DELETED"
    case .adminKeyUpdate: return "ADMIN_KEY_UPDATE"
    case .dmTokenUpdate: return "DM_TOKEN_UPDATE"
    case .channelUpdate: return "CHANNEL_UPDATE"
    }
  }
}

final class ChannelUICallbacks: NSObject, Bindings.BindingsChannelUICallbacksProtocol {
  @Dependency(\.defaultDatabase) var database
  private func storeNotificationSettings(_ states: [ChannelNotificationStateJSON]) {
    guard !states.isEmpty else { return }

    do {
      try self.database.write { db in
        for state in states {
          guard let channelId = state.channelID?.base64EncodedString(), var chat = try (ChatModel.where { $0.channelId.eq(channelId) }.fetchOne(db)),
                !chat.isSelfChat
          else {
            continue
          }
          let level = NotificationLevel(rawValue: state.level) ?? .none

          chat.notificationLevel = level
          try ChatModel.update(chat).execute(db)
        }
      }
    } catch {
      AppLogger.messaging.error(
        "Failed to cache DM notification update: \(error.localizedDescription, privacy: .public)"
      )
    }
  }

  func eventUpdate(_ eventType: Int64, jsonData: Data?) {
    guard let jsonData
    else {
      return
    }

    switch ChannelEvent(rawValue: eventType) {
    case .notificationUpdate:
      let update = try! Parser.decode(ChannelNotificationUpdateJSON.self, from: jsonData)
      UserDefaults(suiteName: GROUP_ID)?
        .set(jsonData,
             forKey: USER_DEFAULT_CHANNEL_NOTIFICATION_FILTER_KEY)
      if let changedNoti = update.changedNotificationStates {
        self.storeNotificationSettings(changedNoti)
      }

    default:
      break
    }
  }
}
