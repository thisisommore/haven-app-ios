//
//  ChannelOptionsView+Controller.swift
//  iOSExample
//
//  Created by Om More
//

import Observation
import SQLiteData
import SwiftUI

@MainActor
@Observable
final class ChannelOptionsController {
  var isDMEnabled: Bool = false
  var shareURL: String?
  var sharePassword: String?
  var showExportKeySheet: Bool = false
  var showImportKeySheet: Bool = false
  var toastMessage: String?
  var mutedUsers: [Data] = []
  var showLeaveConfirmation: Bool = false
  var showDeleteConfirmation: Bool = false
  var channelNickname: String = ""

  @ObservationIgnored
  @Dependency(\.defaultDatabase) var database

  func onAppear<T: XXDKP>(chat _: ChatModel?, channelId: String?, xxdk: T) {
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
      self.mutedUsers = try xxdk.channel.getMutedUsers(channelId: channelId)
    } catch {
      AppLogger.channels.error(
        "Failed to fetch muted users: \(error.localizedDescription, privacy: .public)"
      )
    }

    do {
      self.channelNickname = try xxdk.channel.getChannelNickname(channelId: channelId)
    } catch {
      AppLogger.channels.error(
        "Failed to fetch channel nickname: \(error.localizedDescription, privacy: .public)"
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
      self.mutedUsers = try xxdk.channel.getMutedUsers(channelId: channelId)
      self.showToast("User unmuted")
    } catch {
      AppLogger.channels.error(
        "Failed to unmute user: \(error.localizedDescription, privacy: .public)"
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

  func handleMuteStatusChanged<T: XXDKP>(
    notification: Notification, channelId: String?, xxdk: T
  ) {
    guard let channelId else { return }
    if let notificationChannelID = notification.userInfo?["channelID"] as? String,
       notificationChannelID == channelId {
      do {
        self.mutedUsers = try xxdk.channel.getMutedUsers(channelId: channelId)
      } catch {
        AppLogger.channels.error(
          "Failed to refresh muted users: \(error.localizedDescription, privacy: .public)"
        )
      }
    }
  }

  func saveNickname<T: XXDKP>(channelId: String?, xxdk: T) {
    guard let channelId else { return }
    do {
      try xxdk.channel.setChannelNickname(channelId: channelId, nickname: self.channelNickname)
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
