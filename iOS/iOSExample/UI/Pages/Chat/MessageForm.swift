//
//  MessageForm.swift
//  iOSExample
//
//  Created by Om More on 28/09/25.
//
import SQLiteData
import SwiftUI

struct MessageForm<T: XXDKP>: View {
  @State private var abc: String = ""
  @State private var isSendingMessage: Bool = false
  var chat: ChatModel?
  var replyTo: ChatMessageModel?
  var onCancelReply: (() -> Void)?
  @EnvironmentObject private var xxdk: T
  @State private var showSendButton: Bool = false
  @Namespace private var namespace

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
        .background(Color(.systemGray6))
        .transition(.move(edge: .bottom).combined(with: .opacity))
      }

      HStack(spacing: 8) {
        TextField(
          "",
          text: self.$abc,
          axis: .vertical
        ).lineLimit(1 ... 10)
          .onSubmit {
            self.sendMessage()
          }
          .padding(.vertical, 8)
          .padding(.horizontal, 12)
          .background(.formBG.opacity(0.1))
          .background(.ultraThinMaterial)
          .clipShape(RoundedRectangle(cornerRadius: 40))
          .padding(.trailing, 8)

        if !self.abc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          && !self.isSendingMessage {
          Button(action: self.sendMessage) {
            Image(systemName: "chevron.right")
              .padding(.vertical, 4)
          }.tint(.haven)
            .buttonStyle(.borderedProminent)
            .padding(.trailing, 6)
            .buttonBorderShape(.circle)
            .transition(.scale.combined(with: .opacity))
        }
        if self.isSendingMessage {
          Spacer()
          ProgressView()
        }
      }
      .padding(.horizontal, 8)
      .padding(.top, 10)
      .animation(
        .spring(response: 0.3, dampingFraction: 0.7),
        value: self.abc.isEmpty
      )
    }
    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: self.replyTo?.id)
    .background(.bottomNav).background(.ultraThinMaterial)
  }

  private func replyPreviewText(for message: ChatMessageModel) -> String {
    let plainText = message.newRenderPlainText ?? message.message
    let trimmed = stripParagraphTags(plainText).trimmingCharacters(in: .whitespacesAndNewlines)
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

    if let chat {
      if let token = chat.dmToken {
        // DM chat: send direct message or reply
        if let pubKey = Data(base64Encoded: chat.id) {
          if let replyTo {
            Task {
              self.xxdk.sendReply(
                msg: trimmed,
                toPubKey: pubKey,
                partnerToken: token,
                replyToMessageIdB64: replyTo.externalId
              )
            }
          } else {
            Task {
              self.xxdk.sendDM(
                msg: trimmed,
                toPubKey: pubKey,
                partnerToken: token
              )
            }
          }
        }
      } else {
        // Channel chat: send via Channels Manager using channelId (stored in id)
        if let replyTo {
          Task {
            self.xxdk.sendReply(
              msg: trimmed,
              channelId: chat.id,
              replyToMessageIdB64: replyTo.externalId
            )
          }
        } else {
          Task {
            self.xxdk.sendDM(
              msg: trimmed,
              channelId: chat.id
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
}

#Preview {
  MessageFormPreviewWrapper()
    .mock()
}

#Preview("Reply Mode") {
  MessageFormPreviewWrapper(replyMode: true)
    .mock()
}

private struct MessageFormPreviewWrapper: View {
  @FetchOne(ChatModel.where { $0.id.eq(previewChatId) }) private var chat: ChatModel?
  @FetchAll(ChatMessageModel.order { $0.timestamp.desc() }.limit(1)) private var messages:
    [ChatMessageModel]
  var replyMode: Bool = false

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

private struct ReplyToSenderView: View {
  let messageId: String
  let senderId: String?
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
