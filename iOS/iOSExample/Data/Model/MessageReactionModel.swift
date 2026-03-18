import Foundation
import SQLiteData

extension UUID {
  static let selfId = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
}

@Table("messageReactions")
struct MessageReactionModel: Identifiable, Hashable {
  var id: Int64
  var externalId: String
  var targetMessageId: String
  var emoji: String
  var timestamp: Date = .init()
  var senderId: UUID
  var status: MessageStatus = .unsent
  var isMe: Bool {
    self.senderId == UUID.selfId
  }
}
