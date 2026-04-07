import Foundation
import SQLiteData

public extension UUID {
  static let selfId = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
}

@Table("messageReactions")
public struct MessageReactionModel: Identifiable, Hashable, Sendable {
  public var id: Int64
  public var externalId: String
  public var targetMessageId: String
  public var emoji: String
  public var timestamp: Date = .init()
  public var senderId: UUID
  public var status: MessageStatus = .unsent
  public var isMe: Bool {
    self.senderId == UUID.selfId
  }

  public init(id: Int64, externalId: String, targetMessageId: String, emoji: String, senderId: UUID) {
    self.id = id
    self.externalId = externalId
    self.targetMessageId = targetMessageId
    self.emoji = emoji
    self.senderId = senderId
  }
}
