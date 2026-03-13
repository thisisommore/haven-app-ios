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
        color: greenColorInt
      )

      try! database.write { db in
        try ChatModel.insert { chat }.execute(db)
        try MessageSenderModel.insert { mockSender }.execute(db)

        let mockMsgs = previewMockMessages(chatId: chat.id, senderId: mockSender.id)

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
              timestamp: 1,
              status: 2
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
