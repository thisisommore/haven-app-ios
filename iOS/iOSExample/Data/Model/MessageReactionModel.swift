import Foundation
import SQLiteData

@Table("messageReactions")
struct MessageReactionModel: Identifiable, Hashable {
    var id: String
    var internalId: Int64
    var targetMessageId: String
    var emoji: String
    var timestamp: Date
    var isMe: Bool = false
    var senderId: String?

    init(
        id: String, internalId: Int64, targetMessageId: String, emoji: String,
        senderId: String? = nil, isMe: Bool = false
    ) {
        self.id = id
        self.internalId = internalId
        self.targetMessageId = targetMessageId
        self.emoji = emoji
        timestamp = Date()
        self.isMe = isMe
        self.senderId = senderId
    }
}
