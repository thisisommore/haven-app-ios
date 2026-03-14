//
//  NewChatView.swift
//  iOSExample
//
//  Created by Om More on 17/12/25.
//
import Foundation
import SQLiteData
import SwiftUI

struct NewChatView<T: XXDKP>: View {
  @Environment(\.dismiss) var dismiss
  @State private var showConfirmationSheet: Bool = false
  @EnvironmentObject var xxdk: T
  @Dependency(\.defaultDatabase) var database
  @State private var inviteLink: String = ""
  @State private var channelData: ChannelJSON?
  @State private var errorMessage: String?
  @State private var isJoining: Bool = false
  @State private var showPasswordSheet: Bool = false
  @State private var isPrivateChannel: Bool = false
  @State private var prettyPrint: String?

  var body: some View {
    NavigationView {
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
                  // Check privacy level first
                  let privacyLevel =
                    try xxdk.getChannelPrivacyLevel(
                      url: trimmed
                    )

                  if privacyLevel == .secret {
                    // Private channel - show password input
                    self.isPrivateChannel = true
                    self.showPasswordSheet = true
                    self.errorMessage = nil
                  } else {
                    // Public channel - proceed directly
                    let channel = try xxdk.getChannelFromURL(
                      url: trimmed
                    )
                    self.channelData = channel
                    self.showConfirmationSheet = true
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
      .sheet(isPresented: self.$showPasswordSheet) {
        PasswordInputView(
          url: self.inviteLink,
          onConfirm: { password in
            do {
              let pp = try xxdk.decodePrivateURL(
                url: self.inviteLink,
                password: password
              )
              self.prettyPrint = pp
              let channel = try xxdk.getPrivateChannelFromURL(
                url: self.inviteLink,
                password: password
              )
              self.channelData = channel
              self.showConfirmationSheet = true
              self.showPasswordSheet = false
              self.errorMessage = nil
            } catch {
              self.errorMessage =
                "Failed to decrypt channel: \(error.localizedDescription)"
              self.showPasswordSheet = false
            }
          },
          onCancel: {
            self.showPasswordSheet = false
          }
        )
      }
      .sheet(isPresented: self.$showConfirmationSheet) { [inviteLink, channelData] in
        JoinChannelConfirmationView(
          channelName: channelData?.Name ?? "",
          channelURL: inviteLink,
          isJoining: self.$isJoining,
          onConfirm: { enableDM in
            Task {
              await self.joinChannel(
                url: inviteLink,
                channelData: channelData!,
                enableDM: enableDM
              )
            }
          }
        )
      }
      .navigationTitle("Join Channel")
      .navigationBarTitleDisplayMode(.inline)
    }
  }

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
        joinedChannel = try await self.xxdk.joinChannel(prettyPrint)
      } else {
        joinedChannel = try await self.xxdk.joinChannelFromURL(url)
      }

      // Create and save the chat to the database
      guard let channelId = joinedChannel.ChannelID
      else {
        throw XXDKError.channelIdMissing
      }

      // Enable or disable direct messages based on toggle
      if enableDM {
        try self.xxdk.enableDirectMessages(channelId: channelId)
      } else {
        try self.xxdk.disableDirectMessages(channelId: channelId)
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
}
