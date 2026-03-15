import Foundation
import SQLiteData

@Table("messageReactions")
struct MessageReactionModel: Identifiable, Hashable {
  var id: Int64
  var externalId: String
  var targetMessageId: String
  var emoji: String
  var timestamp: Date
  var isMe: Bool = false
  var senderId: String?

  init(
    id: Int64, externalId: String, targetMessageId: String, emoji: String,
    senderId: String? = nil, isMe: Bool = false
  ) {
    self.id = id
    self.externalId = externalId
    self.targetMessageId = targetMessageId
    self.emoji = emoji
    self.timestamp = Date()
    self.isMe = isMe
    self.senderId = senderId
  }
}
