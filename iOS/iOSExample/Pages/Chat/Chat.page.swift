//
//  Chat.page.swift
//  iOSExample
//
//  Created by Om More on 22/09/25.
//

import SQLiteData
import SwiftUI

struct ChatView<T: XXDKP>: View {
    let chatId: String
    let chatTitle: String

    @EnvironmentObject var selectedChat: SelectedChat
    @Dependency(\.defaultDatabase) var database
    @FetchOne private var chat: ChatModel?

    private var isChannel: Bool {
        guard let chat else { return false }
        return chat.name != "<self>" && chat.dmToken == nil
    }

    @Environment(\.dismiss) private var dismiss
    @State private var replyingTo: ChatMessageModel? = nil
    @State private var showChannelOptions: Bool = false
    @State private var isAdmin: Bool = false
    @State private var isMuted: Bool = false
    @EnvironmentObject var xxdk: T

    private func markMessagesAsRead() {
        guard let chat else { return }
        let joinedAt = chat.joinedAt
        let chatId = chat.id

        guard
            let unreadMessages = try? database.read({ db in
                try ChatMessageModel.where { message in
                    message.chatId.eq(chatId) && message.isIncoming && !message.isRead
                        && message.timestamp > joinedAt
                }.fetchAll(db)
            }), !unreadMessages.isEmpty
        else { return }

        var updatedChat = chat
        updatedChat.unreadCount = 0

        try? database.write { db in
            for var message in unreadMessages {
                message.isRead = true
                try ChatMessageModel.update(message).execute(db)
            }
            try ChatModel.update(updatedChat).execute(db)
        }
    }

    init(chatId: String, chatTitle: String) {
        self.chatId = chatId
        self.chatTitle = chatTitle
        _chat = FetchOne(ChatModel.where { $0.id.eq(chatId) })
    }

    var body: some View {
        ZStack {
            ChatMessages(chatId: chatId) { message in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    replyingTo = message
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            if isMuted {
                HStack {
                    Image(systemName: "speaker.slash.fill")
                        .foregroundColor(.secondary)
                    Text("You are muted in this channel")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.ultraThinMaterial)
            } else {
                MessageForm<T>(
                    chat: chat,
                    replyTo: replyingTo,
                    onCancelReply: {
                        replyingTo = nil
                    }
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if selectedChat.chatId == chatId {
                        selectedChat.clear()
                    } else {
                        dismiss()
                    }
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.headline)
                    .foregroundStyle(.haven)
                }
            }
            ToolbarItem(placement: .principal) {
                Button {
                    showChannelOptions = true
                } label: {
                    HStack(spacing: 4) {
                        Text(chatTitle == "<self>" ? "Notes" : chatTitle)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                        if isChannel && chat?.isSecret == true {
                            SecretBadge()
                        }
                        if isChannel && isAdmin {
                            AdminBadge()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showChannelOptions) {
            ChannelOptionsView<T>(chat: chat) {
                Task {
                    do {
                        try xxdk.leaveChannel(channelId: chatId)
                        let chatsToDelete =
                            try? await database.read({ db in
                                try ChatModel.where { $0.id.eq(chatId) }.fetchAll(db)
                            })
                        if let chatsToDelete {
                            try? await database.write { db in
                                for chatToDelete in chatsToDelete {
                                    try ChatModel.delete(chatToDelete).execute(db)
                                }
                            }
                        }
                        await MainActor.run {
                            dismiss()
                        }
                    } catch {
                        AppLogger.channels.error(
                            "Failed to leave channel: \(error.localizedDescription, privacy: .public)"
                        )
                    }
                }
            }
            .environmentObject(xxdk)
        }
        .onAppear {
            isAdmin = chat?.isAdmin ?? false
            isMuted = isChannel ? xxdk.isMuted(channelId: chatId) : false
            // Mark all incoming messages as read
            markMessagesAsRead()
        }
        .onReceive(NotificationCenter.default.publisher(for: .userMuteStatusChanged)) {
            notification in
            if let channelID = notification.userInfo?["channelID"] as? String,
                channelID == chatId
            {
                guard isChannel else { return }
                isMuted = xxdk.isMuted(channelId: chatId)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .chatMessagesUpdated)) {
            notification in
            guard let updatedChatId = notification.userInfo?["chatId"] as? String,
                updatedChatId == chatId
            else { return }
            markMessagesAsRead()
        }
        .id("chat-\(chatId)")
        .onChange(of: showChannelOptions) { _, newValue in
            if !newValue {
                isAdmin = chat?.isAdmin ?? false
            }
        }
        .background(ChatBackgroundView())
        //        .background(
        //            NewChatBackSwipeControl(isDisabled: true)
        //                .allowsHitTesting(false)
        //        )
    }
}

#Preview {
    ChatView<XXDKMock>(
        chatId: previewChatId,
        chatTitle: "Mayur"
    )
    .mock()
}
