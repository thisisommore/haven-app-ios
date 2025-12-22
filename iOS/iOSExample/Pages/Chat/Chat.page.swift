//
//  Chat.page.swift
//  iOSExample
//
//  Created by Om More on 22/09/25.
//

import SwiftData
import SwiftUI

struct FloatingDateHeader: View {
    let date: Date?
    let scrollingToOlder: Bool

    private var dateText: String {
        guard let date else { return "" }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = calendar.isDate(date, equalTo: Date(), toGranularity: .year) ? "EEE d MMM" : "EEE d MMM yyyy"
            return formatter.string(from: date)
        }
    }

    var body: some View {
        if date != nil {
            Text(dateText)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                .id(dateText)
                .transition(.asymmetric(
                    insertion: .opacity,
                    removal: .offset(y: scrollingToOlder ? 30 : -30).combined(with: .opacity)
                ))
        }
    }
}

struct DateSeparatorBadge: View {
    let date: Date
    let isFirst: Bool

    private var dateText: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = calendar.isDate(date, equalTo: Date(), toGranularity: .year) ? "EEE d MMM" : "EEE d MMM yyyy"
            return formatter.string(from: date)
        }
    }

    var body: some View {
        HStack {
            Spacer()
            Text(dateText)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            Spacer()
        }
        .padding(.top, isFirst ? 0 : 28)
        .padding(.bottom, 12)
    }
}

struct VisibleMessagePreferenceKey: PreferenceKey {
    static var defaultValue: Date? = nil
    static func reduce(value: inout Date?, nextValue: () -> Date?) {
        // Keep the earliest (topmost) visible message date
        if let next = nextValue() {
            if value == nil || next < value! {
                value = next
            }
        }
    }
}

struct EmptyChatView: View {
    var body: some View {
        VStack {
            Spacer()
            Text("No messages yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .clipShape(Capsule())
            Spacer()
        }
    }
}

struct ChatView<T: XXDKP>: View {
    let width: CGFloat
    let chatId: String
    let chatTitle: String

    @EnvironmentObject var selectedChat: SelectedChat
    @EnvironmentObject private var swiftDataActor: SwiftDataActor
    @Query private var chatResults: [ChatModel]
    @Query private var allMessages: [ChatMessageModel]

    private var chat: ChatModel? { chatResults.first }
    private var messages: [ChatMessageModel] {
        // Filter messages for this chat - using @Query ensures updates trigger refresh
        let chatMessages = allMessages.filter { $0.chat.id == chatId }
        return chatMessages.sorted { $0.timestamp < $1.timestamp }
    }

    private var isChannel: Bool {
        guard let chat else { return false }
        return chat.name != "<self>" && chat.dmToken == nil
    }

    @Environment(\.dismiss) private var dismiss
    @State var abc: String = ""
    @State private var replyingTo: ChatMessageModel? = nil
    @State private var showChannelOptions: Bool = false
    @State private var navigateToDMChat: ChatModel? = nil
    @State private var visibleDate: Date? = nil
    @State private var showDateHeader: Bool = false
    @State private var hideTask: Task<Void, Never>? = nil
    @State private var scrollingToOlder: Bool = true
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

            // Navigate to the new chat using the created chat object
            navigateToDMChat = dmChat
        } catch {
            print("Failed to create DM chat: \(error)")
        }
    }

    init(width: CGFloat, chatId: String, chatTitle: String) {
        self.width = width
        self.chatId = chatId
        self.chatTitle = chatTitle
        _chatResults = Query(
            filter: #Predicate<ChatModel> { chat in
                chat.id == chatId
            }
        )
        // Query all messages - ensures fileData updates trigger view refresh
        _allMessages = Query()
    }

    var body: some View {
        ZStack(alignment: .top) {
            if messages.isEmpty {
                EmptyChatView()
            } else {
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(messages.enumerated()), id: \.element.id) { index, result in
                                // Show date separator if this is first message or date changed
                                let showDateSeparator = index == 0 || (index > 0 && index < messages.count && !Calendar.current.isDate(result.timestamp, inSameDayAs: messages[index - 1].timestamp))
                                if showDateSeparator {
                                    DateSeparatorBadge(date: result.timestamp, isFirst: index == 0)
                                }

                                // Show sender name only for first message in a group (same sender, same date)
                                let isFirstInGroup: Bool = {
                                    guard index > 0 else { return true }
                                    let prev = messages[index - 1]
                                    if showDateSeparator { return true }
                                    return result.sender?.id != prev.sender?.id
                                }()

                                // Check if this is last message in group
                                let isLastInGroup: Bool = {
                                    guard index < messages.count - 1 else { return true }
                                    let next = messages[index + 1]
                                    // Next message on different date
                                    if !Calendar.current.isDate(result.timestamp, inSameDayAs: next.timestamp) { return true }
                                    // Next message has different sender
                                    return result.sender?.id != next.sender?.id
                                }()

                                // Show timestamp only on the last message before (day OR sender OR time) changes
                                let showTimestamp: Bool = {
                                    guard index < messages.count - 1 else { return true }
                                    let next = messages[index + 1]
                                    // Next message on different date
                                    if !Calendar.current.isDate(result.timestamp, inSameDayAs: next.timestamp) { return true }
                                    // Next message has different sender
                                    if result.sender?.id != next.sender?.id { return true }
                                    // Next message has different time (short style, same as UI)
                                    let currentTime = DateFormatter.localizedString(from: result.timestamp, dateStyle: .none, timeStyle: .short)
                                    let nextTime = DateFormatter.localizedString(from: next.timestamp, dateStyle: .none, timeStyle: .short)
                                    return currentTime != nextTime
                                }()

                                ChatMessageRow(
                                    result: result,
                                    isAdmin: isAdmin,
                                    isFirstInGroup: isFirstInGroup,
                                    isLastInGroup: isLastInGroup,
                                    showTimestamp: showTimestamp,
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
                                            print("Failed to mute user: \(error)")
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
                                            print("Failed to unmute user: \(error)")
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
                                .background(
                                    GeometryReader { geo in
                                        let frame = geo.frame(in: .named("chatScroll"))
                                        Color.clear
                                            .preference(
                                                key: VisibleMessagePreferenceKey.self,
                                                value: frame.minY < 60 && frame.maxY > 0 ? result.timestamp : nil
                                            )
                                    }
                                )
                            }
                            Spacer()
                        }.padding().scrollTargetLayout()
                    }
                }
                .coordinateSpace(name: "chatScroll")
                .onPreferenceChange(VisibleMessagePreferenceKey.self) { date in
                    if let date {
                        // Determine scroll direction
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
                MessageForm<XXDK>(
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
                        print("Failed to leave channel: \(error)")
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
                print("Failed to fetch muted users: \(error)")
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
                    print("Failed to refresh muted users: \(error)")
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .fileDataUpdated)) { _ in
            // Delay slightly to allow SwiftData to sync from background context
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                print("[FT] ChatView received fileDataUpdated, refreshing (trigger=\(fileDataRefreshTrigger + 1))")
                fileDataRefreshTrigger += 1
            }
        }
        .id("chat-\(chatId)-\(fileDataRefreshTrigger)")
        .onChange(of: showChannelOptions) { _, newValue in
            if !newValue {
                isAdmin = chat?.isAdmin ?? false
            }
        }
        .navigationDestination(item: $navigateToDMChat) { dmChat in
            ChatView<XXDK>(
                width: width,
                chatId: dmChat.id,
                chatTitle: dmChat.name
            )
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
    // In-memory SwiftData container for previewing ChatView with mock data
    let (chat, mockMsgs, reactions) = createChatPreviewData()

    let container = try! ModelContainer(
        for: ChatModel.self,
        ChatMessageModel.self,
        MessageReactionModel.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    container.mainContext.insert(chat)
    mockMsgs.forEach { container.mainContext.insert($0) }
    reactions.forEach { container.mainContext.insert($0) }

    // Return the view wired up with our model container and mock XXDK service

    return NavigationStack {
        ChatView<XXDKMock>(
            width: UIScreen.w(100),
            chatId: chat.id,
            chatTitle: chat.name
        )
        .modelContainer(container)
        .environmentObject(SwiftDataActor(previewModelContainer: container))
        .environmentObject(XXDKMock())
        .environmentObject(SelectedChat())
    }
}
