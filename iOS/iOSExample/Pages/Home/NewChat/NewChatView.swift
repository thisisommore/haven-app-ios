//
//  NewChatView.swift
//  iOSExample
//
//  Created by Om More on 17/12/25.
//
import Foundation
import SwiftUI

struct NewChatView<T: XXDKP>: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var swiftDataActor: SwiftDataActor
    @State private var showConfirmationSheet: Bool = false
    @EnvironmentObject var xxdk: T
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
                        TextEditor(text: $inviteLink)
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
                        Button("Close")
                            { dismiss() }.tint(.haven)
                    }.hiddenSharedBackground()
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(
                            action: {
                                let trimmed = inviteLink.trimmingCharacters(
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
                                        isPrivateChannel = true
                                        showPasswordSheet = true
                                        errorMessage = nil
                                    } else {
                                        // Public channel - proceed directly
                                        let channel = try xxdk.getChannelFromURL(
                                            url: trimmed
                                        )
                                        channelData = channel
                                        showConfirmationSheet = true
                                        errorMessage = nil
                                    }
                                } catch {
                                    errorMessage =
                                        "Failed to get channel: \(error.localizedDescription)"
                                }
                            },
                            label: { Text("Join").foregroundStyle(.haven) }
                        )
                    }.hiddenSharedBackground()
                }
            }
            .sheet(isPresented: $showPasswordSheet) {
                PasswordInputView(
                    url: inviteLink,
                    onConfirm: { password in
                        do {
                            let pp = try xxdk.decodePrivateURL(
                                url: inviteLink,
                                password: password
                            )
                            prettyPrint = pp
                            let channel = try xxdk.getPrivateChannelFromURL(
                                url: inviteLink,
                                password: password
                            )
                            channelData = channel
                            showConfirmationSheet = true
                            showPasswordSheet = false
                            errorMessage = nil
                        } catch {
                            errorMessage =
                                "Failed to decrypt channel: \(error.localizedDescription)"
                            showPasswordSheet = false
                        }
                    },
                    onCancel: {
                        showPasswordSheet = false
                    }
                )
            }
            .sheet(isPresented: $showConfirmationSheet) {
                [inviteLink, channelData] in
                JoinChannelConfirmationView(
                    channelName: channelData?.name ?? "",
                    channelURL: inviteLink,
                    isJoining: $isJoining,
                    onConfirm: { enableDM in
                        Task {
                            await joinChannel(
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
        isJoining = true
        errorMessage = nil

        do {
            let joinedChannel: ChannelJSON
            // Use prettyPrint if available (private channel), otherwise decode from URL (public channel)
            if let prettyPrint {
                joinedChannel = try await xxdk.joinChannel(prettyPrint)
            } else {
                joinedChannel = try await xxdk.joinChannelFromURL(url)
            }

            // Create and save the chat to the database
            guard let channelId = joinedChannel.channelId else {
                throw XXDKError.channelIdMissing
            }

            // Enable or disable direct messages based on toggle
            if enableDM {
                try xxdk.enableDirectMessages(channelId: channelId)
            } else {
                try xxdk.disableDirectMessages(channelId: channelId)
            }

            let newChat = ChatModel(channelId: channelId, name: joinedChannel.name, isSecret: isPrivateChannel)
            swiftDataActor.insert(newChat)
            try swiftDataActor.save()

            // Dismiss both sheets and reset state
            channelData = nil
            prettyPrint = nil
            dismiss()
        } catch {
            AppLogger.channels.error("Failed to join channel: \(error.localizedDescription, privacy: .public)")
            errorMessage =
                "Failed to join channel: \(error.localizedDescription)"
            channelData = nil
            prettyPrint = nil
        }

        isJoining = false
    }
}
