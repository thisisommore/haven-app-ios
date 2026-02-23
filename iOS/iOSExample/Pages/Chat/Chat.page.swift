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

    private final class ScrollTracker {
        var topVisibleMessageId: String?
        var pendingDateUpdateTask: Task<Void, Never>?
        var hideHeaderTask: Task<Void, Never>?
    }

    @EnvironmentObject var selectedChat: SelectedChat
    @Environment(\.modelContext) private var modelContext
    @Query private var chatResults: [ChatModel]

    private let messagesPageSize = 120

    private struct MessageCursor {
        let timestamp: Date
        let internalId: Int64
    }

    private struct MessageIdentity {
        let id: String
        let timestamp: Date
        let internalId: Int64
    }

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
        let reactions: [MessageReactionModel]
    }

    private static func buildDisplayMessages(from messages: [ChatMessageModel], reactions: [MessageReactionModel] = []) -> [MessageDisplayInfo] {
        let reactionsByMessage = Dictionary(grouping: reactions, by: { $0.targetMessageId })
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
                repliedToMessage: repliedToMessage,
                reactions: reactionsByMessage[msg.id] ?? []
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
    @State private var scrollingToOlder: Bool = true
    @State private var scrollTracker = ScrollTracker()
    @State private var isAdmin: Bool = false
    @State private var toastMessage: String? = nil
    @State private var isMuted: Bool = false
    @State private var mutedUsers: [Data] = []
    @State private var highlightedMessageId: String? = nil
    @State private var pagedMessageIds: [String] = []
    @State private var messages: [ChatMessageModel] = []
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
        guard let chat else { return }
        let joinedAt = chat.joinedAt
        let chatId = chat.id

        let descriptor = FetchDescriptor<ChatMessageModel>(
            predicate: #Predicate { message in
                message.chat.id == chatId &&
                    message.isIncoming &&
                    !message.isRead &&
                    message.timestamp > joinedAt
            }
        )

        guard let unreadMessages = try? modelContext.fetch(descriptor),
              !unreadMessages.isEmpty
        else { return }

        for message in unreadMessages {
            message.isRead = true
        }
        chat.unreadCount = 0
        try? modelContext.save()
    }

    @MainActor
    func createDMChatAndNavigate(codename: String, dmToken: Int32, pubKey: Data, color: Int) {
        // Create a new DM chat
        let dmChat = ChatModel(pubKey: pubKey, name: codename, dmToken: dmToken, color: color)

        do {
            modelContext.insert(dmChat)
            try modelContext.save()

            // Navigate to the new chat using SelectedChat
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
        _chatResults = Query(
            filter: #Predicate<ChatModel> { chat in
                chat.id == chatId
            }
        )
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

        let visibleMessageIds = pagedMessageIds
        let descriptor = FetchDescriptor<MessageReactionModel>(
            predicate: #Predicate { reaction in
                visibleMessageIds.contains(reaction.targetMessageId)
            },
            sortBy: [
                SortDescriptor(\MessageReactionModel.internalId),
            ]
        )
        let fetchedReactions = (try? modelContext.fetch(descriptor)) ?? []
        reactionsByMessageId = Dictionary(grouping: fetchedReactions, by: { $0.targetMessageId })
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

    private var oldestCursor: MessageCursor? {
        guard let first = messages.first else { return nil }
        return MessageCursor(timestamp: first.timestamp, internalId: first.internalId)
    }

    private var newestCursor: MessageCursor? {
        guard let last = messages.last else { return nil }
        return MessageCursor(timestamp: last.timestamp, internalId: last.internalId)
    }

    @MainActor
    private func fetchLatestMessages(limit: Int) -> [MessageIdentity] {
        let currentChatId = chatId
        var descriptor = FetchDescriptor<ChatMessageModel>(
            predicate: #Predicate { message in
                message.chat.id == currentChatId
            },
            sortBy: [
                SortDescriptor(\ChatMessageModel.timestamp, order: .reverse),
                SortDescriptor(\ChatMessageModel.internalId, order: .reverse),
            ]
        )
        descriptor.fetchLimit = limit

        let newestFirst = (try? modelContext.fetch(descriptor)) ?? []
        let identities = newestFirst.map { message in
            MessageIdentity(
                id: message.id,
                timestamp: message.timestamp,
                internalId: message.internalId
            )
        }
        return Array(identities.reversed())
    }

    @MainActor
    private func fetchOlderMessages(before cursor: MessageCursor, limit: Int) -> [MessageIdentity] {
        let currentChatId = chatId
        let cursorTimestamp = cursor.timestamp
        let cursorInternalId = cursor.internalId
        var descriptor = FetchDescriptor<ChatMessageModel>(
            predicate: #Predicate { message in
                message.chat.id == currentChatId &&
                    (message.timestamp < cursorTimestamp ||
                        (message.timestamp == cursorTimestamp && message.internalId < cursorInternalId))
            },
            sortBy: [
                SortDescriptor(\ChatMessageModel.timestamp, order: .reverse),
                SortDescriptor(\ChatMessageModel.internalId, order: .reverse),
            ]
        )
        descriptor.fetchLimit = limit

        let olderDescending = (try? modelContext.fetch(descriptor)) ?? []
        let identities = olderDescending.map { message in
            MessageIdentity(
                id: message.id,
                timestamp: message.timestamp,
                internalId: message.internalId
            )
        }
        return Array(identities.reversed())
    }

    @MainActor
    private func fetchNewerMessages(after cursor: MessageCursor, limit: Int) -> [MessageIdentity] {
        let currentChatId = chatId
        let cursorTimestamp = cursor.timestamp
        let cursorInternalId = cursor.internalId
        var descriptor = FetchDescriptor<ChatMessageModel>(
            predicate: #Predicate { message in
                message.chat.id == currentChatId &&
                    (message.timestamp > cursorTimestamp ||
                        (message.timestamp == cursorTimestamp && message.internalId > cursorInternalId))
            },
            sortBy: [
                SortDescriptor(\ChatMessageModel.timestamp),
                SortDescriptor(\ChatMessageModel.internalId),
            ]
        )
        descriptor.fetchLimit = limit
        let newerAscending = (try? modelContext.fetch(descriptor)) ?? []
        return newerAscending.map { message in
            MessageIdentity(
                id: message.id,
                timestamp: message.timestamp,
                internalId: message.internalId
            )
        }
    }

    @MainActor
    private func fetchMessagesInLoadedWindow(oldest: MessageCursor, newest: MessageCursor) -> [MessageIdentity] {
        let currentChatId = chatId
        let oldestTimestamp = oldest.timestamp
        let oldestInternalId = oldest.internalId
        let newestTimestamp = newest.timestamp
        let newestInternalId = newest.internalId
        let descriptor = FetchDescriptor<ChatMessageModel>(
            predicate: #Predicate { message in
                message.chat.id == currentChatId &&
                    (message.timestamp > oldestTimestamp ||
                        (message.timestamp == oldestTimestamp && message.internalId >= oldestInternalId)) &&
                    (message.timestamp < newestTimestamp ||
                        (message.timestamp == newestTimestamp && message.internalId <= newestInternalId))
            },
            sortBy: [
                SortDescriptor(\ChatMessageModel.timestamp),
                SortDescriptor(\ChatMessageModel.internalId),
            ]
        )

        let inRangeMessages = (try? modelContext.fetch(descriptor)) ?? []
        return inRangeMessages.map { message in
            MessageIdentity(
                id: message.id,
                timestamp: message.timestamp,
                internalId: message.internalId
            )
        }
    }

    @MainActor
    private func mergePagedMessageIdsChronologically(with additionalIds: [String]) {
        guard !additionalIds.isEmpty else { return }

        let mergedIds = Array(Set(pagedMessageIds).union(additionalIds))
        var descriptor = FetchDescriptor<ChatMessageModel>(
            predicate: #Predicate { message in
                mergedIds.contains(message.id)
            },
            sortBy: [
                SortDescriptor(\ChatMessageModel.timestamp),
                SortDescriptor(\ChatMessageModel.internalId),
            ]
        )
        descriptor.fetchLimit = mergedIds.count

        guard let orderedMessages = try? modelContext.fetch(descriptor) else { return }
        pagedMessageIds = orderedMessages.map(\.id)
        messages = orderedMessages
        refreshMessageDateLookup()
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

        let ids = pagedMessageIds
        var descriptor = FetchDescriptor<ChatMessageModel>(
            predicate: #Predicate { message in
                ids.contains(message.id)
            },
            sortBy: [
                SortDescriptor(\ChatMessageModel.timestamp),
                SortDescriptor(\ChatMessageModel.internalId),
            ]
        )
        descriptor.fetchLimit = pagedMessageIds.count

        let fetched = (try? modelContext.fetch(descriptor)) ?? []
        let byId = Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) })
        messages = pagedMessageIds.compactMap { byId[$0] }
        refreshMessageDateLookup()
        refreshVisibleReactions()
    }

    private func loadInitialMessagesIfNeeded() {
        guard !isLoadingInitialMessages, pagedMessageIds.isEmpty else { return }
        isLoadingInitialMessages = true

        Task(priority: .userInitiated) { @MainActor in
            let initialBatch = fetchLatestMessages(limit: messagesPageSize)
            let initialIds = initialBatch.map(\.id)

            pagedMessageIds = initialIds
            reloadMessagesFromPageIds()
            hasMoreOlderMessages = initialBatch.count == messagesPageSize
            isLoadingInitialMessages = false
        }
    }

    private func loadOlderMessagesIfNeeded() {
        guard !isLoadingOlderMessages, hasMoreOlderMessages else { return }
        guard let cursor = oldestCursor else { return }
        isLoadingOlderMessages = true

        Task(priority: .utility) { @MainActor in
            let olderBatch = fetchOlderMessages(before: cursor, limit: messagesPageSize)
            let olderIds = olderBatch.map(\.id)

            let existingIds = Set(pagedMessageIds)
            let uniqueOlderIds = olderIds.filter { !existingIds.contains($0) }

            if !uniqueOlderIds.isEmpty {
                mergePagedMessageIdsChronologically(with: uniqueOlderIds)
            }

            if olderBatch.count < messagesPageSize || uniqueOlderIds.isEmpty {
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
            var appended: [MessageIdentity] = []

            while true {
                let batch = fetchNewerMessages(after: cursor, limit: messagesPageSize)
                guard !batch.isEmpty else { break }

                appended.append(contentsOf: batch)

                guard batch.count == messagesPageSize, let newest = batch.last else { break }
                cursor = MessageCursor(timestamp: newest.timestamp, internalId: newest.internalId)
            }

            let appendedIds = appended.map(\.id)

            let existingIds = Set(pagedMessageIds)
            let uniqueAppendedIds = appendedIds.filter { !existingIds.contains($0) }
            if !uniqueAppendedIds.isEmpty {
                mergePagedMessageIdsChronologically(with: uniqueAppendedIds)
            }
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
            let olderIds = olderBatch.map(\.id)
            let existingIds = Set(pagedMessageIds)
            let uniqueOlderIds = olderIds.filter { !existingIds.contains($0) }

            if !uniqueOlderIds.isEmpty {
                mergePagedMessageIdsChronologically(with: uniqueOlderIds)
            }

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
            let inRangeIds = inRangeBatch.map(\.id)
            let existingIds = Set(pagedMessageIds)
            let missingIds = inRangeIds.filter { !existingIds.contains($0) }

            if !missingIds.isEmpty {
                mergePagedMessageIdsChronologically(with: missingIds)
            }

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

    @MainActor
    private func seedInitialMessagesFromChatIfNeeded() {
        guard messages.isEmpty, pagedMessageIds.isEmpty, let chat else { return }
        let sorted = chat.messages.sorted { lhs, rhs in
            if lhs.timestamp == rhs.timestamp {
                return lhs.internalId < rhs.internalId
            }
            return lhs.timestamp < rhs.timestamp
        }
        guard !sorted.isEmpty else { return }
        let seeded = Array(sorted.suffix(messagesPageSize))
        messages = seeded
        pagedMessageIds = seeded.map(\.id)
        hasMoreOlderMessages = sorted.count > seeded.count
        refreshMessageDateLookup()
        refreshVisibleReactions()
    }

    @MainActor
    private func scrollToMessage(_ messageId: String) {
        if pagedMessageIds.contains(messageId) {
            targetScrollMessageId = messageId
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                targetScrollMessageId = nil
            }
        } else {
            // TODO: Fetch older messages if necessary to reach the target message
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
                NewChatMessagesList(
                    messages: messages,
                    reactionsByMessageId: reactionsByMessageId,
                    isLoadingOlderMessages: isLoadingOlderMessages,
                    isAdmin: isAdmin,
                    mutedUsers: Set(mutedUsers),
                    targetScrollMessageId: targetScrollMessageId,
                    onReachedTop: {
                        loadOlderMessagesIfNeeded()
                    },
                    onTopVisibleMessageChanged: { messageId in
                        onTopVisibleMessageChanged(messageId)
                    },
                    onReplyMessage: { message in
                        replyingTo = message
                    },
                    onDMMessage: { codename, dmToken, pubKey, color in
                        createDMChatAndNavigate(codename: codename, dmToken: dmToken, pubKey: pubKey, color: color)
                    },
                    onDeleteMessage: isChannel ? { message in
                        deleteMessage(message)
                    } : nil,
                    onMuteUser: { pubKey in
                        setMuteState(for: pubKey, muted: true)
                    },
                    onUnmuteUser: { pubKey in
                        setMuteState(for: pubKey, muted: false)
                    },
                    onShowReactions: { messageId in
                        selectedReactionsMessageId = messageId
                    },
                    onScrollToReply: { messageId in
                        scrollToMessage(messageId)
                    },
                    onScrollActivityChanged: { isScrolling in
                        if isMessagesListScrolling == isScrolling {
                            return
                        }
                        isMessagesListScrolling = isScrolling
                        guard !isScrolling, hasDeferredChatRefresh else { return }
                        hasDeferredChatRefresh = false
                        refreshChatMessagesNow()
                    },
                    renderChannelPreview: { link, isIncoming, timestamp in
                        AnyView(ChannelInviteLinkPreview<T>(link: link, isIncoming: isIncoming, timestamp: timestamp).environmentObject(xxdk))
                    },
                    renderDMPreview: { link, isIncoming, timestamp in
                        AnyView(DMInviteLinkPreview<T>(link: link, isIncoming: isIncoming, timestamp: timestamp).environmentObject(xxdk))
                    }
                )
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

                        await MainActor.run {
                            let descriptor = FetchDescriptor<ChatModel>(predicate: #Predicate { $0.id == chatId })
                            let chatsToDelete = (try? modelContext.fetch(descriptor)) ?? []

                            for chatToDelete in chatsToDelete {
                                modelContext.delete(chatToDelete)
                            }

                            try? modelContext.save()
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
            seedInitialMessagesFromChatIfNeeded()
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
            // Mark all incoming messages as read
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
            refreshChatMessagesNow()
        }
        .id("chat-\(chatId)")
        .onChange(of: showChannelOptions) { _, newValue in
            if !newValue {
                isAdmin = chat?.isAdmin ?? false
            }
        }
        .background(ChatBackgroundView())
        .background(
            NewChatBackSwipeControl(isDisabled: true)
                .allowsHitTesting(false)
        )
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
