import HavenCore
import SQLiteData
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
    Image(systemName: "lock.fill")
      .font(.system(size: 12, weight: .semibold))
      .foregroundStyle(Color(uiColor: .secondaryLabel))
  }
}

struct UnreadBadge: View {
  let count: Int

  var body: some View {
    Text(self.count > 99 ? "99+" : "\(self.count)")
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

  @Dependency(\.defaultDatabase) var database

  @FetchAll private var latestMessage: [ChatMessageModel]

  init(chat: ChatModel) {
    self.chat = chat
    _latestMessage = FetchAll(
      ChatMessageModel.where { $0.chatId.eq(chat.id) }
        .order { $0.timestamp.desc() }
        .limit(1)
    )
  }

  private var isChannel: Bool {
    self.chat.name != "ChatModel.selfChatInternalName" && self.chat.dmToken == nil
  }

  private var isDM: Bool {
    self.chat.dmToken != nil
  }

  private var dmPartnerNickname: String? {
    guard self.isDM else { return nil }
    guard
      let senderId = try? database.read({ db in
        try ChatMessageModel.where {
          $0.chatId.eq(chat.id) && $0.isIncoming && $0.senderId != nil
        }.limit(1).fetchOne(db)?.senderId
      })
    else { return nil }
    return try? self.database.read { db in
      try MessageSenderModel.where { $0.id.eq(senderId) }.fetchOne(db)?.nickname
    }
  }

  /// Truncate nickname to 10 chars for display
  private func truncateNickname(_ nickname: String) -> String {
    nickname.count > 10 ? String(nickname.prefix(10)) + "…" : nickname
  }

  /// Display name for chat title
  private var chatDisplayName: String {
    if self.chat.name == "ChatModel.selfChatInternalName" {
      return "Notes"
    }
    if self.isDM, let nickname = dmPartnerNickname, !nickname.isEmpty {
      return "\(self.truncateNickname(nickname)) aka \(self.chat.name)"
    }
    if self.isChannel {
      return "#\(self.chat.name)"
    }
    return self.chat.name
  }

  /// Today: time only. Yesterday: localized "Yesterday". Same calendar week: weekday (abbrev).
  /// Otherwise: numeric date (locale order).
  private func formattedListTimestamp(_ date: Date) -> String {
    let cal = Calendar.current
    if cal.isDateInToday(date) {
      return date.formatted(date: .omitted, time: .shortened)
    }
    if cal.isDateInYesterday(date) {
      let f = DateFormatter()
      f.dateStyle = .short
      f.timeStyle = .none
      f.doesRelativeDateFormatting = true
      return f.string(from: date)
    }
    if cal.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
      return date.formatted(.dateTime.weekday(.abbreviated))
    }
    return date.formatted(date: .numeric, time: .omitted)
  }

  var body: some View {
    HStack(alignment: .top) {
      if self.chat.name == "ChatModel.selfChatInternalName" {
        Image(systemName: "bookmark.circle.fill").font(.system(size: 40)).foregroundStyle(
          .haven
        ).symbolRenderingMode(.hierarchical)
      }

      VStack(alignment: .leading) {
        HStack(spacing: 6) {
          Text(self.chatDisplayName).foregroundStyle(Color(uiColor: .label))
          if self.isChannel && self.chat.isSecret {
            SecretBadge()
          }
          if self.isChannel && self.chat.isAdmin {
            AdminBadge()
          }
        }

        if let lastMessage = self.latestMessage.first {
          VStack(alignment: .leading, spacing: 2) {
            LastMessageSenderNameView(lastMessage: lastMessage, isDM: self.isDM)
            Text(AttributedString(lastMessage.attributedText(color: .secondaryLabel, size: 12)))
              .foregroundStyle(Color(uiColor: .secondaryLabel))
              .font(.system(size: 12))
              .lineLimit(1)
              .truncationMode(.tail)
          }
        } else if self.chat.name != "ChatModel.selfChatInternalName" {
          Text("No messages yet")
            .font(.system(size: 12))
            .foregroundStyle(Color(uiColor: .secondaryLabel))
        }
      }

      Spacer(minLength: 8)

      VStack(alignment: .trailing, spacing: 4) {
        if let lastMessage = self.latestMessage.first {
          Text(self.formattedListTimestamp(lastMessage.timestamp))
            .font(.system(size: 12))
            .foregroundStyle(Color(uiColor: .secondaryLabel))
        }
        if self.chat.unreadCount > 0 {
          UnreadBadge(count: self.chat.unreadCount)
        }
      }
    }
  }
}

private struct LastMessageSenderNameView: View {
  let lastMessage: ChatMessageModel
  let isDM: Bool
  @FetchOne private var sender: MessageSenderModel?

  private static let fallbackSenderId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

  init(lastMessage: ChatMessageModel, isDM: Bool) {
    self.lastMessage = lastMessage
    self.isDM = isDM

    if lastMessage.isIncoming, let senderId = lastMessage.senderId {
      _sender = FetchOne(MessageSenderModel.where { $0.id.eq(senderId) })
    } else {
      _sender = FetchOne(MessageSenderModel.where { $0.id.eq(Self.fallbackSenderId) })
    }
  }

  private func truncateNickname(_ nickname: String) -> String {
    nickname.count > 10 ? String(nickname.prefix(10)) + "…" : nickname
  }

  private var senderName: String {
    if !self.lastMessage.isIncoming {
      return "you"
    }
    guard let sender else {
      return "unknown"
    }
    if self.isDM {
      return sender.codename
    }
    if let nickname = sender.nickname, !nickname.isEmpty {
      return "\(self.truncateNickname(nickname)) aka \(sender.codename)"
    }
    return sender.codename
  }

  var body: some View {
    Text(self.senderName)
      .foregroundStyle(Color(uiColor: .secondaryLabel))
      .font(.system(size: 12))
  }
}
