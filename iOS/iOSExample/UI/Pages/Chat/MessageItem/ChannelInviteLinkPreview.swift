//
//  ChannelInviteLinkPreview.swift
//  iOSExample
//
//  Created by Om More on 07/12/25.
//

import SQLiteData
import SwiftUI

struct ParsedChannelLink {
  let url: String
  let name: String
  let description: String
  let level: String

  static func parse(from text: String) -> ParsedChannelLink? {
    // Decode HTML entities first (e.g., &amp; -> &)
    let decodedText =
      text
        .replacingOccurrences(of: "&amp;", with: "&")
        .replacingOccurrences(of: "&lt;", with: "<")
        .replacingOccurrences(of: "&gt;", with: ">")

    // Find xx network channel URL in text (supports xxnetwork.com and haven.xx.network)
    let pattern = #"https?://(xxnetwork\.com|haven\.xx\.network)/join\?[^\s<\"\']+"#
    guard let regex = try? NSRegularExpression(pattern: pattern),
          let match = regex.firstMatch(
            in: decodedText, range: NSRange(decodedText.startIndex..., in: decodedText)
          ),
          let range = Range(match.range, in: decodedText)
    else {
      return nil
    }

    let url = String(decodedText[range])
    guard let components = URLComponents(string: url) else { return nil }

    var name = ""
    var description = ""
    var level = "Public"

    for item in components.queryItems ?? [] {
      switch item.name {
      case "0Name":
        name = item.value?.replacingOccurrences(of: "+", with: " ") ?? ""
      case "1Description":
        description = item.value?.replacingOccurrences(of: "+", with: " ") ?? ""
      case "2Level":
        level = item.value ?? "Public"
      default:
        break
      }
    }

    // Secret channels don't have 0Name parameter, show as "Secret Channel"
    let isSecret = name.isEmpty
    let displayName = isSecret ? "Secret Channel" : name

    return ParsedChannelLink(
      url: url, name: displayName, description: description,
      level: isSecret ? "Secret" : level
    )
  }
}

struct ChannelInviteLinkPreview<T: XXDKP>: View {
  let link: ParsedChannelLink
  let isIncoming: Bool
  let timestamp: String

  @EnvironmentObject var xxdk: T
  @EnvironmentObject var selectedChat: SelectedChat
  @Dependency(\.defaultDatabase) var database

  @State private var isLoading = false
  @State private var isJoining = false
  @State private var showConfirmation = false
  @State private var showPasswordSheet = false
  @State private var channelData: ChannelJSON?
  @State private var prettyPrint: String?
  @State private var errorMessage: String?
  @State private var isAlreadyJoined = false
  @State private var existingChatId: String?

  var body: some View {
    InviteLinkPreviewContainer(isIncoming: self.isIncoming, timestamp: self.timestamp) {
      InviteLinkHeader(
        icon: self.link.level == "Secret" ? "lock.circle.fill" : "number.circle.fill",
        title: self.link.name,
        subtitle: self.link.description
      )

      InviteLinkButton(
        isLoading: self.isLoading,
        isCompleted: self.isAlreadyJoined,
        completedText: "Open Chat",
        actionText: "Join Channel",
        errorMessage: errorMessage,
        action: self.loadChannel,
        completedAction: self.openChat
      )

      if let errorMessage {
        Text(errorMessage)
          .font(.caption)
          .foregroundStyle(.red)
      }
    }
    .sheet(isPresented: self.$showPasswordSheet) {
      PasswordInputView(
        url: self.link.url,
        onConfirm: { password in self.handlePassword(password) },
        onCancel: { self.showPasswordSheet = false }
      )
    }
    .sheet(isPresented: self.$showConfirmation) {
      JoinChannelConfirmationView(
        channelName: self.channelData?.Name ?? self.link.name,
        channelURL: self.link.url,
        isJoining: self.$isJoining,
        onConfirm: { enableDM in
          Task { await self.joinChannel(enableDM: enableDM) }
        }
      )
    }
    .onAppear {
      self.checkIfAlreadyJoined()
    }
  }

  private func loadChannel() {
    self.isLoading = true
    self.errorMessage = nil

    do {
      let privacyLevel = try xxdk.getChannelPrivacyLevel(url: self.link.url)

      if privacyLevel == .secret {
        self.isLoading = false
        self.showPasswordSheet = true
      } else {
        self.channelData = try self.xxdk.getChannelFromURL(url: self.link.url)
        self.isLoading = false
        self.showConfirmation = true
      }
    } catch {
      self.errorMessage = "Failed to load channel"
      self.isLoading = false
    }
  }

  private func handlePassword(_ password: String) {
    do {
      self.prettyPrint = try self.xxdk.decodePrivateURL(url: self.link.url, password: password)
      self.channelData = try self.xxdk.getPrivateChannelFromURL(url: self.link.url, password: password)
      self.showPasswordSheet = false
      self.showConfirmation = true
    } catch {
      self.errorMessage = "Invalid password"
      self.showPasswordSheet = false
    }
  }

  private func checkIfAlreadyJoined() {
    do {
      let allChats = try database.read { db in
        try ChatModel.all.fetchAll(db)
      }

      // Try matching by channelId first
      if let channel = try? xxdk.getChannelFromURL(url: link.url),
         let channelId = channel.ChannelID {
        if let existingChat = allChats.first(where: { $0.id == channelId }) {
          self.isAlreadyJoined = true
          self.existingChatId = existingChat.id
          return
        }
      }

      // Fallback: match by name (for secret channels or if URL parsing fails)
      if let existingChat = allChats.first(where: { $0.name == link.name }) {
        self.isAlreadyJoined = true
        self.existingChatId = existingChat.id
      }
    } catch {
      // Ignore errors - if we can't check, assume not joined
    }
  }

  private func openChat() {
    guard let chatId = existingChatId else { return }
    self.selectedChat.select(id: chatId, title: self.link.name)
  }

  private func joinChannel(enableDM: Bool) async {
    self.isJoining = true

    do {
      let joinedChannel: ChannelJSON
      if let prettyPrint {
        joinedChannel = try await self.xxdk.joinChannel(prettyPrint)
      } else {
        joinedChannel = try await self.xxdk.joinChannelFromURL(self.link.url)
      }

      guard let channelId = joinedChannel.ChannelID
      else {
        throw XXDKError.channelIdMissing
      }

      if enableDM {
        try self.xxdk.enableDirectMessages(channelId: channelId)
      } else {
        try self.xxdk.disableDirectMessages(channelId: channelId)
      }

      let newChat = ChatModel(
        channelId: channelId, name: joinedChannel.Name, isSecret: self.link.level == "Secret"
      )
      try await self.database.write { db in
        try ChatModel.insert { newChat }.execute(db)
      }

      self.showConfirmation = false
    } catch {
      self.errorMessage = "Failed to join"
    }

    self.isJoining = false
  }
}

#Preview {
  VStack(spacing: 16) {
    ChannelInviteLinkPreview<XXDKMock>(
      link: ParsedChannelLink(
        url: "http://haven.xx.network/join?...",
        name: "xxGeneralChat",
        description: "Talking about the xx network",
        level: "Public"
      ),
      isIncoming: true,
      timestamp: "16:12 PM"
    )
  }
  .padding()
  .mock()
}
