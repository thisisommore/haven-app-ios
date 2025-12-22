//
//  PreviewUtils.swift
//  iOSExample
//
//  Created by Om More on 22/12/25.
//

import SwiftUI
import Foundation
import SwiftData

#if DEBUG
// Create a mock chat and some messages
let previewChatId = "previewChatId"
let greenColorInt = 0x0B421F

extension View {
    func mock() -> some View {
        let container: ModelContainer = {
            let c = try! ModelContainer(
                for: ChatModel.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            
            let chat = ChatModel(channelId: previewChatId, name: "Mayur")
            let mockSender = MessageSenderModel(id: "mock-sender-id", pubkey: Data(), codename: "Mayur", dmToken: 0, color: greenColorInt)
            
            c.mainContext.insert(chat)
            
            let mockMsgs = [
                ChatMessageModel(
                    message: "Hi there 👋",
                    isIncoming: true,
                    chat: chat,
                    sender: mockSender,
                    id: UUID().uuidString,
                    internalId: InternalIdGenerator.shared.next()
                ), ChatMessageModel(
                    message: "Hi there 👋",
                    isIncoming: true,
                    chat: chat,
                    sender: mockSender,
                    id: UUID().uuidString,
                    internalId: InternalIdGenerator.shared.next()
                ), ChatMessageModel(
                    message: "Hi there 👋",
                    isIncoming: true,
                    chat: chat,
                    sender: mockSender,
                    id: UUID().uuidString,
                    internalId: InternalIdGenerator.shared.next()
                ),
                ChatMessageModel(
                    message: "Yes sir",
                    isIncoming: true,
                    chat: chat,
                    sender: mockSender,
                    id: UUID().uuidString,
                    internalId: InternalIdGenerator.shared.next(),
                    replyTo: "Study overs?"
                ),
                ChatMessageModel(
                    message: "Study over?",
                    isIncoming: false,
                    chat: chat,
                    id: "Study over?",
                    internalId: InternalIdGenerator.shared.next()
                ),
                ChatMessageModel(
                    message: "All good! Working on the demo.",
                    isIncoming: true,
                    chat: chat,
                    sender: mockSender,
                    id: "4TDppExKKwB/pAvRNkCn9pGDi8IGPIGhJSKdouDoCqE=",
                    internalId: InternalIdGenerator.shared.next()
                ),
                ChatMessageModel(
                    message: "How's it going?",
                    isIncoming: false,
                    chat: chat,
                    id: UUID().uuidString,
                    internalId: InternalIdGenerator.shared.next()
                ),
                ChatMessageModel(
                    message: "Hi there 👋",
                    isIncoming: true,
                    chat: chat,
                    sender: mockSender,
                    id: UUID().uuidString,
                    internalId: InternalIdGenerator.shared.next()
                ),
                ChatMessageModel(
                    message: "Hi there 👋",
                    isIncoming: true,
                    chat: chat,
                    id: UUID().uuidString,
                    internalId: InternalIdGenerator.shared.next()
                ),
                ChatMessageModel(
                    message: "Hi there 👋",
                    isIncoming: true,
                    chat: chat,
                    id: UUID().uuidString,
                    internalId: InternalIdGenerator.shared.next()
                ),
                ChatMessageModel(
                    message: "Hi there 👋",
                    isIncoming: true,
                    chat: chat,
                    sender: mockSender,
                    id: UUID().uuidString,
                    internalId: InternalIdGenerator.shared.next()
                ),
                ChatMessageModel(
                    message: "Hey Mayur!",
                    isIncoming: false,
                    chat: chat,
                    id: UUID().uuidString,
                    internalId: InternalIdGenerator.shared.next()
                ),
                ChatMessageModel(
                    message: "All good! Working on the demo.",
                    isIncoming: true,
                    chat: chat,
                    sender: mockSender,
                    id: UUID().uuidString,
                    internalId: InternalIdGenerator.shared.next(),
                    replyTo: "How's it going?"
                ),
                ChatMessageModel(
                    message: "How's it going?",
                    isIncoming: false,
                    chat: chat,
                    id: "How's it going?",
                    internalId: InternalIdGenerator.shared.next()
                ),
                ChatMessageModel(
                    message: "Hi there 👋",
                    isIncoming: true,
                    chat: chat,
                    sender: mockSender,
                    id: UUID().uuidString,
                    internalId: InternalIdGenerator.shared.next()
                ),
                ChatMessageModel(
                    message: "Hey Mayur!",
                    isIncoming: false,
                    chat: chat,
                    id: UUID().uuidString,
                    internalId: InternalIdGenerator.shared.next()
                ),
                ChatMessageModel(
                    message: "All good! Working on the demo.",
                    isIncoming: true,
                    chat: chat,
                    sender: mockSender,
                    id: UUID().uuidString,
                    internalId: InternalIdGenerator.shared.next()
                ),
                ChatMessageModel(
                    message: "How's it going?",
                    isIncoming: false,
                    chat: chat,
                    id: UUID().uuidString,
                    internalId: InternalIdGenerator.shared.next()
                ),
                ChatMessageModel(
                    message: "Hi there 👋",
                    isIncoming: true,
                    chat: chat,
                    sender: mockSender,
                    id: UUID().uuidString,
                    internalId: InternalIdGenerator.shared.next()
                ),
                ChatMessageModel(
                    message: "Hey Mayur!",
                    isIncoming: false,
                    chat: chat,
                    id: UUID().uuidString,
                    internalId: InternalIdGenerator.shared.next()
                ),
                ChatMessageModel(
                    message: "All good! Working on the demo.",
                    isIncoming: true,
                    chat: chat,
                    sender: mockSender,
                    id: UUID().uuidString,
                    internalId: InternalIdGenerator.shared.next()
                ),
                ChatMessageModel(
                    message: "How's it going?",
                    isIncoming: false,
                    chat: chat,
                    id: UUID().uuidString,
                    internalId: InternalIdGenerator.shared.next()
                ),
                ChatMessageModel(
                    message: "Hi there 👋",
                    isIncoming: true,
                    chat: chat,
                    sender: mockSender,
                    id: UUID().uuidString,
                    internalId: InternalIdGenerator.shared.next()
                ),
                ChatMessageModel(
                    message: "Hey Mayur!",
                    isIncoming: false,
                    chat: chat,
                    id: UUID().uuidString,
                    internalId: InternalIdGenerator.shared.next()
                ),
                ChatMessageModel(
                    message: "All good! Working on the demo.",
                    isIncoming: true,
                    chat: chat,
                    sender: mockSender,
                    id: UUID().uuidString,
                    internalId: InternalIdGenerator.shared.next()
                ),
                ChatMessageModel(
                    message: "How's it going?",
                    isIncoming: false,
                    chat: chat,
                    id: UUID().uuidString,
                    internalId: InternalIdGenerator.shared.next()
                ),
                ChatMessageModel(
                    message: "Hi there 👋",
                    isIncoming: true,
                    chat: chat,
                    sender: mockSender,
                    id: UUID().uuidString,
                    internalId: InternalIdGenerator.shared.next()
                ),
                ChatMessageModel(
                    message: "<p>Hey Mayur!</p>",
                    isIncoming: false,
                    chat: chat,
                    id: UUID().uuidString,
                    internalId: InternalIdGenerator.shared.next()
                ),
            ]

            let reactions = [
                MessageReactionModel(
                    id: "wow",
                    internalId: InternalIdGenerator.shared.next(),
                    targetMessageId: "4TDppExKKwB/pAvRNkCn9pGDi8IGPIGhJSKdouDoCqE=",
                    emoji: "💚",
                    sender: mockSender
                ),
            ]
            
            for msg in mockMsgs {
                c.mainContext.insert(msg)
            }
            for reaction in reactions {
                c.mainContext.insert(reaction)
            }
            
            for name in ["<self>", "Tom", "Shashank"] {
                let chat = ChatModel(pubKey: name.data, name: name, dmToken: 0, color: greenColorInt)
                c.mainContext.insert(chat)
                c.mainContext.insert(
                    ChatMessageModel(
                        message: "<p>Hello world</p>",
                        isIncoming: true,
                        chat: chat,
                        sender: nil,
                        id: name,
                        internalId: InternalIdGenerator.shared.next(),
                        replyTo: nil,
                        timestamp: 1
                    )
                )
            }
            try! c.mainContext.save()
            return c
        }()
        
        return self
            .modelContainer(container)
            .environmentObject(SwiftDataActor(previewModelContainer: container))
            .environmentObject(XXDKMock())
            .environmentObject(SelectedChat())
            .navigationBarBackButtonHidden()
    }
}
#endif
