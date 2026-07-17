//
//  MacChatMessagesView.swift
//  haven
//
//  Scrollable message history for the selected chat: date separators,
//  same-sender grouping, and scroll-to-bottom on new messages.
//

import SQLiteData
import SwiftUI

private enum MacChatListItem: Identifiable {
  case date(Date)
  case message(ChatMessageModel, showsSender: Bool)

  var id: String {
    switch self {
    case let .date(day):
      return "date-\(day.timeIntervalSince1970)"
    case let .message(message, _):
      return "msg-\(message.id)"
    }
  }
}

struct MacChatMessagesView: View {
  let chatId: UUID
  let controller: ChatPageController

  @EnvironmentObject private var xxdk: XXDK

  @FetchAll private var messages: [ChatMessageModel]
  @FetchAll private var senders: [MessageSenderModel]
  @FetchAll private var reactions: [MessageReactionModel]

  @State private var reactorsFor: ChatMessageModel?
  @State private var highlightedMessageId: Int64?

  init(chatId: UUID, controller: ChatPageController) {
    self.chatId = chatId
    self.controller = controller
    _messages = FetchAll(
      ChatMessageModel
        .where { $0.chatId.eq(chatId) }
        .order { $0.timestamp.asc() }
    )
    _senders = FetchAll(MessageSenderModel.all)
    _reactions = FetchAll(MessageReactionModel.all)
  }

  private var isChannel: Bool {
    self.controller.chat.map { $0.id != UUID.selfId && $0.dmToken == nil } ?? false
  }

  private var sendersById: [UUID: MessageSenderModel] {
    Dictionary(uniqueKeysWithValues: self.senders.map { ($0.id, $0) })
  }

  private var reactionsByTarget: [String: [MessageReactionModel]] {
    Dictionary(grouping: self.reactions.filter { $0.status != .deleting }) { $0.targetMessageId }
  }

  private var items: [MacChatListItem] {
    var result: [MacChatListItem] = []
    var lastDay: Date?
    var lastSenderKey: String?

    for message in self.messages {
      let day = Calendar.current.startOfDay(for: message.timestamp)
      if day != lastDay {
        result.append(.date(day))
        lastDay = day
        lastSenderKey = nil
      }

      let senderKey = message.isIncoming
        ? "in-\(message.senderId?.uuidString ?? "")"
        : "me"
      let showsSender = senderKey != lastSenderKey
      result.append(.message(message, showsSender: showsSender))
      lastSenderKey = senderKey
    }
    return result
  }

  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    formatter.doesRelativeDateFormatting = true
    return formatter
  }()

  private func scrollToMessage(externalId: String, proxy: ScrollViewProxy) {
    guard let target = self.messages.first(where: { $0.externalId == externalId }) else { return }
    withAnimation {
      proxy.scrollTo("msg-\(target.id)", anchor: .center)
    }
    self.highlightedMessageId = target.id
    Task {
      try? await Task.sleep(for: .seconds(1.2))
      await MainActor.run {
        if self.highlightedMessageId == target.id {
          self.highlightedMessageId = nil
        }
      }
    }
  }

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: 3) {
          if self.messages.isEmpty {
            EmptyChatView()
              .padding(.top, 80)
          }

          ForEach(self.items) { item in
            switch item {
            case let .date(day):
              Text(Self.dateFormatter.string(from: day))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(.regularMaterial, in: Capsule())
                .padding(.top, 14)
                .padding(.bottom, 6)
                .frame(maxWidth: .infinity)
                .id(item.id)

            case let .message(message, showsSender):
              MacMessageBubble(
                message: message,
                sender: message.senderId.flatMap { self.sendersById[$0] },
                reactions: self.reactionsByTarget[message.externalId] ?? [],
                showsSender: showsSender,
                isChannel: self.isChannel,
                isHighlighted: self.highlightedMessageId == message.id,
                controller: self.controller,
                onReplyPreviewTap: { externalId in
                  self.scrollToMessage(externalId: externalId, proxy: proxy)
                },
                onShowReactors: { self.reactorsFor = message }
              )
              .id(item.id)
            }
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
      }
      .defaultScrollAnchor(.bottom)
      .background(Color.appBackground)
      .sheet(item: self.$reactorsFor) { message in
        ReactorsSheet(
          targetMessageId: message.externalId,
          chatId: self.chatId,
          selectedEmoji: nil,
          onDeleteReaction: nil
        )
        .frame(minWidth: 380, minHeight: 420)
      }
    }
  }
}
