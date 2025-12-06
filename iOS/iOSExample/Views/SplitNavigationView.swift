import SwiftUI
import SwiftData

struct SplitNavigationView: View {
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar / Primary
            HomeView<XXDK>(width: 100)
                .navigationTitle("Home")
        } detail: {
            // Detail
            Text("Select chat to continue")
        }.navigationBarBackButtonHidden(true)
    }
}

#Preview {
    // In-memory SwiftData container for previewing SplitNavigationView with mock data
    let container = try! ModelContainer(
        for: Chat.self, ChatMessage.self, MessageReaction.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    // Create a mock channel chat and some messages so the detail has content
    let previewChannelId = "previewChannelId"
    let chat = Chat(channelId: previewChannelId, name: "General")
    let chat2 = Chat(channelId: "max", name: "Max")
    let msgs = [
        ChatMessage(message: "Welcome to #general!", isIncoming: true, chat: chat, sender: Sender(id: "system-id", pubkey: Data(), codename: "System", color: greenColorInt), id: UUID().uuidString, internalId: InternalIdGenerator.shared.next()),
        ChatMessage(message: "Hi everyone 👋", isIncoming: false, chat: chat, id: UUID().uuidString, internalId: InternalIdGenerator.shared.next()),
        ChatMessage(message: "Great to see you here.", isIncoming: true, chat: chat, sender: Sender(id: "mayur-id", pubkey: Data(), codename: "Mayur", color: greenColorInt), id: UUID().uuidString, internalId: InternalIdGenerator.shared.next())
    ]
    msgs.forEach { container.mainContext.insert($0) }
    container.mainContext.insert(chat2)

    return SplitNavigationView()
        .modelContainer(container)
        .environmentObject(XXDKMock())
}
