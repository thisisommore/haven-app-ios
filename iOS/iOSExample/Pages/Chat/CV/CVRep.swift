//
//  CVRep.swift
//  iOSExample
//
//  Created by Om More on 06/03/26.
//

import SwiftUI

struct MaxChat: UIViewControllerRepresentable {
  @EnvironmentObject private var chatStore: ChatStore
  let chatId: String
  let pageSize: Int = 50

  var onReplyMessage: ((ChatMessageModel) -> Void)? = nil
  var onDMMessage: ((String, Int32, Data, Int) -> Void)? = nil
  var onDeleteMessage: ((ChatMessageModel) -> Void)? = nil
  var onMuteUser: ((Data) -> Void)? = nil
  var onUnmuteUser: ((Data) -> Void)? = nil

  init(
    chatId: String,
    onReplyMessage: ((ChatMessageModel) -> Void)? = nil,
    onDMMessage: ((String, Int32, Data, Int) -> Void)? = nil,
    onDeleteMessage: ((ChatMessageModel) -> Void)? = nil,
    onMuteUser: ((Data) -> Void)? = nil,
    onUnmuteUser: ((Data) -> Void)? = nil
  ) {
    self.chatId = chatId
    self.onReplyMessage = onReplyMessage
    self.onDMMessage = onDMMessage
    self.onDeleteMessage = onDeleteMessage
    self.onMuteUser = onMuteUser
    self.onUnmuteUser = onUnmuteUser
  }

  func makeUIViewController(context _: Context) -> Controller {
    let controller = Controller(chatId: chatId, pageSize: pageSize, chatStore: chatStore)
    controller.updateCallbacks(
      onReplyMessage: onReplyMessage,
      onDMMessage: onDMMessage,
      onDeleteMessage: onDeleteMessage,
      onMuteUser: onMuteUser,
      onUnmuteUser: onUnmuteUser
    )
    return controller
  }

  func updateUIViewController(_ uiViewController: Controller, context _: Context) {
  }

}
