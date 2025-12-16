//
//  ChatMessage.swift
//  iOSExample
//
//  Created by Om More on 17/10/25.
//
import Foundation
import SwiftData

/// Message type enum matching channel message types
enum MessageType: Int64 {
    case text = 1
    case reply = 2
    case reaction = 3
    case file = 40000 // File transfer message type
}

@Model
class ChatMessageModel: Identifiable {
    @Attribute(.unique) var id: String
    var internalId: Int64
    var message: String
    var timestamp: Date
    var isIncoming: Bool
    var isRead: Bool
    var sender: MessageSenderModel?
    var chat: ChatModel
    var replyTo: String?

    // File attachment properties
    var fileName: String?
    var fileType: String?
    var fileData: Data?
    var filePreview: Data?
    var fileLinkJSON: String?

    /// Check if this message has a file attachment
    var hasFile: Bool {
        fileName != nil && fileType != nil
    }

    /// Check if the file is an image
    var isImage: Bool {
        guard let type = fileType?.lowercased() else { return false }
        return ["jpg", "jpeg", "png", "gif", "webp", "heic"].contains(type)
    }

    init(message: String, isIncoming: Bool, chat: ChatModel, sender: MessageSenderModel? = nil, id: String, internalId: Int64, replyTo: String? = nil, timestamp: Int64 = Int64(Date().timeIntervalSince1970 * 1e+6 * 1e+3), isRead: Bool = false) {
        self.id = id
        self.internalId = internalId
        self.message = message
        self.timestamp = Date(timeIntervalSince1970: Double(timestamp) * 1e-6 * 1e-3)
        self.isIncoming = isIncoming
        self.isRead = isRead
        if sender != nil {
            self.sender = sender
        }
        self.chat = chat
        self.replyTo = replyTo
    }

    /// Create a file message
    static func fileMessage(
        fileName: String,
        fileType: String,
        fileData: Data?,
        filePreview: Data?,
        fileLinkJSON: String?,
        isIncoming: Bool,
        chat: ChatModel,
        sender: MessageSenderModel?,
        id: String,
        internalId: Int64,
        timestamp: Int64
    ) -> ChatMessageModel {
        let msg = ChatMessageModel(
            message: "📎 \(fileName)",
            isIncoming: isIncoming,
            chat: chat,
            sender: sender,
            id: id,
            internalId: internalId,
            timestamp: timestamp
        )
        msg.fileName = fileName
        msg.fileType = fileType
        msg.fileData = fileData
        msg.filePreview = filePreview
        msg.fileLinkJSON = fileLinkJSON
        return msg
    }
}
