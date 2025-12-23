//
//  DMInviteLinkPreview.swift
//  iOSExample
//
//  Created by Om More on 23/12/25.
//

import Bindings
import SwiftData
import SwiftUI

struct ParsedDMLink {
    let url: String
    let token: Int32
    let pubKey: Data
    let codeset: Int

    static func parse(from text: String) -> ParsedDMLink? {
        // Decode HTML entities first (e.g., &amp; -> &)
        let decodedText = text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")

        // Find haven DM URL in text
        let pattern = #"haven://dm\?[^\s<\"\']+"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: decodedText, range: NSRange(decodedText.startIndex..., in: decodedText)),
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
    @EnvironmentObject var swiftDataActor: SwiftDataActor
    @EnvironmentObject var selectedChat: SelectedChat

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isAlreadyAdded = false
    @State private var userName: String = "Unknown User"
    @State private var userColor: Int = 0xE97451

    var body: some View {
        InviteLinkPreviewContainer(isIncoming: isIncoming, timestamp: timestamp) {
            InviteLinkHeader(
                icon: "message.circle.fill",
                title: userName,
                subtitle: "Direct Message Invite"
            )

            InviteLinkButton(
                isLoading: isLoading,
                isCompleted: isAlreadyAdded,
                completedText: "Already Added",
                actionText: "Add User",
                errorMessage: errorMessage,
                action: addUser
            )

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .onAppear {
            deriveUserInfo()
            checkIfAlreadyAdded()
        }
    }

    private func deriveUserInfo() {
        var err: NSError?
        guard let identityData = Bindings.BindingsConstructIdentity(
            link.pubKey,
            link.codeset,
            &err
        ), err == nil else {
            return
        }

        do {
            let identity = try Parser.decodeIdentity(from: identityData)
            userName = identity.codename
            var colorStr = identity.color
            if colorStr.hasPrefix("0x") || colorStr.hasPrefix("0X") {
                colorStr.removeFirst(2)
            }
            userColor = Int(colorStr, radix: 16) ?? 0xE97451
        } catch {
            // Keep defaults
        }
    }

    private func checkIfAlreadyAdded() {
        let chatId = link.pubKey.base64EncodedString()
        do {
            let descriptor = FetchDescriptor<ChatModel>()
            let allChats = try swiftDataActor.fetch(descriptor)
            isAlreadyAdded = allChats.contains { $0.id == chatId }
        } catch {
            // Ignore errors
        }
    }

    private func addUser() {
        isLoading = true
        errorMessage = nil

        let newChat = ChatModel(
            pubKey: link.pubKey,
            name: userName,
            dmToken: link.token,
            color: userColor
        )

        Task {
            swiftDataActor.insert(newChat)
            do {
                try swiftDataActor.save()
                await MainActor.run {
                    isAlreadyAdded = true
                    isLoading = false
                    selectedChat.select(id: newChat.id, title: userName)
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to add"
                    isLoading = false
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
