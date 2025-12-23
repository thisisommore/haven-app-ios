//
//  ChannelOptionsView.swift
//  iOSExample
//
//  Created by Om More
//

import SwiftData
import SwiftUI

struct ChannelOptionsView<T: XXDKP>: View {
    let chat: ChatModel?
    let onLeaveChannel: () -> Void
    var onDeleteChat: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var xxdk: T
    @State private var isDMEnabled: Bool = false
    @State private var shareURL: String?
    @State private var sharePassword: String?
    @State private var showExportKeySheet: Bool = false
    @State private var showImportKeySheet: Bool = false
    @State private var showBackgroundPicker: Bool = false
    @State private var toastMessage: String?
    @State private var isAdmin: Bool = false
    @State private var mutedUsers: [Data] = []
    @State private var showLeaveConfirmation: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @State private var channelNickname: String = ""
    @FocusState private var isNicknameFocused: Bool

    private var isDM: Bool {
        chat?.dmToken != nil
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(isDM ? "Name" : "Channel Name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(chat?.name ?? "Unknown")
                            .font(.body)
                    }

                    if !isDM, let description = chat?.channelDescription, !description.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(description)
                                .font(.body)
                        }
                    }

                    if !isDM {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your Nickname")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack {
                                TextField("Enter nickname (max 24 chars)", text: $channelNickname)
                                    .focused($isNicknameFocused)
                                    .onChange(of: channelNickname) { _, newValue in
                                        if newValue.count > 24 {
                                            channelNickname = String(newValue.prefix(24))
                                        }
                                    }
                                if isNicknameFocused {
                                    Button("Save") {
                                        saveNickname()
                                        isNicknameFocused = false
                                    }
                                    .font(.caption)
                                    .foregroundColor(.haven)
                                }
                            }
                            if channelNickname.count > 10 {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text("Nickname will be truncated to 10 chars in display")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }

                    if !isDM {
                        Toggle("Direct Messages", isOn: $isDMEnabled)
                            .tint(.haven)
                            .onChange(of: isDMEnabled) { oldValue, newValue in
                                guard let channelId = chat?.id else { return }
                                do {
                                    if newValue {
                                        try xxdk.enableDirectMessages(channelId: channelId)
                                    } else {
                                        try xxdk.disableDirectMessages(channelId: channelId)
                                    }
                                } catch {
                                    print("Failed to toggle DM: \(error)")
                                    isDMEnabled = oldValue
                                }
                            }
                    }

                    if !isDM, let urlString = shareURL, let url = URL(string: urlString) {
                        ShareLink(item: url) {
                            HStack {
                                Text(verbatim: urlString)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                        .tint(.haven)

                        if let password = sharePassword, !password.isEmpty {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text("Password")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        SecretBadge()
                                    }
                                    Text(password)
                                        .font(.body)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Spacer()
                                Button {
                                    UIPasteboard.general.string = password
                                    toastMessage = "Password copied"
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                    .foregroundColor(.haven)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }
                .onAppear {
                    refreshAdminStatus()
                    guard let channelId = chat?.id else { return }
                    do {
                        isDMEnabled = try xxdk.areDMsEnabled(channelId: channelId)
                    } catch {
                        print("Failed to fetch DM status: \(error)")
                        isDMEnabled = false
                    }
                    do {
                        let shareData = try xxdk.getShareURL(channelId: channelId, host: "https://xxnetwork.com/join")
                        shareURL = shareData.url
                        sharePassword = shareData.password
                    } catch {
                        print("Failed to fetch share URL: \(error)")
                    }
                    do {
                        mutedUsers = try xxdk.getMutedUsers(channelId: channelId)
                    } catch {
                        print("Failed to fetch muted users: \(error)")
                    }
                    do {
                        channelNickname = try xxdk.getChannelNickname(channelId: channelId)
                    } catch {
                        print("Failed to fetch channel nickname: \(error)")
                    }
                }

                // Admin section - only visible for channel admins (not for DMs)
                if !isDM, let _ = chat?.id, isAdmin {
                    Section(header: Text("Admin")) {
                        Button {
                            showExportKeySheet = true
                        } label: {
                            HStack {
                                Image(systemName: "key.fill")
                                    .foregroundColor(.haven)
                                Text("Export Channel Key")
                                Spacer()
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tint(.primary)
                    }
                }

                // Muted Users section - only visible for admins (not for DMs)
                if !isDM, let _ = chat?.id, isAdmin {
                    Section(header: Text("Muted Users")) {
                        if mutedUsers.isEmpty {
                            Text("No muted users")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(mutedUsers, id: \.self) { pubKey in
                                MutedUserRow(pubKey: pubKey) {
                                    guard let channelId = chat?.id else { return }
                                    do {
                                        try xxdk.muteUser(channelId: channelId, pubKey: pubKey, mute: false)
                                        mutedUsers = try xxdk.getMutedUsers(channelId: channelId)
                                        withAnimation(.spring(response: 0.3)) {
                                            toastMessage = "User unmuted"
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                            withAnimation {
                                                toastMessage = nil
                                            }
                                        }
                                    } catch {
                                        print("Failed to unmute user: \(error)")
                                    }
                                }
                            }
                        }
                    }
                }

                // Import key section - only visible for non-admins and not for DMs
                if !isDM, let _ = chat?.id, !isAdmin {
                    Section {
                        Button {
                            showImportKeySheet = true
                        } label: {
                            HStack {
                                Image(systemName: "key.fill")
                                    .foregroundColor(.haven)
                                Text("Import Channel Key")
                                Spacer()
                                Image(systemName: "square.and.arrow.down")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tint(.primary)
                    }
                }

                // Chat Background section
                Section(header: Text("Appearance")) {
                    Button {
                        showBackgroundPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "paintbrush.fill")
                                .foregroundColor(.haven)
                            Text("Chat Background")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .tint(.primary)
                }

                Section {
                    Button(role: .destructive) {
                        if isDM {
                            showDeleteConfirmation = true
                        } else {
                            showLeaveConfirmation = true
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text(isDM ? "Delete Chat" : "Leave Channel")
                            Spacer()
                        }
                    }
                }
                .alert("Leave Channel", isPresented: $showLeaveConfirmation) {
                    Button("Cancel", role: .cancel) {}
                    Button("Leave", role: .destructive) {
                        onLeaveChannel()
                        dismiss()
                    }
                } message: {
                    Text("Are you sure you want to leave \"\(chat?.name ?? "this channel")\"?")
                }
                .alert("Delete Chat", isPresented: $showDeleteConfirmation) {
                    Button("Cancel", role: .cancel) {}
                    Button("Delete", role: .destructive) {
                        onDeleteChat?()
                        dismiss()
                    }
                } message: {
                    Text("Are you sure you want to delete this chat with \"\(chat?.name ?? "this contact")\"?")
                }
            }
            .navigationTitle(isDM ? "DM Options" : "Channel Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }.tint(.haven)
                }.hiddenSharedBackground()
            }
            .sheet(isPresented: $showExportKeySheet) {
                ExportChannelKeySheet(
                    channelId: chat?.id ?? "",
                    channelName: chat?.name ?? "Unknown",
                    xxdk: xxdk,
                    onSuccess: { message in
                        withAnimation(.spring(response: 0.3)) {
                            toastMessage = message
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                toastMessage = nil
                            }
                        }
                    }
                )
            }
            .sheet(isPresented: $showImportKeySheet) {
                ImportChannelKeySheet(
                    channelId: chat?.id ?? "",
                    channelName: chat?.name ?? "Unknown",
                    xxdk: xxdk,
                    onSuccess: { message in
                        chat?.isAdmin = true
                        refreshAdminStatus()
                        withAnimation(.spring(response: 0.3)) {
                            toastMessage = message
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                toastMessage = nil
                            }
                        }
                    }
                )
            }
            .sheet(isPresented: $showBackgroundPicker) {
                ChatBackgroundPickerView<T>()
            }
            .overlay {
                if let message = toastMessage {
                    VStack {
                        Spacer()
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.white)
                            Text(message)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(Color.haven)
                        .cornerRadius(25)
                        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
                        .padding(.bottom, 50)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .userMuteStatusChanged)) { notification in
                guard let channelId = chat?.id else { return }
                if let notificationChannelID = notification.userInfo?["channelID"] as? String,
                   notificationChannelID == channelId
                {
                    do {
                        mutedUsers = try xxdk.getMutedUsers(channelId: channelId)
                    } catch {
                        print("Failed to refresh muted users: \(error)")
                    }
                }
            }
        }
    }

    private func refreshAdminStatus() {
        isAdmin = chat?.isAdmin ?? false
    }

    private func saveNickname() {
        guard let channelId = chat?.id else { return }
        do {
            try xxdk.setChannelNickname(channelId: channelId, nickname: channelNickname)
            withAnimation(.spring(response: 0.3)) {
                toastMessage = "Nickname saved"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    toastMessage = nil
                }
            }
        } catch {
            print("Failed to save nickname: \(error)")
        }
    }
}

#Preview {
    ChannelOptionsPreviewWrapper()
        .mock()
}

private struct ChannelOptionsPreviewWrapper: View {
    @Query(filter: #Predicate<ChatModel> { $0.id == previewChatId }) private var chats: [ChatModel]
    
    var body: some View {
        if let chat = chats.first {
            ChannelOptionsView<XXDKMock>(chat: chat) {
            }
            .task {
                chat.channelDescription = "A channel for general team discussions and announcements"
            }
        } else {
            ProgressView()
        }
    }
}



