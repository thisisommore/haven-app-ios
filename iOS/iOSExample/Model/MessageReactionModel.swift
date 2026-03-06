import Foundation
import GRDB

struct MessageReactionModel: Identifiable, Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "messageReactionModel"

    var id: String
    var internalId: Int64
    var targetMessageId: String
    var emoji: String
    var timestamp: Date
    var isMe: Bool
    var senderId: String?

    init(id: String, internalId: Int64, targetMessageId: String, emoji: String, senderId: String? = nil, isMe: Bool = false) {
        self.targetMessageId = targetMessageId
        self.emoji = emoji
        timestamp = Date()
        self.isMe = isMe
        self.senderId = senderId
        self.id = id
        self.internalId = internalId
    }
}
