//
//  ChatModel.swift
//  iOSExample
//
//  Created by Om More on 24/09/25.
//

import Foundation
import SQLiteData

// ChatModel is a single storage model for all conversation types: channel chat, DM chat, and self/notes chat.
// init takes care of setting correct values
@Table("chats")
public struct ChatModel: Identifiable, Hashable, Sendable {
  // this is transformed into readable name like Notes for user
  private static let selfChatInternalName = "ChatModel.selfChatInternalName"
  /// Internal unique chat id
  public var id: UUID = .init()
  public var name: String

  public var joinedAt: Date = .init()
  public var unreadCount: Int = 0

  // Channel only
  public var channelId: String?
  public var channelDescription: String?
  public var isSecret: Bool = false
  public var isAdmin: Bool = false
  public var color: Int = 0xE97451 // burnt sienna
  //

  // DM only
  public var pubKey: Data?
  public var dmToken: Int32?
  //

  public var isChannel: Bool {
    self.name != Self.selfChatInternalName && self.dmToken == nil
  }
}

public extension ChatModel {
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
public struct ChannelMutedUserModel: Identifiable, Hashable {
  public var id: UUID = .init()
  public var channelId: String
  public var pubkey: Data

  public init(channelId: String, pubkey: Data) {
    self.channelId = channelId
    self.pubkey = pubkey
  }
}
