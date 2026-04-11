//
//  ChannelOptionsView+Controller.swift
//  iOSExample
//
//  Created by Om More
//

import HavenCore
import Observation
import SQLiteData
import SwiftUI

enum ChannelOptionsActiveSheet: Identifiable {
  case exportKey
  case importKey

  var id: String {
    switch self {
    case .exportKey:
      return "exportKey"
    case .importKey:
      return "importKey"
    }
  }
}

@MainActor
@Observable
final class ChannelOptionsController {
  var isDMEnabled: Bool = false
  var shareURL: String?
  var sharePassword: String?
  var activeSheet: ChannelOptionsActiveSheet?
  var toastMessage: String?
  var showLeaveConfirmation: Bool = false
  var showDeleteConfirmation: Bool = false
  var channelNickname: String = ""
  var notificationsLevel: NotificationLevel = .none

  func notificationsLevels(for chat: ChatModel) -> [NotificationLevel] {
    chat.isChannel ? [.all, .none, .ping] : [.none, .all]
  }

  @ObservationIgnored
  @Dependency(\.defaultDatabase) var database

  func onAppear<T: XXDKP>(channelId: String?, chat: ChatModel, xxdk: T) {
    self.notificationsLevel = chat.notificationLevel

    if chat.isSelfChat {
      self.notificationsLevel = .none
      return
    }

    if let pubKey = chat.pubKey {
      do {
        if let level = try xxdk.dm?.getNotificationSettings(pubKey: pubKey) {
          self.notificationsLevel = level
        }
      } catch {
        AppLogger.messaging.error(
          "Failed to fetch DM notification settings: \(error.localizedDescription, privacy: .public)"
        )
      }
      return
    }

    guard let channelId else { return }

    do {
      self.isDMEnabled = try xxdk.channel.areDMsEnabled(channelId: channelId)
    } catch {
      AppLogger.channels.error(
        "Failed to fetch DM status: \(error.localizedDescription, privacy: .public)"
      )
      self.isDMEnabled = false
    }

    do {
      let shareData = try xxdk.channel.getShareURL(
        channelId: channelId, host: "https://xxnetwork.com/join"
      )
      self.shareURL = shareData.url
      self.sharePassword = shareData.password
    } catch {
      AppLogger.channels.error(
        "Failed to fetch share URL: \(error.localizedDescription, privacy: .public)"
      )
    }

    do {
      self.channelNickname = try xxdk.channel.getNickname(channelId: channelId)
    } catch {
      AppLogger.channels.error(
        "Failed to fetch channel nickname: \(error.localizedDescription, privacy: .public)"
      )
    }

    do {
      self.notificationsLevel = try xxdk.channel.getNotificationSettings(channelId: channelId)
    } catch {
      AppLogger.channels.error(
        "Failed to fetch notification settings: \(error.localizedDescription, privacy: .public)"
      )
    }
  }

  func updateChannelNickname(_ newValue: String) {
    if newValue.count > 24 {
      self.channelNickname = String(newValue.prefix(24))
      return
    }
    self.channelNickname = newValue
  }

  func toggleDirectMessages<T: XXDKP>(
    oldValue: Bool, newValue: Bool, channelId: String?, xxdk: T
  ) {
    guard let channelId else { return }
    do {
      if newValue {
        try xxdk.channel.enableDirectMessages(channelId: channelId)
      } else {
        try xxdk.channel.disableDirectMessages(channelId: channelId)
      }
    } catch {
      AppLogger.channels.error(
        "Failed to toggle DM: \(error.localizedDescription, privacy: .public)"
      )
      self.isDMEnabled = oldValue
    }
  }

  func unmuteUser<T: XXDKP>(pubKey: Data, channelId: String?, xxdk: T) {
    guard let channelId else { return }
    do {
      try xxdk.channel.muteUser(channelId: channelId, pubKey: pubKey, mute: false)
      self.showToast("User unmuted")
    } catch {
      AppLogger.channels.error(
        "Failed to unmute user: \(error.localizedDescription, privacy: .public)"
      )
    }
  }

  func setNotificationsLevel<T: XXDKP>(
    _ level: NotificationLevel,
    chat: ChatModel,
    xxdk: T
  ) {
    guard !chat.isSelfChat else { return }
    guard chat.channelId != nil || (chat.pubKey != nil && xxdk.dm != nil) else { return }

    do {
      if let channelId = chat.channelId {
        try xxdk.channel.setNotifications(channelId: channelId, level: level)
      } else if let pubKey = chat.pubKey, let dm = xxdk.dm {
        try dm.setNotifications(pubKey: pubKey, level: level)
      }
      self.notificationsLevel = level
      self.showToast("Notification settings saved")
    } catch {
      AppLogger.channels.error(
        "Failed to update notification level: \(error.localizedDescription, privacy: .public)"
      )
    }
  }

  func handleExportSuccess(message: String) {
    self.showToast(message)
  }

  func handlePasswordCopied() {
    self.showToast("Password copied")
  }

  func handleImportSuccess(
    message: String, chatId: UUID?, chat _: ChatModel?
  ) {
    if let chatId {
      try? self.database.write { db in
        try ChatModel.where { $0.id.eq(chatId) }
          .update { $0.isAdmin = true }
          .execute(db)
      }
    }
    self.showToast(message)
  }

  func saveNickname<T: XXDKP>(channelId: String?, xxdk: T) {
    guard let channelId else { return }
    do {
      try xxdk.channel.setNickname(channelId: channelId, nickname: self.channelNickname)
      self.showToast("Nickname saved")
    } catch {
      AppLogger.channels.error(
        "Failed to save nickname: \(error.localizedDescription, privacy: .public)"
      )
    }
  }

  private func showToast(_ message: String) {
    withAnimation(.spring(response: 0.3)) {
      self.toastMessage = message
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
      withAnimation {
        self.toastMessage = nil
      }
    }
  }
}
