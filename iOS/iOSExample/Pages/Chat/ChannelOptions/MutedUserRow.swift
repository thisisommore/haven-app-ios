//
//  MutedUserRow.swift
//  iOSExample
//
//  Created by Om More
//

import SwiftUI

struct MutedUserRow: View {
    let pubKey: Data
    var onUnmute: (() -> Void)?
    @EnvironmentObject var chatStore: ChatStore
    @State private var sender: MessageSenderModel?

    var body: some View {
        HStack {
            Image(systemName: "speaker.slash.fill")
                .foregroundColor(.secondary)
            if let sender {
                Text(sender.codename)
                    .foregroundColor(.primary)
            } else {
                Text(pubKey.base64EncodedString())
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button {
                onUnmute?()
            } label: {
                Text("Unmute")
                    .font(.caption)
                    .foregroundColor(.haven)
            }
            .buttonStyle(.borderless)
        }
        .onAppear {
            sender = try? chatStore.fetchSender(pubkey: pubKey)
        }
    }
}
