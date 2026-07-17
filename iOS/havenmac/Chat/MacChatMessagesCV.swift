//
//  MacChatMessagesCV.swift
//  haven
//
//  SwiftUI bridge for the AppKit message list (MacChatMessagesVC).
//

import SwiftUI

struct MacChatMessagesCV: NSViewControllerRepresentable {
  let chatId: UUID
  let controller: ChatPageController
  let onShowReactors: (ChatMessageModel) -> Void

  @EnvironmentObject private var xxdk: XXDK

  func makeNSViewController(context _: Context) -> MacChatMessagesVC {
    MacChatMessagesVC(
      chatId: self.chatId,
      pageController: self.controller,
      xxdk: self.xxdk,
      onShowReactors: self.onShowReactors
    )
  }

  func updateNSViewController(_: MacChatMessagesVC, context _: Context) {}
}
