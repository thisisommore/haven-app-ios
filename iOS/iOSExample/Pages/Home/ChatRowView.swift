import SwiftUI
import UIKit

struct AdminBadge: View {
    var body: some View {
        Text("Admin")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.haven)
            .clipShape(Capsule())
    }
}

struct SecretBadge: View {
    var body: some View {
        Text("Secret")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Color.haven)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.clear)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.haven, lineWidth: 1))
    }
}

struct UnreadBadge: View {
    let count: Int

    var body: some View {
        Text(count > 99 ? "99+" : "\(count)")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.haven)
            .clipShape(Capsule())
    }
}

struct ChatRowView<T: XXDKP>: View {
    let chat: ChatModel
    @EnvironmentObject var xxdk: T
    @EnvironmentObject var chatStore: ChatStore

    private var isChannel: Bool {
        chat.name != "<self>" && chat.dmToken == nil
    }

    private var isDM: Bool {
        chat.dmToken != nil
    }

    /// Truncate nickname to 10 chars for display
    private func truncateNickname(_ nickname: String) -> String {
        nickname.count > 10 ? String(nickname.prefix(10)) + "…" : nickname
    }

    @State private var lastMessage: ChatMessageModel?
    @State private var lastMessageSender: MessageSenderModel?
    @State private var dmPartnerNickname: String?

    /// Display name for chat title
    private var chatDisplayName: String {
        if chat.name == "<self>" {
            return "Notes"
        }
        if isDM, let nickname = dmPartnerNickname, !nickname.isEmpty {
            return "\(truncateNickname(nickname)) aka \(chat.name)"
        }
        return chat.name
    }

    var body: some View {
        HStack {
            if chat.name == "<self>" {
                Image(systemName: "bookmark.circle.fill").font(.system(size: 40)).foregroundStyle(.orange).symbolRenderingMode(.hierarchical)
            }

            VStack(alignment: .leading) {
                HStack(spacing: 6) {
                    Text(chatDisplayName).foregroundStyle(Color(uiColor: .label))
                    if isChannel && chat.isSecret {
                        SecretBadge()
                    }
                    if isChannel && chat.isAdmin {
                        AdminBadge()
                    }
                }

                if let lastMessage {
                    let senderName: String = {
                        if !lastMessage.isIncoming {
                            return "you"
                        }
                        guard let sender = lastMessageSender else { return "unknown" }
                        if isDM {
                            return sender.codename
                        }
                        if let nickname = sender.nickname, !nickname.isEmpty {
                            return "\(truncateNickname(nickname)) aka \(sender.codename)"
                        }
                        return sender.codename
                    }()

                    VStack(alignment: .leading) {
                        Text(senderName)
                            .foregroundStyle(Color(uiColor: .secondaryLabel))
                            .font(.system(size: 12))
                        
                    }
                } else {
                    Text("No messages yet")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                }
            }

            Spacer()

            if chat.unreadCount > 0 {
                UnreadBadge(count: chat.unreadCount)
            }
        }
        .onAppear {
            loadLastMessage()
        }
        .onReceive(NotificationCenter.default.publisher(for: .chatMessagesUpdated)) { notification in
            if let updatedChatId = notification.userInfo?["chatId"] as? String,
               updatedChatId == chat.id
            {
                loadLastMessage()
            }
        }
    }

    private func loadLastMessage() {
        if let msgs = try? chatStore.fetchLatestMessages(chatId: chat.id, limit: 1),
           let msg = msgs.last
        {
            lastMessage = msg
            if let senderId = msg.senderId {
                lastMessageSender = try? chatStore.fetchSender(id: senderId)
            }
        }
        if isDM {
            if let msgs = try? chatStore.fetchLatestMessages(chatId: chat.id, limit: 50) {
                if let incomingWithSender = msgs.first(where: { $0.isIncoming && $0.senderId != nil }),
                   let sender = try? chatStore.fetchSender(id: incomingWithSender.senderId!)
                {
                    dmPartnerNickname = sender.nickname
                }
            }
        }
    }
}
