//
//  SelectedChat.swift
//  iOSExample
//
//  Holds selected chat info for split view detail column
//

import Foundation

final class SelectedChat: ObservableObject {
  @Published var chatId: UUID?

  func select(id: UUID) {
    self.chatId = id
  }

  func clear() {
    self.chatId = nil
  }
}
