//
//  PreviewUtils.swift
//  iOSExample
//
//  Created by Om More on 22/12/25.
//

import Foundation
import SwiftUI

let previewChatId = "previewChatId"
let greenColorInt = 0x0B421F

extension View {
    func mock() -> some View {
        #if DEBUG
            let chatStore: ChatStore = {
                let appDb = try! AppDatabase.makeInMemory()
                let store = ChatStore(database: appDb)

                let chat = ChatModel(channelId: previewChatId, name: "Mayur")
                try! store.insertChat(chat)

                let mockSender = MessageSenderModel(id: "mock-sender-id", pubkey: Data(), codename: "Mayur", dmToken: 0, color: greenColorInt)
                try! store.dbQueue.write { db in try mockSender.insert(db) }

                let mockMsgs: [ChatMessageModel] = [
                    ChatMessageModel(
                        message: "Hi there 👋",
                        isIncoming: true,
                        chatId: previewChatId,
                        senderId: "mock-sender-id",
                        id: UUID().uuidString,
                        internalId: InternalIdGenerator.shared.next()
                    ),
                    ChatMessageModel(
                        message: "Yes sir",
                        isIncoming: true,
                        chatId: previewChatId,
                        senderId: "mock-sender-id",
                        id: UUID().uuidString,
                        internalId: InternalIdGenerator.shared.next(),
                        replyTo: "Study overs?"
                    ),
                    ChatMessageModel(
                        message: "Study over?",
                        isIncoming: false,
                        chatId: previewChatId,
                        id: "Study over?",
                        internalId: InternalIdGenerator.shared.next()
                    ),
                    ChatMessageModel(
                        message: "All good! Working on the demo.",
                        isIncoming: true,
                        chatId: previewChatId,
                        senderId: "mock-sender-id",
                        id: "4TDppExKKwB/pAvRNkCn9pGDi8IGPIGhJSKdouDoCqE=",
                        internalId: InternalIdGenerator.shared.next()
                    ),
                    ChatMessageModel(
                        message: "How's it going?",
                        isIncoming: false,
                        chatId: previewChatId,
                        id: UUID().uuidString,
                        internalId: InternalIdGenerator.shared.next()
                    ),
                    ChatMessageModel(
                        message: "<p>Hey Mayur!</p>",
                        isIncoming: false,
                        chatId: previewChatId,
                        id: UUID().uuidString,
                        internalId: InternalIdGenerator.shared.next()
                    ),
                ]

                for msg in mockMsgs {
                    try! store.insertMessage(msg)
                }

                let reaction = MessageReactionModel(
                    id: "wow",
                    internalId: InternalIdGenerator.shared.next(),
                    targetMessageId: "4TDppExKKwB/pAvRNkCn9pGDi8IGPIGhJSKdouDoCqE=",
                    emoji: "💚",
                    senderId: "mock-sender-id"
                )
                try! store.upsertReaction(reaction)

                for name in ["<self>", "Tom", "Shashank"] {
                    let dmChat = ChatModel(pubKey: name.data(using: .utf8)!, name: name, dmToken: 0, color: greenColorInt)
                    try! store.insertChat(dmChat)
                    let msg = ChatMessageModel(
                        message: "<p>Hello world</p>",
                        isIncoming: true,
                        chatId: dmChat.id,
                        id: name,
                        internalId: InternalIdGenerator.shared.next(),
                        timestamp: 1
                    )
                    try! store.insertMessage(msg)
                }

                return store
            }()

            return NavigationStack {
                self
            }
            .environmentObject(chatStore)
            .environmentObject(XXDKMock())
            .environmentObject(SelectedChat())
            .navigationBarBackButtonHidden()
        #else
            return self
        #endif
    }
}
