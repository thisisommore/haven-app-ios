//
//  ChatModel.swift
//  iOSExample
//
//  Created by Om More on 24/09/25.
//

import Foundation
import SQLiteData

@Table("chats")
struct ChatModel: Identifiable, Hashable {
  /// Internal unique chat id
  var id: UUID = .init()
  var name: String

  var joinedAt: Date = .init()
  var unreadCount: Int = 0

  // Channel only
  var channelId: String?
  var channelDescription: String?
  var isSecret: Bool = false
  var isAdmin: Bool = false
  var color: Int = 0xE97451 // burnt sienna
  //

  // DM only
  var pubKey: Data?
  var dmToken: Int32?
  //

  var isChannel: Bool {
    self.name != "<self>" && self.dmToken == nil
  }
}

extension ChatModel {
  /// Initializer for Channels
  init(
    channelId: String, name: String, description: String? = nil, isAdmin: Bool = false,
    isSecret: Bool = false
  ) {
    self.channelId = channelId
    self.name = name
    self.channelDescription = description
    self.isAdmin = isAdmin
    self.isSecret = isSecret
  }

  /// Initializer for DM
  init(pubKey: Data, name: String, dmToken: Int32, color: Int) {
    self.pubKey = pubKey
    self.name = name
    self.dmToken = dmToken
    self.color = color
  }
}

@Table("channelMutedUsers")
struct ChannelMutedUserModel: Identifiable, Hashable {
  var id: UUID = .init()
  var channelId: String
  var pubkey: Data

  init(channelId: String, pubkey: Data) {
    self.channelId = channelId
    self.pubkey = pubkey
  }
}
