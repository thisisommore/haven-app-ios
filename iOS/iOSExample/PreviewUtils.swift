//
//  PreviewUtils.swift
//  iOSExample
//
//  Created by Om More on 22/12/25.
//

import Foundation
import SQLiteData
import SwiftUI

let previewChatId = "previewChatId"
let greenColorInt = 0x0B421F

extension View {
    func mock() -> some View {
        #if DEBUG
            prepareDependencies {
                $0.defaultDatabase = try! appDatabase()
            }
            @Dependency(\.defaultDatabase) var database

            let chat = ChatModel(channelId: previewChatId, name: "Mayur")
            let mockSender = MessageSenderModel(
                id: "mock-sender-id", pubkey: Data(), codename: "Mayur", dmToken: 0,
                color: greenColorInt)

            try! database.write { db in
                try ChatModel.insert { chat }.execute(db)
                try MessageSenderModel.insert { mockSender }.execute(db)

                let mockMsgs = [
                    ChatMessageModel(
                        message: "Hi there 👋", isIncoming: true,
                        chatId: chat.id, senderId: mockSender.id,
                        id: UUID().uuidString, internalId: InternalIdGenerator.shared.next()
                    ),
                    ChatMessageModel(
                        message: "Hi there 👋", isIncoming: true,
                        chatId: chat.id, senderId: mockSender.id,
                        id: UUID().uuidString, internalId: InternalIdGenerator.shared.next()
                    ),
                    ChatMessageModel(
                        message: "Hi there 👋", isIncoming: true,
                        chatId: chat.id, senderId: mockSender.id,
                        id: UUID().uuidString, internalId: InternalIdGenerator.shared.next()
                    ),
                    ChatMessageModel(
                        message: "Yes sir", isIncoming: true,
                        chatId: chat.id, senderId: mockSender.id,
                        id: UUID().uuidString, internalId: InternalIdGenerator.shared.next(),
                        replyTo: "Study overs?"
                    ),
                    ChatMessageModel(
                        message: "Study over?", isIncoming: false,
                        chatId: chat.id,
                        id: "Study over?", internalId: InternalIdGenerator.shared.next()
                    ),
                    ChatMessageModel(
                        message: "All good! Working on the demo.", isIncoming: true,
                        chatId: chat.id, senderId: mockSender.id,
                        id: "4TDppExKKwB/pAvRNkCn9pGDi8IGPIGhJSKdouDoCqE=",
                        internalId: InternalIdGenerator.shared.next()
                    ),
                    ChatMessageModel(
                        message: "How's it going?", isIncoming: false,
                        chatId: chat.id,
                        id: UUID().uuidString, internalId: InternalIdGenerator.shared.next()
                    ),
                    ChatMessageModel(
                        message: "Hi there 👋", isIncoming: true,
                        chatId: chat.id, senderId: mockSender.id,
                        id: UUID().uuidString, internalId: InternalIdGenerator.shared.next()
                    ),
                    ChatMessageModel(
                        message: "Hi there 👋", isIncoming: true,
                        chatId: chat.id,
                        id: UUID().uuidString, internalId: InternalIdGenerator.shared.next()
                    ),
                    ChatMessageModel(
                        message: "Hi there 👋", isIncoming: true,
                        chatId: chat.id,
                        id: UUID().uuidString, internalId: InternalIdGenerator.shared.next()
                    ),
                    ChatMessageModel(
                        message: "Hi there 👋", isIncoming: true,
                        chatId: chat.id, senderId: mockSender.id,
                        id: UUID().uuidString, internalId: InternalIdGenerator.shared.next()
                    ),
                    ChatMessageModel(
                        message: "Hey Mayur!", isIncoming: false,
                        chatId: chat.id,
                        id: UUID().uuidString, internalId: InternalIdGenerator.shared.next()
                    ),
                    ChatMessageModel(
                        message: "All good! Working on the demo.", isIncoming: true,
                        chatId: chat.id, senderId: mockSender.id,
                        id: UUID().uuidString, internalId: InternalIdGenerator.shared.next(),
                        replyTo: "How's it going?"
                    ),
                    ChatMessageModel(
                        message: "How's it going?", isIncoming: false,
                        chatId: chat.id,
                        id: "How's it going?", internalId: InternalIdGenerator.shared.next()
                    ),
                    ChatMessageModel(
                        message: "Hi there 👋", isIncoming: true,
                        chatId: chat.id, senderId: mockSender.id,
                        id: UUID().uuidString, internalId: InternalIdGenerator.shared.next()
                    ),
                    ChatMessageModel(
                        message: "Hey Mayur!", isIncoming: false,
                        chatId: chat.id,
                        id: UUID().uuidString, internalId: InternalIdGenerator.shared.next()
                    ),
                    ChatMessageModel(
                        message: "All good! Working on the demo.", isIncoming: true,
                        chatId: chat.id, senderId: mockSender.id,
                        id: UUID().uuidString, internalId: InternalIdGenerator.shared.next()
                    ),
                    ChatMessageModel(
                        message: "How's it going?", isIncoming: false,
                        chatId: chat.id,
                        id: UUID().uuidString, internalId: InternalIdGenerator.shared.next()
                    ),
                    ChatMessageModel(
                        message: "Hi there 👋", isIncoming: true,
                        chatId: chat.id, senderId: mockSender.id,
                        id: UUID().uuidString, internalId: InternalIdGenerator.shared.next()
                    ),
                    ChatMessageModel(
                        message: "Hey Mayur!", isIncoming: false,
                        chatId: chat.id,
                        id: UUID().uuidString, internalId: InternalIdGenerator.shared.next()
                    ),
                    ChatMessageModel(
                        message: "All good! Working on the demo.", isIncoming: true,
                        chatId: chat.id, senderId: mockSender.id,
                        id: UUID().uuidString, internalId: InternalIdGenerator.shared.next()
                    ),
                    ChatMessageModel(
                        message: "How's it going?", isIncoming: false,
                        chatId: chat.id,
                        id: UUID().uuidString, internalId: InternalIdGenerator.shared.next()
                    ),
                    ChatMessageModel(
                        message: "Hi there 👋", isIncoming: true,
                        chatId: chat.id, senderId: mockSender.id,
                        id: UUID().uuidString, internalId: InternalIdGenerator.shared.next()
                    ),
                    ChatMessageModel(
                        message: "Hey Mayur!", isIncoming: false,
                        chatId: chat.id,
                        id: UUID().uuidString, internalId: InternalIdGenerator.shared.next()
                    ),
                    ChatMessageModel(
                        message: "All good! Working on the demo.", isIncoming: true,
                        chatId: chat.id, senderId: mockSender.id,
                        id: UUID().uuidString, internalId: InternalIdGenerator.shared.next()
                    ),
                    ChatMessageModel(
                        message: "How's it going?", isIncoming: false,
                        chatId: chat.id,
                        id: UUID().uuidString, internalId: InternalIdGenerator.shared.next()
                    ),
                    ChatMessageModel(
                        message: "Hi there 👋", isIncoming: true,
                        chatId: chat.id, senderId: mockSender.id,
                        id: UUID().uuidString, internalId: InternalIdGenerator.shared.next()
                    ),
                    ChatMessageModel(
                        message: "<p>Hey Mayur!</p>", isIncoming: false,
                        chatId: chat.id,
                        id: UUID().uuidString, internalId: InternalIdGenerator.shared.next()
                    ),
                ]

                for msg in mockMsgs {
                    try ChatMessageModel.insert { msg }.execute(db)
                }

                try MessageReactionModel.insert {
                    MessageReactionModel(
                        id: "wow",
                        internalId: InternalIdGenerator.shared.next(),
                        targetMessageId: "4TDppExKKwB/pAvRNkCn9pGDi8IGPIGhJSKdouDoCqE=",
                        emoji: "💚",
                        senderId: mockSender.id
                    )
                }.execute(db)

                for name in ["<self>", "Tom", "Shashank"] {
                    let dmChat = ChatModel(
                        pubKey: name.data, name: name, dmToken: 0, color: greenColorInt)
                    try ChatModel.insert { dmChat }.execute(db)
                    try ChatMessageModel.insert {
                        ChatMessageModel(
                            message: "<p>Hello world</p>",
                            isIncoming: true,
                            chatId: dmChat.id,
                            id: name,
                            internalId: InternalIdGenerator.shared.next(),
                            replyTo: nil,
                            timestamp: 1
                        )
                    }.execute(db)
                }
            }

            return NavigationStack {
                self
            }
            .environmentObject(XXDKMock())
            .environmentObject(SelectedChat())
            .navigationBarBackButtonHidden()
        #else
            return self
        #endif
    }
}
