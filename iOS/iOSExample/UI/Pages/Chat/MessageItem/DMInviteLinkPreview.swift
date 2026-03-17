//
//  DMInviteLinkPreview.swift
//  iOSExample
//
//  Created by Om More on 23/12/25.
//

import Bindings
import SQLiteData
import SwiftUI

struct ParsedDMLink {
  let url: String
  let token: Int32
  let pubKey: Data
  let codeset: Int

  static func parse(from text: String) -> ParsedDMLink? {
    // Decode HTML entities first (e.g., &amp; -> &)
    let decodedText =
      text
        .replacingOccurrences(of: "&amp;", with: "&")
        .replacingOccurrences(of: "&lt;", with: "<")
        .replacingOccurrences(of: "&gt;", with: ">")

    // Find haven DM URL in text
    let pattern = #"haven://dm\?[^\s<\"\']+"#
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

    var tokenValue: Int32?
    var pubKeyData: Data?
    var codesetValue: Int?

    for item in components.queryItems ?? [] {
      switch item.name {
      case "token":
        if let tokenStr = item.value, let token64 = Int64(tokenStr) {
          tokenValue = Int32(bitPattern: UInt32(truncatingIfNeeded: token64))
        }
      case "pubKey":
        if let pubKeyBase64 = item.value?.removingPercentEncoding {
          pubKeyData = Data(base64Encoded: pubKeyBase64)
        }
      case "codeset":
        if let codesetStr = item.value {
          codesetValue = Int(codesetStr)
        }
      default:
        break
      }
    }

    guard let token = tokenValue,
          let pubKey = pubKeyData,
          let codeset = codesetValue
    else {
      return nil
    }

    return ParsedDMLink(url: url, token: token, pubKey: pubKey, codeset: codeset)
  }
}

struct DMInviteLinkPreview<T: XXDKP>: View {
  let link: ParsedDMLink
  let isIncoming: Bool
  let timestamp: String

  @EnvironmentObject var xxdk: T
  @EnvironmentObject var selectedChat: SelectedChat
  @Dependency(\.defaultDatabase) var database

  @State private var isLoading = false
  @State private var errorMessage: String?
  @State private var isAlreadyAdded = false
  @State private var isSelfChat = false
  @State private var userName: String = "Unknown User"
  @State private var userColor: Int = 0xE97451

  var body: some View {
    InviteLinkPreviewContainer(isIncoming: self.isIncoming, timestamp: self.timestamp) {
      InviteLinkHeader(
        icon: "message.circle.fill",
        title: self.userName,
        subtitle: "Direct Message Invite"
      )

      InviteLinkButton(
        isLoading: self.isLoading,
        isCompleted: self.isAlreadyAdded,
        completedText: "Open Chat",
        actionText: "Add User",
        errorMessage: errorMessage,
        action: self.addUser,
        completedAction: self.isSelfChat ? nil : self.openChat
      )

      if let errorMessage {
        Text(errorMessage)
          .font(.caption)
          .foregroundStyle(.red)
      }
    }
    .onAppear {
      self.deriveUserInfo()
      self.checkIfAlreadyAdded()
    }
  }

  private func deriveUserInfo() {
    let identity: IdentityJSON?
    do {
      identity = try BindingsStatic.constructIdentity(
        pubKey: self.link.pubKey, codeset: self.link.codeset
      )
    } catch {
      return
    }
    guard let identity else { return }

    self.userName = identity.Codename
    var colorStr = identity.Color
    if colorStr.hasPrefix("0x") || colorStr.hasPrefix("0X") {
      colorStr.removeFirst(2)
    }
    self.userColor = Int(colorStr, radix: 16) ?? 0xE97451
  }

  private func checkIfAlreadyAdded() {
    do {
      let existingChat = try database.read { db in
        try ChatModel.where { $0.pubKey.eq(self.link.pubKey) }.fetchOne(db)
      }
      if let existingChat {
        self.isAlreadyAdded = true
        self.isSelfChat = existingChat.name == "<self>"
      }
    } catch {
      // Ignore errors
    }
  }

  private func openChat() {
    guard !self.isSelfChat else { return }
    let existingChat = try? self.database.read { db in
      try ChatModel.where { $0.pubKey.eq(self.link.pubKey) }.fetchOne(db)
    }
    guard let existingChat else { return }
    self.selectedChat.select(id: existingChat.id, title: self.userName)
  }

  private func addUser() {
    self.isLoading = true
    self.errorMessage = nil

    let newChat = ChatModel(
      pubKey: link.pubKey,
      name: self.userName,
      dmToken: self.link.token,
      color: self.userColor
    )

    Task {
      do {
        try await self.database.write { db in
          try ChatModel.insert { newChat }.execute(db)
        }
        await MainActor.run {
          self.isAlreadyAdded = true
          self.isLoading = false
          self.selectedChat.select(id: newChat.id, title: self.userName)
        }
      } catch {
        await MainActor.run {
          self.errorMessage = "Failed to add"
          self.isLoading = false
        }
      }
    }
  }
}

#Preview {
  let mockLink = ParsedDMLink(
    url: "haven://dm?token=123&pubKey=test&codeset=0",
    token: 123,
    pubKey: Data(),
    codeset: 0
  )

  DMInviteLinkPreview<XXDKMock>(
    link: mockLink,
    isIncoming: true,
    timestamp: "10:00 AM"
  )
  .mock()
}
