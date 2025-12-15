import SwiftUI
import SwiftData

struct SplitNavigationView<T: XXDKP>: View {
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @EnvironmentObject var xxdk: T
    @EnvironmentObject private var selectedChat: SelectedChat

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar - Chat list
            HomeView<T>(width: 320)
                .navigationTitle("Chat")
                .environment(\.isSplitView, true)
        } detail: {
            // Detail - Selected chat or placeholder
            if let chatId = selectedChat.chatId {
                ChatView<T>(width: UIScreen.w(100), chatId: chatId, chatTitle: selectedChat.chatTitle)
                    .id(chatId)
            } else {
                ContentUnavailableView(
                    "No Chat Selected",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Select a chat from the sidebar to start messaging")
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

#Preview {
    @Previewable @StateObject var selectedChat = SelectedChat()
    @Previewable @State var container: ModelContainer = {
        let c = try! ModelContainer(
            for: Chat.self, ChatMessage.self, MessageReaction.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let chat = Chat(channelId: "previewChannelId", name: "General")
        let chat2 = Chat(channelId: "max", name: "Max")
        c.mainContext.insert(chat)
        c.mainContext.insert(chat2)
        return c
    }()
    
    SplitNavigationView<XXDKMock>()
        .modelContainer(container)
        .environmentObject(XXDKMock())
        .environmentObject(selectedChat)
}
