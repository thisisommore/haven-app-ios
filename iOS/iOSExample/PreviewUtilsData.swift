//
//  PreviewUtilsData.swift
//  iOSExample
//
//  Created by Om More on 22/12/25.
//

import Foundation

func previewMockMessages(chatId: String, senderId: String) -> [ChatMessageModel] {
    [
        ChatMessageModel(
            message: "Hi there 👋", isIncoming: true,
            chatId: chatId, senderId: senderId,
            id: InternalIdGenerator.shared.next(), externalId: UUID().uuidString, status: 2
        ),
        ChatMessageModel(
            message: "Hi there 👋", isIncoming: true,
            chatId: chatId, senderId: senderId,
            id: InternalIdGenerator.shared.next(), externalId: UUID().uuidString, status: 2
        ),
        ChatMessageModel(
            message: "Hi there 👋", isIncoming: true,
            chatId: chatId, senderId: senderId,
            id: InternalIdGenerator.shared.next(), externalId: UUID().uuidString, status: 2
        ),
        ChatMessageModel(
            message: "Yes sir", isIncoming: true,
            chatId: chatId, senderId: senderId,

            id: InternalIdGenerator.shared.next(), externalId: UUID().uuidString,
            replyTo: "Study overs?",
            status: 2,

        ),
        ChatMessageModel(
            message: "Study over?", isIncoming: false,
            chatId: chatId,
            id: InternalIdGenerator.shared.next(), externalId: "Study over?", status: 2
        ),
        ChatMessageModel(
            message: "All good! Working on the demo.", isIncoming: true,
            chatId: chatId, senderId: senderId,
            id: InternalIdGenerator.shared.next(),
            externalId: "4TDppExKKwB/pAvRNkCn9pGDi8IGPIGhJSKdouDoCqE=", status: 2
        ),
        ChatMessageModel(
            message: "How's it going?", isIncoming: false,
            chatId: chatId,
            id: InternalIdGenerator.shared.next(), externalId: UUID().uuidString, status: 2
        ),
        ChatMessageModel(
            message: "Hi there 👋", isIncoming: true,
            chatId: chatId, senderId: senderId,
            id: InternalIdGenerator.shared.next(), externalId: UUID().uuidString, status: 2
        ),
        ChatMessageModel(
            message: "Hi there 👋", isIncoming: true,
            chatId: chatId,
            id: InternalIdGenerator.shared.next(), externalId: UUID().uuidString, status: 2
        ),
        ChatMessageModel(
            message: "Hi there 👋", isIncoming: true,
            chatId: chatId,
            id: InternalIdGenerator.shared.next(), externalId: UUID().uuidString, status: 2
        ),
        ChatMessageModel(
            message: "Hi there 👋", isIncoming: true,
            chatId: chatId, senderId: senderId,
            id: InternalIdGenerator.shared.next(), externalId: UUID().uuidString, status: 2
        ),
        ChatMessageModel(
            message: "Hey Mayur!", isIncoming: false,
            chatId: chatId,
            id: InternalIdGenerator.shared.next(), externalId: UUID().uuidString, status: 2
        ),
        ChatMessageModel(
            message: "All good! Working on the demo.", isIncoming: true,
            chatId: chatId, senderId: senderId,
            id: InternalIdGenerator.shared.next(), externalId: UUID().uuidString,
            replyTo: "How's it going?",
            status: 2
        ),
        ChatMessageModel(
            message: "How's it going?", isIncoming: false,
            chatId: chatId,
            id: InternalIdGenerator.shared.next(), externalId: "How's it going?", status: 2
        ),
        ChatMessageModel(
            message: "Hi there 👋", isIncoming: true,
            chatId: chatId, senderId: senderId,
            id: InternalIdGenerator.shared.next(), externalId: UUID().uuidString, status: 2
        ),
        ChatMessageModel(
            message: "Hey Mayur!", isIncoming: false,
            chatId: chatId,
            id: InternalIdGenerator.shared.next(), externalId: UUID().uuidString, status: 2
        ),
        ChatMessageModel(
            message: "All good! Working on the demo.", isIncoming: true,
            chatId: chatId, senderId: senderId,
            id: InternalIdGenerator.shared.next(), externalId: UUID().uuidString, status: 2
        ),
        ChatMessageModel(
            message: "How's it going?", isIncoming: false,
            chatId: chatId,
            id: InternalIdGenerator.shared.next(), externalId: UUID().uuidString, status: 2
        ),
        ChatMessageModel(
            message: "Hi there 👋", isIncoming: true,
            chatId: chatId, senderId: senderId,
            id: InternalIdGenerator.shared.next(), externalId: UUID().uuidString, status: 2
        ),
        ChatMessageModel(
            message: "Hey Mayur!", isIncoming: false,
            chatId: chatId,
            id: InternalIdGenerator.shared.next(), externalId: UUID().uuidString, status: 2
        ),
        ChatMessageModel(
            message: "All good! Working on the demo.", isIncoming: true,
            chatId: chatId, senderId: senderId,
            id: InternalIdGenerator.shared.next(), externalId: UUID().uuidString, status: 2
        ),
        ChatMessageModel(
            message: "How's it going?", isIncoming: false,
            chatId: chatId,
            id: InternalIdGenerator.shared.next(), externalId: UUID().uuidString, status: 2
        ),
        ChatMessageModel(
            message: "Hi there 👋", isIncoming: true,
            chatId: chatId, senderId: senderId,
            id: InternalIdGenerator.shared.next(), externalId: UUID().uuidString, status: 2
        ),
        ChatMessageModel(
            message: "Hey Mayur!", isIncoming: false,
            chatId: chatId,
            id: InternalIdGenerator.shared.next(), externalId: UUID().uuidString, status: 2
        ),
        ChatMessageModel(
            message: "All good! Working on the demo.", isIncoming: true,
            chatId: chatId, senderId: senderId,
            id: InternalIdGenerator.shared.next(), externalId: UUID().uuidString, status: 2
        ),
        ChatMessageModel(
            message: "How's it going?", isIncoming: false,
            chatId: chatId,
            id: InternalIdGenerator.shared.next(), externalId: UUID().uuidString, status: 2
        ),
        ChatMessageModel(
            message: "Hi there 👋", isIncoming: true,
            chatId: chatId, senderId: senderId,
            id: InternalIdGenerator.shared.next(), externalId: UUID().uuidString, status: 2
        ),
        ChatMessageModel(
            message: "<p>Hey Mayur!</p>", isIncoming: false,
            chatId: chatId,
            id: InternalIdGenerator.shared.next(), externalId: UUID().uuidString, status: 2
        ),
    ]
}
