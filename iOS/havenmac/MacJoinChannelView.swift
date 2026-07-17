//
//  MacJoinChannelView.swift
//  haven
//
//  Join Channel dialog redesigned for macOS: one dialog that steps through
//  link → password (secret channels) → confirmation instead of stacked
//  iOS sheets. Logic mirrors the shared `NewChatSheet`.
//

import SQLiteData
import SwiftUI

struct MacJoinChannelView<T: XXDKP>: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var xxdk: T

  @Dependency(\.defaultDatabase) private var database

  @State private var step: Step = .linkInput
  @State private var inviteLink = ""
  @State private var password = ""
  @State private var enableDM = false
  @State private var isPrivateChannel = false
  @State private var prettyPrint: String?
  @State private var isJoining = false
  @State private var errorMessage: String?

  @FocusState private var isInputFocused: Bool

  private enum Step {
    case linkInput
    case passwordInput
    case confirmation(channel: ChannelJSON)
  }

  // MARK: - Flow (mirrors NewChatSheet)

  private func continueFromLink() {
    let trimmed = self.inviteLink.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    self.inviteLink = trimmed

    do {
      let privacyLevel = try self.xxdk.channel.getPrivacyLevel(url: trimmed)
      self.errorMessage = nil
      if privacyLevel == .secret {
        self.isPrivateChannel = true
        self.step = .passwordInput
      } else {
        let channel = try self.xxdk.channel.getFrom(url: trimmed)
        self.step = .confirmation(channel: channel)
      }
    } catch {
      self.errorMessage = "Failed to get channel: \(error.localizedDescription)"
    }
  }

  private func confirmPassword() {
    guard !self.password.isEmpty else { return }
    do {
      let pp = try self.xxdk.channel.decodePrivateURL(
        url: self.inviteLink,
        password: self.password
      )
      self.prettyPrint = pp
      let channel = try self.xxdk.channel.getPrivateChannelFrom(
        url: self.inviteLink,
        password: self.password
      )
      self.errorMessage = nil
      self.step = .confirmation(channel: channel)
    } catch {
      self.errorMessage = "Failed to decrypt channel: \(error.localizedDescription)"
      self.step = .linkInput
    }
  }

  private func join(channel _: ChannelJSON) {
    self.isJoining = true
    self.errorMessage = nil

    Task {
      do {
        let joinedChannel: ChannelJSON
        if let prettyPrint {
          joinedChannel = try await self.xxdk.channel.join(prettyPrint: prettyPrint)
        } else {
          joinedChannel = try await self.xxdk.channel.join(url: self.inviteLink)
        }

        guard let channelId = joinedChannel.ChannelID
        else {
          throw XXDKError.channelIdMissing
        }

        if self.enableDM {
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

        await MainActor.run {
          self.dismiss()
        }
      } catch {
        AppLogger.channels.error(
          "Failed to join channel: \(error.localizedDescription, privacy: .public)"
        )
        await MainActor.run {
          self.errorMessage = "Failed to join channel: \(error.localizedDescription)"
          self.prettyPrint = nil
          self.step = .linkInput
          self.isJoining = false
        }
      }
    }
  }

  // MARK: - UI

  var body: some View {
    VStack(spacing: 0) {
      Text("Join Channel")
        .font(.title2)
        .fontWeight(.bold)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)

      VStack(spacing: 12) {
        switch self.step {
        case .linkInput:
          GroupBox("Invite Link") {
            VStack(alignment: .leading, spacing: 6) {
              TextField("Paste a Haven invite link", text: self.$inviteLink)
                .textFieldStyle(.roundedBorder)
                .focused(self.$isInputFocused)
                .onSubmit { self.continueFromLink() }
              Text("Ask a channel admin for an invite link.")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }

        case .passwordInput:
          GroupBox("Private Channel") {
            VStack(alignment: .leading, spacing: 6) {
              Text("This channel is password protected. Enter the password to continue.")
                .font(.callout)
                .foregroundStyle(.secondary)
              SecureField("Password", text: self.$password)
                .textFieldStyle(.roundedBorder)
                .focused(self.$isInputFocused)
                .onSubmit { self.confirmPassword() }
            }
          }

        case let .confirmation(channel):
          GroupBox("Channel") {
            MacSettingRow("Name") {
              Text(channel.Name)
            }
            Divider()
            VStack(alignment: .leading, spacing: 4) {
              Text("URL")
                .foregroundStyle(.secondary)
              Text(self.inviteLink)
                .font(.system(.callout, design: .monospaced))
                .lineLimit(3)
                .textSelection(.enabled)
            }
            Divider()
            MacSettingRow("Enable Direct Messages") {
              Toggle("", isOn: self.$enableDM)
                .toggleStyle(.switch)
                .labelsHidden()
                .disabled(self.isJoining)
            }
          }
        }

        if let errorMessage {
          Text(errorMessage)
            .font(.caption)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .padding(.horizontal, 20)

      HStack {
        Button("Cancel") {
          self.dismiss()
        }
        .disabled(self.isJoining)
        .keyboardShortcut(.cancelAction)

        Spacer()

        if self.isJoining {
          ProgressView()
            .controlSize(.small)
        }

        switch self.step {
        case .linkInput:
          Button("Continue") {
            self.continueFromLink()
          }
          .buttonStyle(.borderedProminent)
          .tint(.haven)
          .disabled(self.inviteLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          .keyboardShortcut(.defaultAction)

        case .passwordInput:
          Button("Confirm") {
            self.confirmPassword()
          }
          .buttonStyle(.borderedProminent)
          .tint(.haven)
          .disabled(self.password.isEmpty)
          .keyboardShortcut(.defaultAction)

        case let .confirmation(channel):
          Button("Join") {
            self.join(channel: channel)
          }
          .buttonStyle(.borderedProminent)
          .tint(.haven)
          .disabled(self.isJoining)
          .keyboardShortcut(.defaultAction)
        }
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 14)
    }
    .frame(width: 440)
    .onAppear {
      self.isInputFocused = true
    }
  }
}
