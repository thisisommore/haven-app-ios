//
//  PreviewUtils+Data.swift
//  iOSExample
//
//  Created by Om More on 22/12/25.
//

import Foundation
import HavenCore

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
  let makeIncomingMessageFactory = makePreviewIncomingMessageFactory(chatId: chatId, senderId: senderId)
  let makeIncomingMessageWithoutSenderFactory = makePreviewIncomingMessageFactory(
    chatId: chatId
  )
  let makeOutgoingMessage = makePreviewOutgoingMessageFactory(chatId: chatId)

  func makeIncomingMessage(
    _ message: String,
    externalId: String? = nil,
    replyTo: String? = nil
  ) -> ChatMessageModel {
    makeIncomingMessageFactory(message, externalId, replyTo)
  }

  func makeIncomingMessageWithoutSender(
    _ message: String,
    externalId: String? = nil,
    replyTo: String? = nil
  ) -> ChatMessageModel {
    makeIncomingMessageWithoutSenderFactory(message, externalId, replyTo)
  }

  return [
    makeIncomingMessage("Hi there 👋", externalId: nil, replyTo: nil),
    makeIncomingMessage("Hi there 👋", externalId: nil, replyTo: nil),
    makeIncomingMessage("Hi there 👋", externalId: nil, replyTo: nil),
    makeIncomingMessage("Yes sir", externalId: nil, replyTo: "Study overs?"),
    makeOutgoingMessage("Study over?", "Study over?", nil),
    makeIncomingMessage(
      "All good! Working on the demo.",
      externalId: "4TDppExKKwB/pAvRNkCn9pGDi8IGPIGhJSKdouDoCqE=",
      replyTo: nil
    ),
    makeOutgoingMessage("How's it going?", nil, nil),
    makeIncomingMessage("Hi there 👋", externalId: nil, replyTo: nil),
    makeIncomingMessageWithoutSender("Hi there 👋", externalId: nil, replyTo: nil),
    makeIncomingMessageWithoutSender("Hi there 👋", externalId: nil, replyTo: nil),
    makeIncomingMessage("Hi there 👋", externalId: nil, replyTo: nil),
    makeOutgoingMessage("Hey Mayur!", nil, nil),
    makeIncomingMessage(
      "All good! Working on the demo.",
      externalId: nil,
      replyTo: "How's it going?"
    ),
    makeOutgoingMessage("How's it going?", "How's it going?", nil),
    makeIncomingMessage("Hi there 👋", externalId: nil, replyTo: nil),
    makeOutgoingMessage("Hey Mayur!", nil, nil),
    makeIncomingMessage("All good! Working on the demo.", externalId: nil, replyTo: nil),
    makeOutgoingMessage("How's it going?", nil, nil),
    makeIncomingMessage("Hi there 👋", externalId: nil, replyTo: nil),
    makeOutgoingMessage("Hey Mayur!", nil, nil),
    makeIncomingMessage("All good! Working on the demo.", externalId: nil, replyTo: nil),
    makeOutgoingMessage("How's it going?", nil, nil),
    makeIncomingMessage("Hi there 👋", externalId: nil, replyTo: nil),
    makeOutgoingMessage("Hey Mayur!", nil, nil),
    makeIncomingMessage("All good! Working on the demo.", externalId: nil, replyTo: nil),
    makeOutgoingMessage("How's it going?", nil, nil),
    makeIncomingMessage("Hi there 👋", externalId: nil, replyTo: nil),
    makeOutgoingMessage("<p>Hey Mayur!</p>", nil, nil),
  ]
}
