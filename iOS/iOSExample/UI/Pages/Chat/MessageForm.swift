//
//  MessageForm.swift
//  iOSExample
//
//  Created by Om More on 28/09/25.
//
import SQLiteData
import SwiftUI

struct MessageForm<T: XXDKP>: View {
  var chat: ChatModel?
  var replyTo: ChatMessageModel?
  var onCancelReply: (() -> Void)?

  @EnvironmentObject private var xxdk: T

  @State private var abc: String = ""
  @State private var isSendingMessage: Bool = false
  @State private var showSendButton: Bool = false

  private func replyPreviewText(for message: ChatMessageModel) -> String {
    let plainText = message.message
    let trimmed = plainText.stripParagraphTags().trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "Message" : trimmed
  }

  private func sendMessage() {
    // Guard against double-submission
    guard !self.isSendingMessage else { return }
    let trimmed = self.abc.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    withAnimation {
      self.isSendingMessage = true
    }

    let xxdk = self.xxdk
    if let chat {
      if let token = chat.dmToken, let pubKey = chat.pubKey {
        // DM chat: send direct message or reply
        if let replyTo {
          let replyToId = replyTo.externalId
          Task.detached {
            xxdk.dm!.reply(
              msg: trimmed,
              toPubKey: pubKey,
              partnerToken: token,
              replyToMessageIdB64: replyToId
            )
          }
        } else {
          Task.detached {
            xxdk.dm!.send(
              msg: trimmed,
              toPubKey: pubKey,
              partnerToken: token
            )
          }
        }
      } else if let channelId = chat.channelId {
        // Channel chat: send via Channels Manager
        if let replyTo {
          let replyToId = replyTo.externalId
          Task.detached {
            xxdk.channel.msg.reply(
              msg: trimmed,
              channelId: channelId,
              replyToMessageIdB64: replyToId
            )
          }
        } else {
          Task.detached {
            xxdk.channel.msg.send(
              msg: trimmed,
              channelId: channelId
            )
          }
        }
      }
    }
    withAnimation {
      self.isSendingMessage = false
    }
    self.abc = ""
    self.onCancelReply?()
  }

  var body: some View {
    VStack(spacing: 0) {
      // Reply preview
      if let replyTo {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            ReplyToSenderView(messageId: replyTo.externalId, senderId: replyTo.senderId)
            Text(self.replyPreviewText(for: replyTo))
              .font(.caption2)
              .foregroundStyle(.primary)
              .lineLimit(1)
          }
          Spacer()
          Button {
            self.onCancelReply?()
          } label: {
            Image(systemName: "xmark.circle.fill")
              .foregroundStyle(.haven)
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
      }

      HStack(spacing: 8) {
        TextField(
          "",
          text: self.$abc,
          axis: .vertical
        ).lineLimit(1 ... 10)
          .tint(.haven)
          .onSubmit {
            self.sendMessage()
          }
          .padding(.vertical, 8)
          .padding(.horizontal, 12)
          .background(.formBG.opacity(0.1))
          .background(.ultraThinMaterial)
          .clipShape(RoundedRectangle(cornerRadius: 40))

        if !self.abc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          && !self.isSendingMessage {
          Button(action: self.sendMessage) {
            Image(systemName: "chevron.right")
              .padding(.vertical, 4)
          }.tint(.haven)
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.circle)
            .transition(.scale.combined(with: .opacity))
        }
        if self.isSendingMessage {
          Spacer()
          ProgressView()
        }
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .animation(
        .spring(response: 0.3, dampingFraction: 0.7),
        value: self.abc.isEmpty
      )
    }
    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: self.replyTo?.id)
  }
}

private struct ReplyToSenderView: View {
  let messageId: String
  let senderId: UUID?

  @Dependency(\.defaultDatabase) var database

  @State private var senderCodename: String?

  var body: some View {
    Text("Replying to \(self.senderCodename ?? "You")")
      .font(.caption)
      .foregroundStyle(.secondary)
      .task {
        guard let senderId else { return }
        self.senderCodename = try? self.database.read { db in
          try MessageSenderModel.where { $0.id.eq(senderId) }.fetchOne(db)?.codename
        }
      }
  }
}

#Preview {
  Mock {
    MessageFormPreviewWrapper()
  }
}

#Preview("Reply Mode") {
  Mock {
    MessageFormPreviewWrapper(replyMode: true)
  }
}

private struct MessageFormPreviewWrapper: View {
  var replyMode: Bool = false

  @FetchOne(ChatModel.where { $0.id.eq(previewChatId) }) private var chat: ChatModel?
  @FetchAll(ChatMessageModel.order { $0.timestamp.desc() }.limit(1)) private var messages:
    [ChatMessageModel]

  var body: some View {
    ZStack {
      Color.appBackground.edgesIgnoringSafeArea(.all)
      if let chat {
        VStack {
          Spacer()
          MessageForm<XXDKMock>(
            chat: chat,
            replyTo: self.replyMode ? self.messages.first : nil,
            onCancelReply: {}
          )
        }
      }
    }
  }
}
