//
//  MacMessageBubble.swift
//  haven
//
//  A single message bubble: sender label (channels), reply preview, message
//  text, reactions, and timestamp — with a right-click context menu for
//  react / reply / copy / mute / delete.
//

import AppKit
import SQLiteData
import SwiftUI

struct MacMessageBubble: View {
  let message: ChatMessageModel
  let sender: MessageSenderModel?
  let reactionEmojis: [String]
  let showsSender: Bool
  let isChannel: Bool
  let isHighlighted: Bool
  let controller: ChatPageController
  let onReplyPreviewTap: (String) -> Void
  let onShowReactors: () -> Void

  @EnvironmentObject private var xxdk: XXDK
  @Environment(\.colorScheme) private var colorScheme

  @State private var showLinkWarning = false
  @State private var pendingURL: URL?

  private var isOutgoing: Bool {
    !self.message.isIncoming
  }

  private var senderColor: Color {
    guard let sender else { return .haven }
    return Color(hexNumber: sender.color).adaptive(for: self.colorScheme)
  }

  private var canModerate: Bool {
    self.isChannel && (self.controller.chat?.isAdmin ?? false)
  }

  private var canDelete: Bool {
    self.isChannel && (self.isOutgoing || (self.controller.chat?.isAdmin ?? false))
  }

  private static let maxBubbleWidth: CGFloat = 520
  private static let horizontalPadding: CGFloat = 24

  /// Deterministic bubble width: measured text width plus padding, clamped —
  /// mirroring the iOS MessageBubble `size(for:width:)` approach.
  private var bubbleWidth: CGFloat {
    let attributed = self.message.attributedText(size: 14, linkClickable: true)
    let bounds = attributed.boundingRect(
      with: CGSize(
        width: Self.maxBubbleWidth - Self.horizontalPadding,
        height: .greatestFiniteMagnitude
      ),
      options: [.usesLineFragmentOrigin, .usesFontLeading]
    )
    let textWidth = ceil(bounds.width)
    let timeRowWidth: CGFloat = 72
    let content = max(textWidth, timeRowWidth)
    return min(max(content, 44) + Self.horizontalPadding, Self.maxBubbleWidth)
  }

  private func copyMessage() {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(
      self.message.message.stripParagraphTags(),
      forType: .string
    )
  }

  private func openLink(_ url: URL) {
    self.pendingURL = url
    self.showLinkWarning = true
  }

  var body: some View {
    HStack(alignment: .bottom, spacing: 6) {
      if self.isOutgoing { Spacer(minLength: 60) }

      VStack(alignment: self.isOutgoing ? .trailing : .leading, spacing: 1) {
        if self.showsSender, self.isChannel, self.message.isIncoming, let sender {
          Text(sender.codename)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(self.senderColor)
            .padding(.leading, 12)
            .padding(.top, 6)
        }

        VStack(alignment: .leading, spacing: 6) {
          if let replyTo = message.replyTo {
            MacReplyPreviewView(externalId: replyTo, onTap: self.onReplyPreviewTap)
          }

          Text(AttributedString(self.message.attributedText(size: 14, linkClickable: true)))
            .textSelection(.enabled)
            .environment(\.openURL, OpenURLAction { url in
              self.openLink(url)
              return .handled
            })

          HStack(spacing: 4) {
            Spacer(minLength: 16)
            if self.message.status == .unsent || self.message.status == .deleting {
              Image(systemName: "clock")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            }
            Text(self.message.timestamp, format: .dateTime.hour().minute())
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.messageBubble, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
          if self.isHighlighted {
            RoundedRectangle(cornerRadius: 16)
              .stroke(Color.haven, lineWidth: 2)
              .transition(.opacity)
          }
        }
        .frame(width: self.bubbleWidth, alignment: self.isOutgoing ? .trailing : .leading)

        if !self.reactionEmojis.isEmpty {
          Button(action: self.onShowReactors) {
            HStack(spacing: 3) {
              ForEach(self.reactionEmojis, id: \.self) { emoji in
                Text(emoji).font(.system(size: 12))
              }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.messageBubbleReactionBG, in: Capsule())
          }
          .buttonStyle(.plain)
          .padding(.leading, self.isOutgoing ? 0 : 8)
        }
      }

      if !self.isOutgoing { Spacer(minLength: 60) }
    }
    .padding(.top, self.showsSender ? 8 : 0)
    // Definite vertical size so NSHostingView sizeThatFits / intrinsic height
    // match the rendered bubble (prevents collection-view cell overlap on Mac).
    .fixedSize(horizontal: false, vertical: true)
    .contextMenu {
      Button("React…") {
        self.controller.activeSheet = .emojiKeyboard(self.message)
      }
      Button("Reply") {
        self.controller.replyingTo = self.message
      }
      Button("Copy") {
        self.copyMessage()
      }
      if self.canModerate, self.message.isIncoming, let sender {
        Divider()
        Button("Mute \(sender.codename)", role: .destructive) {
          if let channelId = controller.chat?.channelId {
            self.controller.muteUser(sender.pubkey, channelId: channelId, xxdk: self.xxdk)
          }
        }
      }
      if self.canDelete {
        Divider()
        Button("Delete Message", role: .destructive) {
          if let channelId = controller.chat?.channelId {
            self.controller.deleteMessage(self.message.externalId, channelId: channelId, xxdk: self.xxdk)
          }
        }
      }
    }
    .alert(
      "Leaving Haven",
      isPresented: self.$showLinkWarning,
      presenting: self.pendingURL
    ) { url in
      Button("Open Link") {
        NSWorkspace.shared.open(url)
      }
      Button("Cancel", role: .cancel) {}
    } message: { url in
      Text("Open this link in your browser?\n\n\(url.absoluteString)")
    }
  }
}

private struct MacReplyPreviewView: View {  let externalId: String
  let onTap: (String) -> Void

  @Dependency(\.defaultDatabase) private var database

  @FetchOne private var original: ChatMessageModel?

  @State private var senderName = "You"

  init(externalId: String, onTap: @escaping (String) -> Void) {
    self.externalId = externalId
    self.onTap = onTap
    _original = FetchOne(ChatMessageModel.where { $0.externalId.eq(externalId) })
  }

  var body: some View {
    Button {
      self.onTap(self.externalId)
    } label: {
      HStack(spacing: 6) {
        RoundedRectangle(cornerRadius: 1.5)
          .fill(Color.haven)
          .frame(width: 3)
        VStack(alignment: .leading, spacing: 1) {
          Text(self.senderName)
            .font(.caption2)
            .fontWeight(.semibold)
          Text(self.original?.message.stripParagraphTags() ?? "Message")
            .font(.caption)
            .lineLimit(2)
        }
        .foregroundStyle(.secondary)
      }
      .padding(6)
      .frame(maxWidth: 340, alignment: .leading)
      .background(Color.messageReplyPreview, in: RoundedRectangle(cornerRadius: 8))
    }
    .buttonStyle(.plain)
    .task(id: self.original?.senderId) {
      guard let senderId = original?.senderId else { return }
      self.senderName = (try? self.database.read { db in
        try MessageSenderModel.where { $0.id.eq(senderId) }.fetchOne(db)?.codename
      }) ?? "You"
    }
  }
}
