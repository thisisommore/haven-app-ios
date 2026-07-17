//
//  NewChatView.swift
//  iOSExample
//
//  Created by Om More on 17/12/25.
//
import Foundation
import SQLiteData
import SwiftUI

enum NewChatActiveSheet: Identifiable {
  case passwordInput
  case joinConfirmation(inviteLink: String, channelData: ChannelJSON)

  var id: String {
    switch self {
    case .passwordInput:
      return "passwordInput"
    case let .joinConfirmation(inviteLink, channelData):
      if let channelId = channelData.ChannelID {
        return "joinConfirmation-\(channelId)"
      }
      return "joinConfirmation-\(inviteLink)"
    }
  }
}

struct NewChatSheet<T: XXDKP>: View {
  @Environment(\.dismiss) var dismiss
  @EnvironmentObject var xxdk: T

  @Dependency(\.defaultDatabase) var database

  @State private var activeSheet: NewChatActiveSheet?
  @State private var inviteLink: String = ""
  @State private var channelData: ChannelJSON?
  @State private var errorMessage: String?
  @State private var isJoining: Bool = false
  @State private var isPrivateChannel: Bool = false
  @State private var prettyPrint: String?

  private func joinChannel(
    url: String,
    channelData _: ChannelJSON,
    enableDM: Bool
  ) async {
    self.isJoining = true
    self.errorMessage = nil

    do {
      let joinedChannel: ChannelJSON
      // Use prettyPrint if available (private channel), otherwise decode from URL (public channel)
      if let prettyPrint {
        joinedChannel = try await self.xxdk.channel.join(prettyPrint: prettyPrint)
      } else {
        joinedChannel = try await self.xxdk.channel.join(url: url)
      }

      // Create and save the chat to the database
      guard let channelId = joinedChannel.ChannelID
      else {
        throw XXDKError.channelIdMissing
      }

      // Enable or disable direct messages based on toggle
      if enableDM {
        try self.xxdk.channel.enableDirectMessages(channelId: channelId)
      } else {
        try self.xxdk.channel.disableDirectMessages(channelId: channelId)
      }

      let newChat = ChatModel(
        channelId: channelId, name: joinedChannel.Name, isSecret: self.isPrivateChannel
      )
      try await self.database.write { db in
        try ChatModel.insert { newChat }.execute(db)
      }

      // Dismiss both sheets and reset state
      self.channelData = nil
      prettyPrint = nil
      self.dismiss()
    } catch {
      AppLogger.channels.error(
        "Failed to join channel: \(error.localizedDescription, privacy: .public)"
      )
      self.errorMessage =
        "Failed to join channel: \(error.localizedDescription)"
      self.channelData = nil
      self.prettyPrint = nil
    }

    self.isJoining = false
  }

  var body: some View {
    NavigationStack {
      VStack {
        Form {
          Section(header: Text("Enter invite link")) {
            TextEditor(text: self.$inviteLink)
              .frame(minHeight: 100, maxHeight: UIScreen.h(60))
              .font(.body)
          }

          if let errorMessage {
            Section {
              Text(errorMessage)
                .foregroundColor(.red)
                .font(.caption)
            }
          }
        }
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            Button("Close") { self.dismiss() }.tint(.haven)
          }.hiddenSharedBackground()
          ToolbarItem(placement: .topBarTrailing) {
            Button(
              action: {
                let trimmed = self.inviteLink.trimmingCharacters(
                  in: .whitespacesAndNewlines
                )
                guard !trimmed.isEmpty else { return }

                do {
                  let privacyLevel =
                    try xxdk.channel.getPrivacyLevel(
                      url: trimmed
                    )

                  if privacyLevel == .secret {
                    self.isPrivateChannel = true
                    self.activeSheet = .passwordInput
                    self.errorMessage = nil
                  } else {
                    let channel = try xxdk.channel.getFrom(
                      url: trimmed
                    )
                    self.channelData = channel
                    self.activeSheet = .joinConfirmation(
                      inviteLink: trimmed,
                      channelData: channel
                    )
                    self.errorMessage = nil
                  }
                } catch {
                  self.errorMessage =
                    "Failed to get channel: \(error.localizedDescription)"
                }
              },
              label: { Text("Join").foregroundStyle(.haven) }
            )
          }.hiddenSharedBackground()
        }
      }
      .navigationTitle("Join Channel")
      .navigationBarTitleDisplayMode(.inline)
    }
    .sheet(item: self.$activeSheet) { sheet in
      switch sheet {
      case .passwordInput:
        PasswordInputSheet(
          url: self.inviteLink,
          onConfirm: { password in
            do {
              let pp = try xxdk.channel.decodePrivateURL(
                url: self.inviteLink,
                password: password
              )
              self.prettyPrint = pp
              let channel = try xxdk.channel.getPrivateChannelFrom(
                url: self.inviteLink,
                password: password
              )
              self.channelData = channel
              self.activeSheet = .joinConfirmation(
                inviteLink: self.inviteLink,
                channelData: channel
              )
              self.errorMessage = nil
            } catch {
              self.errorMessage =
                "Failed to decrypt channel: \(error.localizedDescription)"
              self.activeSheet = nil
            }
          },
          onCancel: {
            self.activeSheet = nil
          }
        )
      case let .joinConfirmation(inviteLink, channelData):
        JoinChannelConfirmationSheet(
          channelName: channelData.Name,
          channelURL: inviteLink,
          isJoining: self.$isJoining,
          onConfirm: { enableDM in
            Task {
              await self.joinChannel(
                url: inviteLink,
                channelData: channelData,
                enableDM: enableDM
              )
            }
          }
        )
      }
    }
  }
}
