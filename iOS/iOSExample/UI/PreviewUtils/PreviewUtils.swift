//
//  PreviewUtils.swift
//  iOSExample
//
//  Created by Om More on 22/12/25.
//

import Dependencies
import Foundation
import SQLiteData
import SwiftUI

let previewChatId = UUID()
let previewChannelId = "previewChatId"
let greenColorInt = 0x0B421F

/// Preview wrapper: seeds DB and dependencies before `content` is built (DEBUG only).
struct Mock<Content: View>: View {
  @ViewBuilder let content: () -> Content
  private let database: any DatabaseWriter

  init(@ViewBuilder content: @escaping () -> Content) {
    self.content = content
    let db = try! appDatabase()
    self.database = db
    try! Self.seedPreviewDatabase(db)
  }

  var body: some View {
    withDependencies {
      $0.defaultDatabase = self.database
    } operation: {
      NavigationStack {
        self.content()
      }
      .environmentObject(XXDKMock())
      .environmentObject(SelectedChat())
      .navigationBarBackButtonHidden()
    }
  }

  private static func seedPreviewDatabase(_ database: any DatabaseWriter) throws {
    var chat = ChatModel(channelId: previewChannelId, name: "Mayur")
    chat.id = previewChatId
    let mockSender = MessageSenderModel(
      pubkey: Data(), codename: "Mayur", nickname: nil, dmToken: nil,
      color: greenColorInt
    )

    try database.write { db in
      try ChatModel.insert { chat }.execute(db)
      try MessageSenderModel.insert { mockSender }.execute(db)

      let mockMsgs = previewMockMessages(chatId: chat.id, senderId: mockSender.id)

      for msg in mockMsgs {
        try ChatMessageModel.insert { msg }.execute(db)
      }

      try MessageReactionModel.insert {
        MessageReactionModel(
          id: InternalIdGenerator.shared.next(),
          externalId: "wow",
          targetMessageId: "4TDppExKKwB/pAvRNkCn9pGDi8IGPIGhJSKdouDoCqE=",
          emoji: "💚",
          senderId: mockSender.id
        )
      }.execute(db)

      for name in ["Notes", "Tom", "Shashank"] {
        let dmChat = ChatModel(
          pubKey: name.data, name: name, dmToken: 0, color: greenColorInt
        )
        try ChatModel.insert { dmChat }.execute(db)
        try ChatMessageModel.insert {
          ChatMessageModel(
            message: "<p>Hello world</p>",
            isIncoming: true,
            chatId: dmChat.id,
            id: InternalIdGenerator.shared.next(),
            externalId: name,
            replyTo: nil,
            timestamp: Date(),
            status: .delivered
          )
        }.execute(db)
      }
    }
  }
}
