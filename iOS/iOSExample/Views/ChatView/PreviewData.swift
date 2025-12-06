//
//  PreviewData.swift
//  iOSExample
//
//  Created by Om More on 28/09/25.
//
import Foundation
#if DEBUG
// Create a mock chat and some messages
let previewChatId = "previewChatId"
let chat = Chat(channelId: previewChatId, name: "Mayur")
let mockSender = Sender(id: "mock-sender-id", pubkey: Data(), codename: "Mayur", dmToken: 0, color: greenColorInt)
let greenColorInt = 0x0b421f
var mockMsgs = [
    ChatMessage(
        message: "Hi there 👋",
        isIncoming: true,
        chat: chat,
        sender: mockSender,
        id: UUID().uuidString,
        internalId: InternalIdGenerator.shared.next()
    ),   ChatMessage(
        message: "Hi there 👋",
        isIncoming: true,
        chat: chat,
        sender: mockSender,
        id: UUID().uuidString,
        internalId: InternalIdGenerator.shared.next()
    ),   ChatMessage(
        message: "Hi there 👋",
        isIncoming: true,
        chat: chat,
        sender: mockSender,
        id: UUID().uuidString,
        internalId: InternalIdGenerator.shared.next()
    ),
    ChatMessage(
        message: "Yes sir",
        isIncoming: true,
        chat: chat,
        sender: mockSender,
        id: UUID().uuidString,
        internalId: InternalIdGenerator.shared.next(),
        replyTo: "Study overs?"
    ),
    ChatMessage(
        message: "Study over?",
        isIncoming: false,
        chat: chat,
        id: "Study over?",
        internalId: InternalIdGenerator.shared.next()
    ),
    ChatMessage(
        message: "All good! Working on the demo.",
        isIncoming: true,
        chat: chat,
        sender: mockSender,
        id: "4TDppExKKwB/pAvRNkCn9pGDi8IGPIGhJSKdouDoCqE=",
        internalId: InternalIdGenerator.shared.next()
    ),
    ChatMessage(
        message: "How's it going?",
        isIncoming: false,
        chat: chat,
        id: UUID().uuidString,
        internalId: InternalIdGenerator.shared.next()
    ),
    ChatMessage(
        message: "Hi there 👋",
        isIncoming: true,
        chat: chat,
        sender: mockSender,
        id: UUID().uuidString,
        internalId: InternalIdGenerator.shared.next()
    ),
    ChatMessage(
        message: "Hi there 👋",
        isIncoming: true,
        chat: chat,
        id: UUID().uuidString,
        internalId: InternalIdGenerator.shared.next()
    ),
    ChatMessage(
        message: "Hi there 👋",
        isIncoming: true,
        chat: chat,
        id: UUID().uuidString,
        internalId: InternalIdGenerator.shared.next()
    ),
    ChatMessage(
        message: "Hi there 👋",
        isIncoming: true,
        chat: chat,
        sender: mockSender,
        id: UUID().uuidString,
        internalId: InternalIdGenerator.shared.next()
    ),
    ChatMessage(
        message: "Hey Mayur!",
        isIncoming: false,
        chat: chat,
        id: UUID().uuidString,
        internalId: InternalIdGenerator.shared.next()
    ),
    ChatMessage(
        message: "All good! Working on the demo.",
        isIncoming: true,
        chat: chat,
        sender: mockSender,
        id: UUID().uuidString,
        internalId: InternalIdGenerator.shared.next(),
        replyTo: "How's it going?"
    ),
    ChatMessage(
        message: "How's it going?",
        isIncoming: false,
        chat: chat,
        id: "How's it going?",
        internalId: InternalIdGenerator.shared.next()
    ),
    ChatMessage(
        message: "Hi there 👋",
        isIncoming: true,
        chat: chat,
        sender: mockSender,
        id: UUID().uuidString,
        internalId: InternalIdGenerator.shared.next()
    ),
    ChatMessage(
        message: "Hey Mayur!",
        isIncoming: false,
        chat: chat,
        id: UUID().uuidString,
        internalId: InternalIdGenerator.shared.next()
    ),
    ChatMessage(
        message: "All good! Working on the demo.",
        isIncoming: true,
        chat: chat,
        sender: mockSender,
        id: UUID().uuidString,
        internalId: InternalIdGenerator.shared.next()
    ),
    ChatMessage(
        message: "How's it going?",
        isIncoming: false,
        chat: chat,
        id: UUID().uuidString,
        internalId: InternalIdGenerator.shared.next()
    ),
    ChatMessage(
        message: "Hi there 👋",
        isIncoming: true,
        chat: chat,
        sender: mockSender,
        id: UUID().uuidString,
        internalId: InternalIdGenerator.shared.next()
    ),
    ChatMessage(
        message: "Hey Mayur!",
        isIncoming: false,
        chat: chat,
        id: UUID().uuidString,
        internalId: InternalIdGenerator.shared.next()
    ),
    ChatMessage(
        message: "All good! Working on the demo.",
        isIncoming: true,
        chat: chat,
        sender: mockSender,
        id: UUID().uuidString,
        internalId: InternalIdGenerator.shared.next()
    ),
    ChatMessage(
        message: "How's it going?",
        isIncoming: false,
        chat: chat,
        id: UUID().uuidString,
        internalId: InternalIdGenerator.shared.next()
    ),
    ChatMessage(
        message: "Hi there 👋",
        isIncoming: true,
        chat: chat,
        sender: mockSender,
        id: UUID().uuidString,
        internalId: InternalIdGenerator.shared.next()
    ),
    ChatMessage(
        message: "Hey Mayur!",
        isIncoming: false,
        chat: chat,
        id: UUID().uuidString,
        internalId: InternalIdGenerator.shared.next()
    ),
    ChatMessage(
        message: "All good! Working on the demo.",
        isIncoming: true,
        chat: chat,
        sender: mockSender,
        id: UUID().uuidString,
        internalId: InternalIdGenerator.shared.next()
    ),
    ChatMessage(
        message: "How's it going?",
        isIncoming: false,
        chat: chat,
        id: UUID().uuidString,
        internalId: InternalIdGenerator.shared.next()
    ),
    ChatMessage(
        message: "Hi there 👋",
        isIncoming: true,
        chat: chat,
        sender: mockSender,
        id: UUID().uuidString,
        internalId: InternalIdGenerator.shared.next()
    ),
    ChatMessage(
        message: "<p>Hey Mayur!</p>",
        isIncoming: false,
        chat: chat,
        id: UUID().uuidString,
        internalId: InternalIdGenerator.shared.next()
    ),
]

var reactions = [
    MessageReaction(
        id: "wow",
        internalId: InternalIdGenerator.shared.next(),
        targetMessageId: "4TDppExKKwB/pAvRNkCn9pGDi8IGPIGhJSKdouDoCqE=",
        emoji: "💚",
        sender: mockSender
    )
]
#endif
