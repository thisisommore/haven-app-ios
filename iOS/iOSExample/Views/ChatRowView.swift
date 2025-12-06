import SwiftUI
import SwiftData

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

struct ChatRowView<T: XXDKP>: View {
    let chat: Chat
    @EnvironmentObject var xxdk: T
    
    private var isChannel: Bool {
        chat.name != "<self>" && chat.dmToken == nil
    }

    var body: some View {
        HStack {
            if chat.name == "<self>" {
                Image(systemName: "bookmark.circle.fill").font(.system(size: 40)).foregroundStyle(.orange).symbolRenderingMode(.hierarchical)
            }
            
            VStack(alignment: .leading) {
                HStack(spacing: 6) {
                    Text(chat.name == "<self>" ? "Notes" : chat.name).foregroundStyle(.primary)
                    if isChannel && chat.isAdmin {
                        AdminBadge()
                    }
                }

                if let lastMessage = chat.messages.sorted(by: { $0.timestamp < $1.timestamp }).last {
                    let senderName =
                        lastMessage.isIncoming ? (lastMessage.sender?.codename ?? "unknown") : "you"

                    VStack(alignment: .leading) {
                        Text(senderName)
                            .foregroundStyle(.secondary)
                            .font(.system(size: 12))
                         HTMLText(lastMessage.message,
                                  textColor: .messageText,
                                  customFontSize: 12,
                                  lineLimit: 1)
                    }
                } else {
                    Text("No messages yet")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
