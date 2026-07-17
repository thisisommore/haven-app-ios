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

  /// Grows one line at a time up to ~7 lines, then scrolls.
  private var editorHeight: CGFloat {
    let lineBreaks = self.text.filter { $0 == "\n" }.count
    let wrappedExtra = max(0, self.text.count / 90)
    let lines = max(1, lineBreaks + wrappedExtra + 1)
    return min(22 + CGFloat(lines - 1) * 17, 120)
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
        .padding(.top, 10)
      }

      HStack(alignment: .bottom, spacing: 10) {
        TextEditor(text: self.$text)
          .font(.system(size: 14))
          .scrollContentBackground(.hidden)
          .frame(height: self.editorHeight)
          .padding(.horizontal, 10)
          .padding(.top, 8)
          .padding(.bottom, 2)
          .background(Color(nsColor: .textBackgroundColor))
          .clipShape(RoundedRectangle(cornerRadius: 12))
          .overlay {
            RoundedRectangle(cornerRadius: 12)
              .stroke(
                self.isFocused ? Color.haven : Color(nsColor: .separatorColor),
                lineWidth: self.isFocused ? 1.5 : 1
              )
          }
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
            .font(.system(size: 26))
            .foregroundStyle(self.canSend ? Color.haven : Color.secondary.opacity(0.4))
        }
        .buttonStyle(.plain)
        .disabled(!self.canSend)
        .help("Send (Return)")
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
    }
    .background(.bar)
    .overlay(alignment: .top) {
      Divider()
    }
    .onAppear {
      self.isFocused = true
    }
  }
}
