//
//  MacComposer.swift
//  haven
//
//  Message composer with desktop keyboard behavior: Return sends,
//  Shift-Return inserts a newline.
//

import SwiftUI

struct MacComposer<T: XXDKP>: View {
  let chat: ChatModel?
  let replyingTo: ChatMessageModel?
  let onCancelReply: () -> Void

  @EnvironmentObject private var xxdk: T

  @State private var text = ""
  @FocusState private var isFocused: Bool

  private var canSend: Bool {
    !self.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private func send() {
    let trimmed = self.text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, let chat else { return }

    let xxdk = self.xxdk
    if let token = chat.dmToken, let pubKey = chat.pubKey {
      if let replyTo = replyingTo {
        Task.detached(priority: .userInitiated) {
          xxdk.dm.reply(
            msg: trimmed,
            toPubKey: pubKey,
            partnerToken: token,
            replyToMessageIdB64: replyTo.externalId
          )
        }
      } else {
        Task.detached(priority: .userInitiated) {
          xxdk.dm.send(msg: trimmed, toPubKey: pubKey, partnerToken: token)
        }
      }
    } else if let channelId = chat.channelId {
      if let replyTo = replyingTo {
        Task.detached(priority: .userInitiated) {
          xxdk.channel.msg.reply(
            msg: trimmed,
            channelId: channelId,
            replyToMessageIdB64: replyTo.externalId
          )
        }
      } else {
        Task.detached(priority: .userInitiated) {
          xxdk.channel.msg.send(msg: trimmed, channelId: channelId)
        }
      }
    }

    self.text = ""
    self.onCancelReply()
  }

  var body: some View {
    VStack(spacing: 0) {
      Divider()

      if let replyingTo {
        HStack(spacing: 8) {
          RoundedRectangle(cornerRadius: 1.5)
            .fill(Color.haven)
            .frame(width: 3)
          Text(replyingTo.message.stripParagraphTags())
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
          Spacer()
          Button {
            self.onCancelReply()
          } label: {
            Image(systemName: "xmark.circle.fill")
              .foregroundStyle(.secondary)
          }
          .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
      }

      HStack(alignment: .bottom, spacing: 10) {
        TextEditor(text: self.$text)
          .font(.system(size: 14))
          .scrollContentBackground(.hidden)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxHeight: 140)
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(Color.formBG, in: RoundedRectangle(cornerRadius: 14))
          .focused(self.$isFocused)
          .onKeyPress(.return, phases: .down) { press in
            // Return sends, Shift-Return inserts a newline.
            if press.modifiers.contains(.shift) {
              return .ignored
            }
            self.send()
            return .handled
          }

        Button(action: self.send) {
          Image(systemName: "arrow.up.circle.fill")
            .font(.system(size: 24))
            .foregroundStyle(self.canSend ? Color.haven : Color.secondary.opacity(0.5))
        }
        .buttonStyle(.plain)
        .disabled(!self.canSend)
        .help("Send (Return)")
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
    }
    .onAppear {
      self.isFocused = true
    }
  }
}
