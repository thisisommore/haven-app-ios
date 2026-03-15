//
//  MessageContextMenu.swift
//  iOSExample
//
//  Created by Om More on 19/10/25.
//

import SwiftUI
import UniformTypeIdentifiers

/// Context menu options for message interactions
struct MessageContextMenu: View {
  let text: String
  let isIncoming: Bool
  let sender: MessageSenderModel?
  let isAdmin: Bool

  @Binding var selectedEmoji: MessageEmoji
  @Binding var shouldTriggerReply: Bool

  var onDM: ((String, Int32, Data, Int) -> Void)?
  var onSelectText: (() -> Void)?
  var onDelete: (() -> Void)?
  var onMute: ((Data) -> Void)?
  var onUnmute: ((Data) -> Void)?
  let isSenderMuted: Bool

  /// Check if user can delete this message (admin or message owner)
  private var canDelete: Bool {
    self.isAdmin || !self.isIncoming
  }

  var body: some View {
    // Emoji picker
    Picker("React", selection: self.$selectedEmoji) {
      Button(action: {}) {
        Image(systemName: "plus")
      }
      .tag(MessageEmoji.custom)
    }
    .pickerStyle(.palette)

    // Reply button
    Button {
      self.shouldTriggerReply = true
    } label: {
      Label("Reply", systemImage: "arrowshape.turn.up.left")
    }

    // DM button (only for incoming messages with DM token)
    if self.isIncoming,
       let sender = sender,
       let dmToken = sender.dmToken {
      Button {
        self.onDM?(sender.codename, dmToken, sender.pubkey, sender.color)
      } label: {
        Label("Send DM", systemImage: "message")
      }
    }

    // Copy button
    Button {
      UIPasteboard.general.setValue(
        stripParagraphTags(self.text),
        forPasteboardType: UTType.plainText.identifier
      )
    } label: {
      Label("Copy", systemImage: "doc.on.doc")
    }

    // Select Text button
    Button {
      self.onSelectText?()
    } label: {
      Label("Select Text", systemImage: "crop")
    }

    // Delete button (only for admin or message owner)
    if self.canDelete {
      Button(role: .destructive) {
        self.onDelete?()
      } label: {
        Label("Delete", systemImage: "trash")
      }
    }

    // Mute/Unmute button (only for admin on incoming messages)
    if self.isAdmin, self.isIncoming, let sender = sender {
      if self.isSenderMuted {
        Button {
          self.onUnmute?(sender.pubkey)
        } label: {
          Label("Unmute User", systemImage: "speaker.wave.2")
        }
      } else {
        Button(role: .destructive) {
          self.onMute?(sender.pubkey)
        } label: {
          Label("Mute User", systemImage: "speaker.slash")
        }
      }
    }
  }
}
