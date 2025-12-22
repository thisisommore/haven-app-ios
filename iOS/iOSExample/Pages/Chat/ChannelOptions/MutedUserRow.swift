//
//  MutedUserRow.swift
//  iOSExample
//
//  Created by Om More
//

import SwiftData
import SwiftUI

struct MutedUserRow: View {
    let pubKey: Data
    var onUnmute: (() -> Void)?
    @Query private var senders: [MessageSenderModel]

    init(pubKey: Data, onUnmute: (() -> Void)? = nil) {
        self.pubKey = pubKey
        self.onUnmute = onUnmute
        _senders = Query(filter: #Predicate<MessageSenderModel> { sender in
            sender.pubkey == pubKey
        })
    }

    var body: some View {
        HStack {
            Image(systemName: "speaker.slash.fill")
                .foregroundColor(.secondary)
            if let sender = senders.first {
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



