//
//  Chat.page.swift
//  iOSExample
//
//  Created by Om More on 22/09/25.
//

import SwiftData
import SwiftUI

struct ChatView<T: XXDKP>: View {
    let chatId: String
    let chatTitle: String

    @EnvironmentObject var selectedChat: SelectedChat
    @EnvironmentObject private var swiftDataActor: SwiftDataActor
    @Query private var chatResults: [ChatModel]
    @Query(sort: \ChatMessageModel.timestamp) private var messages: [ChatMessageModel]

    private var chat: ChatModel? { chatResults.first }

    private struct MessageDisplayInfo: Identifiable {
        let id: String
        let message: ChatMessageModel
        let showDateSeparator: Bool
        let isFirst: Bool
        let isFirstInGroup: Bool
        let isLastInGroup: Bool
        let showTimestamp: Bool
        let repliedToMessage: String?
    }

    private var displayMessages: [MessageDisplayInfo] {
        let calendar = Calendar.current
        let count = messages.count
        let messageById = Dictionary(uniqueKeysWithValues: messages.map { ($0.id, $0) })
        return messages.enumerated().map { index, msg in
            let prevMsg = index > 0 ? messages[index - 1] : nil
            let nextMsg = index < count - 1 ? messages[index + 1] : nil

            let showDateSeparator = prevMsg == nil || !calendar.isDate(msg.timestamp, inSameDayAs: prevMsg!.timestamp)

            let isFirstInGroup: Bool = {
                guard let prev = prevMsg else { return true }
                if showDateSeparator { return true }
                return msg.sender?.id != prev.sender?.id
            }()

            let isLastInGroup: Bool = {
                guard let next = nextMsg else { return true }
                if !calendar.isDate(msg.timestamp, inSameDayAs: next.timestamp) { return true }
                return msg.sender?.id != next.sender?.id
            }()

            let showTimestamp: Bool = {
                guard let next = nextMsg else { return true }
                if !calendar.isDate(msg.timestamp, inSameDayAs: next.timestamp) { return true }
                if msg.sender?.id != next.sender?.id { return true }
                let currentTime = DateFormatter.localizedString(from: msg.timestamp, dateStyle: .none, timeStyle: .short)
                let nextTime = DateFormatter.localizedString(from: next.timestamp, dateStyle: .none, timeStyle: .short)
                return currentTime != nextTime
            }()

            let repliedToMessage = msg.replyTo.flatMap { messageById[$0]?.message }

            return MessageDisplayInfo(
                id: msg.id,
                message: msg,
                showDateSeparator: showDateSeparator,
                isFirst: index == 0,
                isFirstInGroup: isFirstInGroup,
                isLastInGroup: isLastInGroup,
                showTimestamp: showTimestamp,
                repliedToMessage: repliedToMessage
            )
        }
    }

    private var isChannel: Bool {
        guard let chat else { return false }
        return chat.name != "<self>" && chat.dmToken == nil
    }

    @Environment(\.dismiss) private var dismiss
    @State var abc: String = ""
    @State private var replyingTo: ChatMessageModel? = nil
    @State private var showChannelOptions: Bool = false
    @State private var visibleDate: Date? = nil
    @State private var showDateHeader: Bool = false
    @State private var hideTask: Task<Void, Never>? = nil
    @State private var scrollingToOlder: Bool = true
    @State private var topVisibleMessageId: String?
    @State private var isAdmin: Bool = false
    @State private var toastMessage: String? = nil
    @State private var isMuted: Bool = false
    @State private var mutedUsers: [Data] = []
    @State private var highlightedMessageId: String? = nil
    @State private var fileDataRefreshTrigger: Int = 0
    @EnvironmentObject var xxdk: T

    private func markMessagesAsRead() {
        guard let chat else { return }
        let unreadMessages = chat.messages.filter { $0.isIncoming && !$0.isRead && $0.timestamp > chat.joinedAt }
        guard !unreadMessages.isEmpty else { return }

        for message in unreadMessages {
            message.isRead = true
        }
        chat.unreadCount = 0
        try? swiftDataActor.save()
    }

    func createDMChatAndNavigate(codename: String, dmToken: Int32, pubKey: Data, color: Int) {
        // Create a new DM chat
        let dmChat = ChatModel(pubKey: pubKey, name: codename, dmToken: dmToken, color: color)

        do {
            swiftDataActor.insert(dmChat)
            try swiftDataActor.save()

            // Navigate to the new chat using SelectedChat
            selectedChat.select(id: dmChat.id, title: dmChat.name)
        } catch {
            AppLogger.chat.error("Failed to create DM chat: \(error.localizedDescription, privacy: .public)")
        }
    }

    init(chatId: String, chatTitle: String) {
        self.chatId = chatId
        self.chatTitle = chatTitle
        _chatResults = Query(
            filter: #Predicate<ChatModel> { chat in
                chat.id == chatId
            }
        )
        _messages = Query(
            filter: #Predicate<ChatMessageModel> { message in
                message.chat.id == chatId
            },
            sort: \ChatMessageModel.timestamp
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            if messages.isEmpty {
                EmptyChatView()
            } else {
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(displayMessages) { info in
                                if info.showDateSeparator {
                                    DateSeparatorBadge(date: info.message.timestamp, isFirst: info.isFirst)
                                }

                                ChatMessageRow<T>(
                                    result: info.message,
                                    isAdmin: isAdmin,
                                    isFirstInGroup: info.isFirstInGroup,
                                    isLastInGroup: info.isLastInGroup,
                                    showTimestamp: info.showTimestamp,
                                    repliedToMessage: info.repliedToMessage,
                                    onReply: { message in
                                        replyingTo = message
                                    },
                                    onDM: { codename, dmToken, pubKey, color in
                                        createDMChatAndNavigate(
                                            codename: codename,
                                            dmToken: dmToken,
                                            pubKey: pubKey, color: color
                                        )
                                    },
                                    onDelete: { message in
                                        xxdk.deleteMessage(channelId: chatId, messageId: message.id)
                                    },
                                    onMute: { pubKey in
                                        do {
                                            try xxdk.muteUser(channelId: chatId, pubKey: pubKey, mute: true)
                                            withAnimation(.spring(response: 0.3)) {
                                                toastMessage = "User muted"
                                            }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                                withAnimation {
                                                    toastMessage = nil
                                                }
                                            }
                                        } catch {
                                            AppLogger.channels.error("Failed to mute user: \(error.localizedDescription, privacy: .public)")
                                        }
                                    },
                                    onUnmute: { pubKey in
                                        do {
                                            try xxdk.muteUser(channelId: chatId, pubKey: pubKey, mute: false)
                                            withAnimation(.spring(response: 0.3)) {
                                                toastMessage = "User unmuted"
                                            }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                                withAnimation {
                                                    toastMessage = nil
                                                }
                                            }
                                        } catch {
                                            AppLogger.channels.error("Failed to unmute user: \(error.localizedDescription, privacy: .public)")
                                        }
                                    },
                                    mutedUsers: mutedUsers,
                                    highlightedMessageId: highlightedMessageId,
                                    onScrollToReply: { messageId in
                                        highlightedMessageId = messageId
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            scrollProxy.scrollTo(messageId, anchor: .center)
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                            withAnimation(.easeOut(duration: 0.3)) {
                                                highlightedMessageId = nil
                                            }
                                        }
                                    }
                                )
                            }
                            Spacer()
                        }.padding().scrollTargetLayout()
                    }
                    .scrollPosition(id: $topVisibleMessageId, anchor: .top)
                }
                .onChange(of: topVisibleMessageId) { _, newId in
                    guard let newId,
                          let message = messages.first(where: { $0.id == newId })
                    else { return }

                    let date = message.timestamp
                    if let oldDate = visibleDate {
                        scrollingToOlder = date < oldDate
                    }
                    withAnimation(.spring(duration: 0.35)) {
                        visibleDate = date
                    }
                    showDateHeader = true

                    // Cancel previous hide task and schedule new one
                    hideTask?.cancel()
                    hideTask = Task {
                        try? await Task.sleep(for: .seconds(4))
                        if !Task.isCancelled {
                            await MainActor.run {
                                showDateHeader = false
                            }
                        }
                    }
                }
                .defaultScrollAnchor(.bottom)

                // Floating date header
                FloatingDateHeader(date: visibleDate, scrollingToOlder: scrollingToOlder)
                    .padding(.top, 14)
                    .opacity(showDateHeader ? 1 : 0)
                    .animation(.easeOut(duration: 0.3), value: showDateHeader)
                    .animation(.spring(duration: 0.35), value: visibleDate?.formatted(date: .complete, time: .omitted))
            }
        }
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

                        let descriptor = FetchDescriptor<ChatModel>(predicate: #Predicate { $0.id == chatId })
                        let chatsToDelete = try swiftDataActor.fetch(descriptor)

                        for chatToDelete in chatsToDelete {
                            swiftDataActor.delete(chatToDelete)
                        }

                        try? swiftDataActor.save()

                        await MainActor.run {
                            dismiss()
                        }
                    } catch {
                        AppLogger.channels.error("Failed to leave channel: \(error.localizedDescription, privacy: .public)")
                    }
                }
            }
            .environmentObject(xxdk)
        }
        .onAppear {
            isAdmin = chat?.isAdmin ?? false
            isMuted = xxdk.isMuted(channelId: chatId)
            do {
                mutedUsers = try xxdk.getMutedUsers(channelId: chatId)
            } catch {
                AppLogger.channels.error("Failed to fetch muted users: \(error.localizedDescription, privacy: .public)")
            }
            // Mark all incoming messages as read
            markMessagesAsRead()
        }
        .onReceive(NotificationCenter.default.publisher(for: .userMuteStatusChanged)) { notification in
            if let channelID = notification.userInfo?["channelID"] as? String,
               channelID == chatId
            {
                isMuted = xxdk.isMuted(channelId: chatId)
                do {
                    mutedUsers = try xxdk.getMutedUsers(channelId: chatId)
                } catch {
                    AppLogger.channels.error("Failed to refresh muted users: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .fileDataUpdated)) { _ in
            // Delay slightly to allow SwiftData to sync from background context
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                fileDataRefreshTrigger += 1
            }
        }
        .id("chat-\(chatId)-\(fileDataRefreshTrigger)")
        .onChange(of: showChannelOptions) { _, newValue in
            if !newValue {
                isAdmin = chat?.isAdmin ?? false
            }
        }
        .background(ChatBackgroundView())
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
                    .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}

#Preview {
    ChatView<XXDKMock>(
        chatId: previewChatId,
        chatTitle: "Mayur"
    )
    .mock()
}
