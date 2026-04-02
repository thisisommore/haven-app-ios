//
//  PreviewUtils+Data.swift
//  iOSExample
//
//  Created by Om More on 22/12/25.
//

import Foundation

private typealias PreviewMessageFactory = (
  _ message: String,
  _ externalId: String?,
  _ replyTo: String?
) -> ChatMessageModel

// returns a function
// uses provided chatId and senderId for each call
private func makePreviewIncomingMessageFactory(chatId: UUID, senderId: UUID)
  -> PreviewMessageFactory {
  { message, externalId, replyTo in
    ChatMessageModel(
      message: message,
      isIncoming: true,
      chatId: chatId,
      senderId: senderId,
      id: InternalIdGenerator.shared.next(),
      externalId: externalId ?? UUID().uuidString,
      replyTo: replyTo,
      timestamp: Date(),
      status: .delivered
    )
  }
}

private func makePreviewIncomingMessageFactory(chatId: UUID) -> PreviewMessageFactory {
  { message, externalId, replyTo in
    ChatMessageModel(
      message: message,
      isIncoming: true,
      chatId: chatId,
      id: InternalIdGenerator.shared.next(),
      externalId: externalId ?? UUID().uuidString,
      replyTo: replyTo,
      timestamp: Date(),
      status: .delivered
    )
  }
}

private func makePreviewOutgoingMessageFactory(chatId: UUID) -> PreviewMessageFactory {
  { message, externalId, replyTo in
    ChatMessageModel(
      message: message,
      isIncoming: false,
      chatId: chatId,
      id: InternalIdGenerator.shared.next(),
      externalId: externalId ?? UUID().uuidString,
      replyTo: replyTo,
      timestamp: Date(),
      status: .delivered
    )
  }
}

func previewMockMessages(chatId: UUID, senderId: UUID) -> [ChatMessageModel] {
  let makeIncomingMessage = makePreviewIncomingMessageFactory(chatId: chatId, senderId: senderId)
  let makeIncomingMessageWithoutSender = makePreviewIncomingMessageFactory(
    chatId: chatId
  )
  let makeOutgoingMessage = makePreviewOutgoingMessageFactory(chatId: chatId)

  return [
    makeIncomingMessage("Hi there 👋", nil, nil),
    makeIncomingMessage("Hi there 👋", nil, nil),
    makeIncomingMessage("Hi there 👋", nil, nil),
    makeIncomingMessage("Yes sir", nil, "Study overs?"),
    makeOutgoingMessage("Study over?", "Study over?", nil),
    makeIncomingMessage(
      "All good! Working on the demo.",
      "4TDppExKKwB/pAvRNkCn9pGDi8IGPIGhJSKdouDoCqE=",
      nil
    ),
    makeOutgoingMessage("How's it going?", nil, nil),
    makeIncomingMessage("Hi there 👋", nil, nil),
    makeIncomingMessageWithoutSender("Hi there 👋", nil, nil),
    makeIncomingMessageWithoutSender("Hi there 👋", nil, nil),
    makeIncomingMessage("Hi there 👋", nil, nil),
    makeOutgoingMessage("Hey Mayur!", nil, nil),
    makeIncomingMessage("All good! Working on the demo.", nil, "How's it going?"),
    makeOutgoingMessage("How's it going?", "How's it going?", nil),
    makeIncomingMessage("Hi there 👋", nil, nil),
    makeOutgoingMessage("Hey Mayur!", nil, nil),
    makeIncomingMessage("All good! Working on the demo.", nil, nil),
    makeOutgoingMessage("How's it going?", nil, nil),
    makeIncomingMessage("Hi there 👋", nil, nil),
    makeOutgoingMessage("Hey Mayur!", nil, nil),
    makeIncomingMessage("All good! Working on the demo.", nil, nil),
    makeOutgoingMessage("How's it going?", nil, nil),
    makeIncomingMessage("Hi there 👋", nil, nil),
    makeOutgoingMessage("Hey Mayur!", nil, nil),
    makeIncomingMessage("All good! Working on the demo.", nil, nil),
    makeOutgoingMessage("How's it going?", nil, nil),
    makeIncomingMessage("Hi there 👋", nil, nil),
    makeOutgoingMessage("<p>Hey Mayur!</p>", nil, nil),
  ]
}
