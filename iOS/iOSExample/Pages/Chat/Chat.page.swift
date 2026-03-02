//
//  Chat.page.swift
//  iOSExample
//
//  Created by Om More on 22/09/25.
//

import SwiftUI

struct ChatView<T: XXDKP>: View {
    let chatId: String
    let chatTitle: String

    private final class ScrollTracker {
        var topVisibleMessageId: String?
        var pendingDateUpdateTask: Task<Void, Never>?
        var hideHeaderTask: Task<Void, Never>?
    }

    @EnvironmentObject var selectedChat: SelectedChat
    @EnvironmentObject var chatStore: ChatStore
    @State private var chat: ChatModel?

    private let messagesPageSize = 120

    private struct MessageCursor {
        let timestamp: Date
        let internalId: Int64
    }

    private var isChannel: Bool {
        guard let chat else { return false }
        return chat.name != "<self>" && chat.dmToken == nil
    }

    private struct MessageDisplayInfo: Identifiable {
        let id: String
        let message: ChatMessageModel
        let sender: MessageSenderModel?
        let showDateSeparator: Bool
        let isFirst: Bool
        let isFirstInGroup: Bool
        let isLastInGroup: Bool
        let showTimestamp: Bool
        let repliedToMessage: String?
        let reactions: [MessageReactionModel]
    }

    private func buildDisplayMessages(from messages: [ChatMessageModel], senders: [String: MessageSenderModel], reactions: [String: [MessageReactionModel]]) -> [MessageDisplayInfo] {
        let calendar = Calendar.current
        let count = messages.count
        let messageById = Dictionary(uniqueKeysWithValues: messages.map { ($0.id, $0) })
        return messages.enumerated().map { index, msg in
            let prevMsg = index > 0 ? messages[index - 1] : nil
            let nextMsg = index < count - 1 ? messages[index + 1] : nil
            let sender = msg.senderId.flatMap { senders[$0] }

            let showDateSeparator = prevMsg == nil || !calendar.isDate(msg.timestamp, inSameDayAs: prevMsg!.timestamp)

            let isFirstInGroup: Bool = {
                guard let prev = prevMsg else { return true }
                if showDateSeparator { return true }
                return msg.senderId != prev.senderId
            }()

            let isLastInGroup: Bool = {
                guard let next = nextMsg else { return true }
                if !calendar.isDate(msg.timestamp, inSameDayAs: next.timestamp) { return true }
                return msg.senderId != next.senderId
            }()

            let showTimestamp: Bool = {
                guard let next = nextMsg else { return true }
                if !calendar.isDate(msg.timestamp, inSameDayAs: next.timestamp) { return true }
                if msg.senderId != next.senderId { return true }
                let currentTime = DateFormatter.localizedString(from: msg.timestamp, dateStyle: .none, timeStyle: .short)
                let nextTime = DateFormatter.localizedString(from: next.timestamp, dateStyle: .none, timeStyle: .short)
                return currentTime != nextTime
            }()

            let repliedToMessage = msg.replyTo.flatMap { messageById[$0]?.message }

            return MessageDisplayInfo(
                id: msg.id,
                message: msg,
                sender: sender,
                showDateSeparator: showDateSeparator,
                isFirst: index == 0,
                isFirstInGroup: isFirstInGroup,
                isLastInGroup: isLastInGroup,
                showTimestamp: showTimestamp,
                repliedToMessage: repliedToMessage,
                reactions: reactions[msg.id] ?? []
            )
        }
    }

    @Environment(\.dismiss) private var dismiss
    @State var abc: String = ""
    @State private var replyingTo: ChatMessageModel? = nil
    @State private var replyingToSenderName: String? = nil
    @State private var showChannelOptions: Bool = false
    @State private var visibleDate: Date? = nil
    @State private var showDateHeader: Bool = false
    @State private var scrollingToOlder: Bool = true
    @State private var scrollTracker = ScrollTracker()
    @State private var isAdmin: Bool = false
    @State private var toastMessage: String? = nil
    @State private var isMuted: Bool = false
    @State private var mutedUsers: [Data] = []
    @State private var highlightedMessageId: String? = nil
    @State private var pagedMessageIds: [String] = []
    @State private var messages: [ChatMessageModel] = []
    @State private var senderCache: [String: MessageSenderModel] = [:]
    @State private var isLoadingInitialMessages: Bool = false
    @State private var isLoadingOlderMessages: Bool = false
    @State private var isRefreshingNewerMessages: Bool = false
    @State private var isRefreshingBackfilledOlderMessages: Bool = false
    @State private var isRefreshingInRangeMessages: Bool = false
    @State private var isMessagesListScrolling: Bool = false
    @State private var hasDeferredChatRefresh: Bool = false
    @State private var targetScrollMessageId: String? = nil
    @State private var hasMoreOlderMessages: Bool = true
    @State private var cachedDisplayMessages: [MessageDisplayInfo] = []
    @State private var messageDateLookup: [String: Date] = [:]
    @State private var reactionsByMessageId: [String: [MessageReactionModel]] = [:]
    @State private var selectedReactionsMessageId: String? = nil
    @EnvironmentObject var xxdk: T

    private func showToast(_ message: String) {
        withAnimation(.spring(response: 0.3)) {
            toastMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                toastMessage = nil
            }
        }
    }

    private func markMessagesAsRead() {
        guard chat != nil else { return }
        try? chatStore.markMessagesAsRead(chatId: chatId)
        chat = try? chatStore.fetchChat(id: chatId)
    }

    @MainActor
    func createDMChatAndNavigate(codename: String, dmToken: Int32, pubKey: Data, color: Int) {
        let dmChat = ChatModel(pubKey: pubKey, name: codename, dmToken: dmToken, color: color)

        do {
            try chatStore.insertChat(dmChat)
            selectedChat.select(id: dmChat.id, title: dmChat.name)
        } catch {
            AppLogger.chat.error("Failed to create DM chat: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func deleteMessage(_ message: ChatMessageModel) {
        xxdk.deleteMessage(channelId: chatId, messageId: message.id)
        showToast("Delete requested")
    }

    private func setMuteState(for pubKey: Data, muted: Bool) {
        do {
            try xxdk.muteUser(channelId: chatId, pubKey: pubKey, mute: muted)
            mutedUsers = try xxdk.getMutedUsers(channelId: chatId)
            showToast(muted ? "User muted" : "User unmuted")
        } catch {
            AppLogger.channels.error("Failed to update mute state: \(error.localizedDescription, privacy: .public)")
        }
    }

    init(chatId: String, chatTitle: String) {
        self.chatId = chatId
        self.chatTitle = chatTitle
    }

    private func onTopVisibleMessageChanged(_ messageId: String?) {
        if scrollTracker.topVisibleMessageId == messageId {
            return
        }
        scrollTracker.topVisibleMessageId = messageId
        guard let messageId else {
            scrollTracker.pendingDateUpdateTask?.cancel()
            return
        }
        scrollTracker.pendingDateUpdateTask?.cancel()

        scrollTracker.pendingDateUpdateTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled,
                  let date = messageDateLookup[messageId]
            else { return }

            let calendar = Calendar.current
            let dayDate = calendar.startOfDay(for: date)
            if let oldDate = visibleDate {
                scrollingToOlder = dayDate < oldDate
            }
            if visibleDate != dayDate {
                visibleDate = dayDate
            }
            if !showDateHeader {
                showDateHeader = true
            }

            scrollTracker.hideHeaderTask?.cancel()
            scrollTracker.hideHeaderTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.2))
                guard !Task.isCancelled else { return }
                showDateHeader = false
            }
        }
    }

    private var oldestCursor: MessageCursor? {
        guard let first = messages.first else { return nil }
        return MessageCursor(timestamp: first.timestamp, internalId: first.internalId)
    }

    private var newestCursor: MessageCursor? {
        guard let last = messages.last else { return nil }
        return MessageCursor(timestamp: last.timestamp, internalId: last.internalId)
    }

    @MainActor
    private func refreshMessageDateLookup() {
        messageDateLookup = Dictionary(uniqueKeysWithValues: messages.map { ($0.id, $0.timestamp) })
    }

    @MainActor
    private func refreshVisibleReactions() {
        guard !pagedMessageIds.isEmpty else {
            reactionsByMessageId = [:]
            return
        }
        reactionsByMessageId = (try? chatStore.fetchReactions(targetMessageIds: pagedMessageIds)) ?? [:]
    }

    @MainActor
    private func refreshSenderCache() {
        let senderIds = Set(messages.compactMap(\.senderId))
        let newIds = senderIds.subtracting(senderCache.keys)
        guard !newIds.isEmpty else { return }
        if let fetched = try? chatStore.fetchSenders(ids: Array(newIds)) {
            senderCache.merge(fetched) { _, new in new }
        }
    }

    private func groupedReactionsForSheet(messageId: String) -> [(emoji: String, reactions: [MessageReactionModel])] {
        let reactions = reactionsByMessageId[messageId] ?? []
        return Dictionary(grouping: reactions, by: { $0.emoji })
            .map { (emoji: $0.key, reactions: $0.value) }
            .sorted {
                if $0.reactions.count == $1.reactions.count {
                    return $0.emoji < $1.emoji
                }
                return $0.reactions.count > $1.reactions.count
            }
    }

    // MARK: - Paging

    @MainActor
    private func fetchLatestMessages(limit: Int) -> [ChatMessageModel] {
        (try? chatStore.fetchLatestMessages(chatId: chatId, limit: limit)) ?? []
    }

    @MainActor
    private func fetchOlderMessages(before cursor: MessageCursor, limit: Int) -> [ChatMessageModel] {
        (try? chatStore.fetchOlderMessages(chatId: chatId, beforeTimestamp: cursor.timestamp, beforeInternalId: cursor.internalId, limit: limit)) ?? []
    }

    @MainActor
    private func fetchNewerMessages(after cursor: MessageCursor, limit: Int) -> [ChatMessageModel] {
        (try? chatStore.fetchNewerMessages(chatId: chatId, afterTimestamp: cursor.timestamp, afterInternalId: cursor.internalId, limit: limit)) ?? []
    }

    @MainActor
    private func fetchMessagesInLoadedWindow(oldest: MessageCursor, newest: MessageCursor) -> [ChatMessageModel] {
        (try? chatStore.fetchMessagesInRange(chatId: chatId, oldestTimestamp: oldest.timestamp, oldestInternalId: oldest.internalId, newestTimestamp: newest.timestamp, newestInternalId: newest.internalId)) ?? []
    }

    @MainActor
    private func mergePagedMessageIdsChronologically(with newMessages: [ChatMessageModel]) {
        guard !newMessages.isEmpty else { return }
        let existingIds = Set(pagedMessageIds)
        let uniqueNew = newMessages.filter { !existingIds.contains($0.id) }
        guard !uniqueNew.isEmpty else { return }

        messages.append(contentsOf: uniqueNew)
        messages.sort {
            if $0.timestamp == $1.timestamp { return $0.internalId < $1.internalId }
            return $0.timestamp < $1.timestamp
        }
        pagedMessageIds = messages.map(\.id)
        refreshMessageDateLookup()
        refreshSenderCache()
        refreshVisibleReactions()
    }

    @MainActor
    private func reloadMessagesFromPageIds() {
        guard !pagedMessageIds.isEmpty else {
            messages = []
            refreshMessageDateLookup()
            refreshVisibleReactions()
            return
        }

        let fetched = (try? chatStore.fetchMessages(ids: pagedMessageIds)) ?? []
        let byId = Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) })
        messages = pagedMessageIds.compactMap { byId[$0] }
        refreshMessageDateLookup()
        refreshSenderCache()
        refreshVisibleReactions()
    }

    private func loadInitialMessagesIfNeeded() {
        guard !isLoadingInitialMessages, pagedMessageIds.isEmpty else { return }
        isLoadingInitialMessages = true

        Task(priority: .userInitiated) { @MainActor in
            let initialBatch = fetchLatestMessages(limit: messagesPageSize)
            pagedMessageIds = initialBatch.map(\.id)
            messages = initialBatch
            hasMoreOlderMessages = initialBatch.count == messagesPageSize
            refreshMessageDateLookup()
            refreshSenderCache()
            refreshVisibleReactions()
            isLoadingInitialMessages = false
        }
    }

    private func loadOlderMessagesIfNeeded() {
        guard !isLoadingOlderMessages, hasMoreOlderMessages else { return }
        guard let cursor = oldestCursor else { return }
        isLoadingOlderMessages = true

        Task(priority: .utility) { @MainActor in
            let olderBatch = fetchOlderMessages(before: cursor, limit: messagesPageSize)
            mergePagedMessageIdsChronologically(with: olderBatch)

            if olderBatch.count < messagesPageSize {
                hasMoreOlderMessages = false
            }
            isLoadingOlderMessages = false
        }
    }

    private func refreshNewerMessages() {
        guard !isRefreshingNewerMessages, !isLoadingInitialMessages else { return }
        guard var cursor = newestCursor else {
            loadInitialMessagesIfNeeded()
            return
        }

        isRefreshingNewerMessages = true

        Task(priority: .utility) { @MainActor in
            var appended: [ChatMessageModel] = []

            while true {
                let batch = fetchNewerMessages(after: cursor, limit: messagesPageSize)
                guard !batch.isEmpty else { break }
                appended.append(contentsOf: batch)
                guard batch.count == messagesPageSize, let newest = batch.last else { break }
                cursor = MessageCursor(timestamp: newest.timestamp, internalId: newest.internalId)
            }

            mergePagedMessageIdsChronologically(with: appended)
            isRefreshingNewerMessages = false
            refreshInRangeMessagesIfNeeded()
        }
    }

    private func refreshBackfilledOlderMessagesIfNeeded() {
        guard !isRefreshingBackfilledOlderMessages,
              !isLoadingInitialMessages,
              !isLoadingOlderMessages,
              !pagedMessageIds.isEmpty,
              !hasMoreOlderMessages,
              let cursor = oldestCursor
        else { return }

        isRefreshingBackfilledOlderMessages = true

        Task(priority: .utility) { @MainActor in
            let olderBatch = fetchOlderMessages(before: cursor, limit: messagesPageSize)
            mergePagedMessageIdsChronologically(with: olderBatch)
            hasMoreOlderMessages = olderBatch.count == messagesPageSize
            isRefreshingBackfilledOlderMessages = false
            refreshInRangeMessagesIfNeeded()
        }
    }

    private func refreshInRangeMessagesIfNeeded() {
        guard !isRefreshingInRangeMessages,
              !isLoadingInitialMessages,
              !isLoadingOlderMessages,
              !isRefreshingNewerMessages,
              !isRefreshingBackfilledOlderMessages,
              !pagedMessageIds.isEmpty,
              let oldest = oldestCursor,
              let newest = newestCursor
        else { return }

        isRefreshingInRangeMessages = true

        Task(priority: .utility) { @MainActor in
            let inRangeBatch = fetchMessagesInLoadedWindow(oldest: oldest, newest: newest)
            mergePagedMessageIdsChronologically(with: inRangeBatch)
            isRefreshingInRangeMessages = false
        }
    }

    @MainActor
    private func refreshChatMessagesNow() {
        refreshNewerMessages()
        refreshBackfilledOlderMessagesIfNeeded()
        refreshInRangeMessagesIfNeeded()
        refreshVisibleReactions()
    }

    private func parseMessageInternalId(from userInfo: [AnyHashable: Any]) -> Int64? {
        if let id = userInfo["messageInternalId"] as? Int64 {
            return id
        }
        if let id = userInfo["messageInternalId"] as? Int {
            return Int64(id)
        }
        if let id = userInfo["messageInternalId"] as? NSNumber {
            return id.int64Value
        }
        if let idString = userInfo["messageInternalId"] as? String {
            return Int64(idString)
        }
        return nil
    }

    @MainActor
    private func applyMessageUpdateIfLoaded(internalId: Int64) -> Bool {
        guard let messageIndex = messages.firstIndex(where: { $0.internalId == internalId }) else { return false }

        guard let refreshed = try? chatStore.fetchMessage(internalId: internalId) else { return false }

        let oldMessageId = messages[messageIndex].id
        messages[messageIndex] = refreshed

        if let pagedIndex = pagedMessageIds.firstIndex(of: oldMessageId) {
            pagedMessageIds[pagedIndex] = refreshed.id
        }
        if oldMessageId != refreshed.id {
            refreshMessageDateLookup()
            refreshVisibleReactions()
        }

        messages = Array(messages)
        return true
    }

    @MainActor
    private func scrollToMessage(_ messageId: String) {
        if pagedMessageIds.contains(messageId) {
            targetScrollMessageId = messageId
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                targetScrollMessageId = nil
            }
        } else {
            showToast("Message is not loaded")
        }
    }

    var body: some View {
        ZStack {
            if isLoadingInitialMessages && messages.isEmpty {
                ProgressView()
            } else if messages.isEmpty {
                EmptyChatView()
            } else {
                List(messages, id: \.id) { message in
                    let sender = message.senderId.flatMap { senderCache[$0] }
                    VStack(alignment: message.isIncoming ? .leading : .trailing, spacing: 4) {
                        if let sender {
                            Text(sender.codename)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text(message.message)
                            .padding(8)
                            .background(message.isIncoming ? Color(.systemGray5) : Color.blue.opacity(0.2))
                            .cornerRadius(8)
                        Text(message.timestamp, style: .time)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: message.isIncoming ? .leading : .trailing)
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .top) {
            if showDateHeader {
                FloatingDateHeader(
                    date: visibleDate,
                    scrollingToOlder: scrollingToOlder
                )
                .padding(.top, 8)
                .allowsHitTesting(false)
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
                    replyToSenderName: replyingToSenderName,
                    onCancelReply: {
                        replyingTo = nil
                        replyingToSenderName = nil
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
        .sheet(
            isPresented: Binding(
                get: { selectedReactionsMessageId != nil },
                set: { isPresented in
                    if !isPresented {
                        selectedReactionsMessageId = nil
                    }
                }
            )
        ) {
            if let messageId = selectedReactionsMessageId {
                ReactorsSheet(
                    groupedReactions: groupedReactionsForSheet(messageId: messageId),
                    selectedEmoji: nil
                )
                .presentationDetents([.medium, .large])
            }
        }
        .sheet(isPresented: $showChannelOptions) {
            ChannelOptionsView<T>(chat: chat) {
                Task {
                    do {
                        try xxdk.leaveChannel(channelId: chatId)
                        try chatStore.deleteChat(id: chatId)
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
            chat = try? chatStore.fetchChat(id: chatId)
            loadInitialMessagesIfNeeded()
            isAdmin = chat?.isAdmin ?? false
            if isChannel {
                isMuted = xxdk.isMuted(channelId: chatId)
                do {
                    mutedUsers = try xxdk.getMutedUsers(channelId: chatId)
                } catch {
                    AppLogger.channels.error("Failed to fetch muted users: \(error.localizedDescription, privacy: .public)")
                }
            } else {
                isMuted = false
                mutedUsers = []
            }
            markMessagesAsRead()
        }
        .onReceive(NotificationCenter.default.publisher(for: .userMuteStatusChanged)) { notification in
            if let channelID = notification.userInfo?["channelID"] as? String,
               channelID == chatId
            {
                guard isChannel else { return }
                isMuted = xxdk.isMuted(channelId: chatId)
                do {
                    mutedUsers = try xxdk.getMutedUsers(channelId: chatId)
                } catch {
                    AppLogger.channels.error("Failed to refresh muted users: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .chatMessagesUpdated)) { notification in
            guard let updatedChatId = notification.userInfo?["chatId"] as? String,
                  updatedChatId == chatId
            else { return }
            guard !isMessagesListScrolling else {
                hasDeferredChatRefresh = true
                return
            }
            if let userInfo = notification.userInfo,
               let internalId = parseMessageInternalId(from: userInfo)
            {
                _ = applyMessageUpdateIfLoaded(internalId: internalId)
                return
            }
            refreshChatMessagesNow()
        }
        .id("chat-\(chatId)")
        .onChange(of: showChannelOptions) { _, newValue in
            if !newValue {
                chat = try? chatStore.fetchChat(id: chatId)
                isAdmin = chat?.isAdmin ?? false
            }
        }
        .background(ChatBackgroundView())
        .overlay {
            if let toastMessage {
                VStack {
                    Spacer()
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                        Text(toastMessage)
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
