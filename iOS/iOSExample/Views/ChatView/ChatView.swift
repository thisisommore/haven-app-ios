//
//  ChatView.swift
//  iOSExample
//
//  Created by Om More on 22/09/25.
//

import SwiftData
import SwiftUI

// MARK: - Floating Date Header
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

// MARK: - Date Separator Badge
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

// MARK: - Visible Message Tracker
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

// MARK: - Empty Chat State
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
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

 
    @EnvironmentObject private var swiftDataActor: SwiftDataActor
    @Query private var chatResults: [Chat]

    private var chat: Chat? { chatResults.first }
    private var messages: [ChatMessage] {
        guard let chat else { return [] }
        // Sort by timestamp ascending
        return chat.messages.sorted { $0.timestamp < $1.timestamp }
    }
    private var isChannel: Bool {
        guard let chat else { return false }
        return chat.name != "<self>" && chat.dmToken == nil
    }

    @Environment(\.dismiss) private var dismiss
    @State var abc: String = ""
    @State private var replyingTo: ChatMessage? = nil
    @State private var showChannelOptions: Bool = false
    @State private var navigateToDMChat: Chat? = nil
    @State private var visibleDate: Date? = nil
    @State private var showDateHeader: Bool = false
    @State private var hideTask: Task<Void, Never>? = nil
    @State private var scrollingToOlder: Bool = true
    @State private var isAdmin: Bool = false
    @State private var toastMessage: String? = nil
    @State private var isMuted: Bool = false
    @State private var mutedUsers: [Data] = []
    @EnvironmentObject var xxdk: T
    func createDMChatAndNavigate(codename: String, dmToken: Int32, pubKey: Data, color: Int)
    {
        // Create a new DM chat
        let dmChat = Chat(pubKey: pubKey, name: codename, dmToken: dmToken, color: color)

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
            filter: #Predicate<Chat> { chat in
                chat.id == chatId
            }
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            if messages.isEmpty {
                EmptyChatView()
            } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, result in
                        // Show date separator if this is first message or date changed
                        if index == 0 || !Calendar.current.isDate(result.timestamp, inSameDayAs: messages[index - 1].timestamp) {
                            DateSeparatorBadge(date: result.timestamp, isFirst: index == 0)
                        }
                        
                        ChatMessageRow(
                            result: result,
                            isAdmin: isAdmin,
                            onReply: { message in
                                replyingTo = message
                            },
                            onDM: { codename, dmToken, pubKey, color  in
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
                            mutedUsers: mutedUsers
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
        .navigationBarHidden(true)
        .safeAreaInset(edge: .top) {
            HStack {
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.headline)
                    .foregroundStyle(.haven)
                }
                
                Spacer()
                
                Button {
                    showChannelOptions = true
                } label: {
                    HStack(spacing: 4) {
                        Text(chatTitle == "<self>" ? "Notes" : chatTitle)
                            .font(.headline.weight(.semibold))
                        if isChannel && isAdmin {
                            AdminBadge()
                        }
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Invisible spacer to balance the back button
                HStack(spacing: 2) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.subheadline)
                .opacity(0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial)
        }
        .sheet(isPresented: $showChannelOptions) {
            ChannelOptionsView<T>(chat: chat) {
                Task {
                    do {
                        try xxdk.leaveChannel(channelId: chatId)
                        await MainActor.run {
                            if let chat = chat {
                                swiftDataActor.delete(chat)
                                do {
                                    try swiftDataActor.save()
                                } catch {
                                    print(
                                        "Failed to save context after deleting chat: \(error)"
                                    )
                                }
                            }
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
        }
        .onReceive(NotificationCenter.default.publisher(for: .userMuteStatusChanged)) { notification in
            if let channelID = notification.userInfo?["channelID"] as? String,
               channelID == chatId {
                isMuted = xxdk.isMuted(channelId: chatId)
                do {
                    mutedUsers = try xxdk.getMutedUsers(channelId: chatId)
                } catch {
                    print("Failed to refresh muted users: \(error)")
                }
            }
        }
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
        .simultaneousGesture(
            DragGesture()
                .onEnded { gesture in
                    if gesture.startLocation.x < 100 && gesture.translation.width > 80 {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
        )
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
    let container = try! ModelContainer(
        for: Chat.self,
        ChatMessage.self,
        MessageReaction.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    );

    {
        mockMsgs.forEach { container.mainContext.insert($0) }

        reactions.forEach { container.mainContext.insert($0) }
    }()
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
    }
}
