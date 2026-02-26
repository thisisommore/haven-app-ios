//
//  ChannelInviteLinkPreview.swift
//  iOSExample
//
//  Created by Om More on 07/12/25.
//

import SwiftData
import SwiftUI

struct ParsedChannelLink {
    let url: String
    let name: String
    let description: String
    let level: String

    static func parse(from text: String) -> ParsedChannelLink? {
        // Decode HTML entities first (e.g., &amp; -> &)
        let decodedText = text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")

        // Find xx network channel URL in text (supports xxnetwork.com and haven.xx.network)
        let pattern = #"https?://(xxnetwork\.com|haven\.xx\.network)/join\?[^\s<\"\']+"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: decodedText, range: NSRange(decodedText.startIndex..., in: decodedText)),
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

        return ParsedChannelLink(url: url, name: displayName, description: description, level: isSecret ? "Secret" : level)
    }
}

struct ChannelInviteLinkPreview<T: XXDKP>: View {
    let link: ParsedChannelLink
    let isIncoming: Bool
    let timestamp: String

    @EnvironmentObject var xxdk: T
    @EnvironmentObject var swiftDataActor: SwiftDataActor
    @EnvironmentObject var selectedChat: SelectedChat

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
        InviteLinkPreviewContainer(isIncoming: isIncoming, timestamp: timestamp) {
            InviteLinkHeader(
                icon: link.level == "Secret" ? "lock.circle.fill" : "number.circle.fill",
                title: link.name,
                subtitle: link.description
            )

            InviteLinkButton(
                isLoading: isLoading,
                isCompleted: isAlreadyJoined,
                completedText: "Open Chat",
                actionText: "Join Channel",
                errorMessage: errorMessage,
                action: loadChannel,
                completedAction: openChat
            )

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .sheet(isPresented: $showPasswordSheet) {
            PasswordInputView(
                url: link.url,
                onConfirm: { password in handlePassword(password) },
                onCancel: { showPasswordSheet = false }
            )
        }
        .sheet(isPresented: $showConfirmation) {
            JoinChannelConfirmationView(
                channelName: channelData?.Name ?? link.name,
                channelURL: link.url,
                isJoining: $isJoining,
                onConfirm: { enableDM in
                    Task { await joinChannel(enableDM: enableDM) }
                }
            )
        }
        .onAppear {
            checkIfAlreadyJoined()
        }
    }

    private func loadChannel() {
        isLoading = true
        errorMessage = nil

        do {
            let privacyLevel = try xxdk.getChannelPrivacyLevel(url: link.url)

            if privacyLevel == .secret {
                isLoading = false
                showPasswordSheet = true
            } else {
                channelData = try xxdk.getChannelFromURL(url: link.url)
                isLoading = false
                showConfirmation = true
            }
        } catch {
            errorMessage = "Failed to load channel"
            isLoading = false
        }
    }

    private func handlePassword(_ password: String) {
        do {
            prettyPrint = try xxdk.decodePrivateURL(url: link.url, password: password)
            channelData = try xxdk.getPrivateChannelFromURL(url: link.url, password: password)
            showPasswordSheet = false
            showConfirmation = true
        } catch {
            errorMessage = "Invalid password"
            showPasswordSheet = false
        }
    }

    private func checkIfAlreadyJoined() {
        do {
            let descriptor = FetchDescriptor<ChatModel>()
            let allChats = try swiftDataActor.fetch(descriptor)

            // Try matching by channelId first
            if let channel = try? xxdk.getChannelFromURL(url: link.url),
               let channelId = channel.ChannelID
            {
                if let existingChat = allChats.first(where: { $0.id == channelId }) {
                    isAlreadyJoined = true
                    existingChatId = existingChat.id
                    return
                }
            }

            // Fallback: match by name (for secret channels or if URL parsing fails)
            if let existingChat = allChats.first(where: { $0.name == link.name }) {
                isAlreadyJoined = true
                existingChatId = existingChat.id
            }
        } catch {
            // Ignore errors - if we can't check, assume not joined
        }
    }

    private func openChat() {
        guard let chatId = existingChatId else { return }
        selectedChat.select(id: chatId, title: link.name)
    }

    private func joinChannel(enableDM: Bool) async {
        isJoining = true

        do {
            let joinedChannel: ChannelJSON
            if let prettyPrint {
                joinedChannel = try await xxdk.joinChannel(prettyPrint)
            } else {
                joinedChannel = try await xxdk.joinChannelFromURL(link.url)
            }

            guard let channelId = joinedChannel.ChannelID else {
                throw XXDKError.channelIdMissing
            }

            if enableDM {
                try xxdk.enableDirectMessages(channelId: channelId)
            } else {
                try xxdk.disableDirectMessages(channelId: channelId)
            }

            let newChat = ChatModel(channelId: channelId, name: joinedChannel.Name, isSecret: link.level == "Secret")
            swiftDataActor.insert(newChat)
            try swiftDataActor.save()

            showConfirmation = false
        } catch {
            errorMessage = "Failed to join"
        }

        isJoining = false
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
