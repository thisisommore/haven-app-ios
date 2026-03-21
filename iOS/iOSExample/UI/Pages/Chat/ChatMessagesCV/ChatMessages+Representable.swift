//
//  ChatMessages+Representable.swift
//  iOSExample
//
//  Created by Om More on 21/03/26.
//
import SwiftUI
import UIKit

struct ChatMessages: UIViewControllerRepresentable {
  let chatId: UUID
  var onReply: (ChatMessageModel) -> Void
  var onReact: (ChatMessageModel) -> Void
  var onDeleteReaction: (MessageReactionModel) -> Void
  func updateUIViewController(_ uiViewController: ChatMessagesVC, context _: Context) {
    uiViewController.onReply = self.onReply
    uiViewController.onReact = self.onReact
    uiViewController.onDeleteReaction = self.onDeleteReaction
  }

  func makeUIViewController(context _: Context) -> ChatMessagesVC {
    return ChatMessagesVC(
      chatId: self.chatId,
      onReply: self.onReply,
      onReact: self.onReact,
      onDeleteReaction: self.onDeleteReaction
    )
  }
}
