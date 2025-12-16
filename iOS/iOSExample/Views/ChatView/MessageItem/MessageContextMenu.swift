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
    let sender: SenderModel?
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
        isAdmin || !isIncoming
    }
    
    var body: some View {
        // Emoji picker
        Picker("React", selection: $selectedEmoji) {
            Button(action: {}) {
                Image(systemName: "plus")
            }
            .tag(MessageEmoji.custom)
        }
        .pickerStyle(.palette)
        
        // Reply button
        Button {
            shouldTriggerReply = true
        } label: {
            Label("Reply", systemImage: "arrowshape.turn.up.left")
        }
        
        // DM button (only for incoming messages with DM token)
        if isIncoming,
           let sender = sender,
           sender.dmToken != 0 {
            Button {
                onDM?(sender.codename, sender.dmToken, sender.pubkey, sender.color)
            } label: {
                Label("Send DM", systemImage: "message")
            }
        }
        
        // Copy button
        Button {
            UIPasteboard.general.setValue(
                stripParagraphTags(text),
                forPasteboardType: UTType.plainText.identifier
            )
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }

        // Select Text button
        Button {
            onSelectText?()
        } label: {
            Label("Select Text", systemImage: "crop")
        }
        
        // Delete button (only for admin or message owner)
        if canDelete {
            Button(role: .destructive) {
                onDelete?()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        
        // Mute/Unmute button (only for admin on incoming messages)
        if isAdmin, isIncoming, let sender = sender {
            if isSenderMuted {
                Button {
                    onUnmute?(sender.pubkey)
                } label: {
                    Label("Unmute User", systemImage: "speaker.wave.2")
                }
            } else {
                Button(role: .destructive) {
                    onMute?(sender.pubkey)
                } label: {
                    Label("Mute User", systemImage: "speaker.slash")
                }
            }
        }
    }
}
