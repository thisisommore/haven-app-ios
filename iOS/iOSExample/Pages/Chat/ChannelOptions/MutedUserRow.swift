//
//  MutedUserRow.swift
//  iOSExample
//
//  Created by Om More
//

import SQLiteData
import SwiftUI

struct MutedUserRow: View {
    let pubKey: Data
    var onUnmute: (() -> Void)?
    @FetchOne private var sender: MessageSenderModel?

    init(pubKey: Data, onUnmute: (() -> Void)? = nil) {
        self.pubKey = pubKey
        self.onUnmute = onUnmute
        let pk = pubKey
        _sender = FetchOne(MessageSenderModel.where { $0.pubkey.eq(pk) })
    }

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
    }
}
