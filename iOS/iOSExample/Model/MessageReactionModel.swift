import Foundation
import SwiftData

@Model
class MessageReactionModel {
    @Attribute(.unique) var id: String
    var internalId: Int64
    var targetMessageId: String
    var emoji: String
    var timestamp: Date
    var isMe: Bool
    var sender: MessageSenderModel?

    init(id: String, internalId: Int64, targetMessageId: String, emoji: String, sender: MessageSenderModel? = nil, isMe: Bool = false) {
        self.targetMessageId = targetMessageId
        self.emoji = emoji
        timestamp = Date()
        self.isMe = isMe
        self.sender = sender
        self.id = id
        self.internalId = internalId
    }
}
