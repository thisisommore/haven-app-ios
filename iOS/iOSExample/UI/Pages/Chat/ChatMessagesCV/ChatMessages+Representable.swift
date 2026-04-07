//
//  ChatMessages+Representable.swift
//  iOSExample
//
//  Created by Om More on 21/03/26.
//
import HavenCore
import SwiftUI
import UIKit

struct ChatMessages: UIViewControllerRepresentable {
  var chat: ChatModel
  var onReply: (ChatMessageModel) -> Void
  var onReact: (ChatMessageModel) -> Void
  /// Using externalId
  var onDeleteMessage: (String) -> Void
  var onMuteUser: (Data) -> Void
  var onDeleteReaction: (MessageReactionModel) -> Void

  func updateUIViewController(_ uiViewController: ChatMessagesVC, context _: Context) {
    uiViewController.chat = self.chat
    uiViewController.onReply = self.onReply
    uiViewController.onReact = self.onReact
    uiViewController.onDeleteMessage = self.onDeleteMessage
    uiViewController.onMuteUser = self.onMuteUser
    uiViewController.onDeleteReaction = self.onDeleteReaction
  }

  func makeUIViewController(context _: Context) -> ChatMessagesVC {
    ChatMessagesVC(
      chat: self.chat,
      onReply: self.onReply,
      onReact: self.onReact,
      onDeleteMessage: self.onDeleteMessage,
      onMuteUser: self.onMuteUser,
      onDeleteReaction: self.onDeleteReaction
    )
  }
}
