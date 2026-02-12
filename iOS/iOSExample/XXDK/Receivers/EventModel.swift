import Bindings
import Dispatch
import Foundation
import SwiftData

extension Notification.Name {
    static let userMuteStatusChanged = Notification.Name("userMuteStatusChanged")
    static let fileLinkReceived = Notification.Name("fileLinkReceived")
    static let fileDownloadNeeded = Notification.Name("fileDownloadNeeded")
    static let fileDataUpdated = Notification.Name("fileDataUpdated")
}

final class EventModelBuilder: NSObject, BindingsEventModelBuilderProtocol {
    private var r: EventModel

    var modelActor: SwiftDataActor?

    // Allow late injection from the app so the EventModel can persist messages
    func configure(modelActor: SwiftDataActor) {
        self.modelActor = modelActor
        // Propagate immediately to the underlying model if already created
        r.configure(modelActor: modelActor)
    }

    init(model: EventModel) {
        r = model
        super.init()
    }

    func build(_: String?) -> (any BindingsEventModelProtocol)? {
        // If a modelActor has been configured on the builder, ensure the model gets it
        if let actor = modelActor, r.modelActor == nil {
            r.configure(modelActor: actor)
        }
        return r
    }
}

final class EventModel: NSObject, BindingsEventModelProtocol {
    // Optional SwiftData container for persisting chats/messages

    var modelActor: SwiftDataActor?

    // Cache for file data received via receiveFile (fileID -> fileData)
    private var fileDataCache: [String: Data] = [:]
    private let fileDataLock = NSLock()

    // Allow late injection of the model container without changing initializer signature
    func configure(modelActor: SwiftDataActor) {
        self.modelActor = modelActor
    }

    // Store file data in cache
    private func cacheFileData(fileID: String, data: Data) {
        fileDataLock.lock()
        fileDataCache[fileID] = data
        fileDataLock.unlock()
    }

    // Retrieve and remove file data from cache
    private func retrieveFileData(fileID: String) -> Data? {
        fileDataLock.lock()
        let data = fileDataCache[fileID]
        fileDataLock.unlock()
        return data
    }

    // MARK: - Helper Methods

    func update(
        fromMessageID _: Data?,
        messageUpdateInfoJSON _: Data?,
        ret0_ _: UnsafeMutablePointer<Int64>?
    ) throws {}

    func update(fromUUID uuid: Int64, messageUpdateInfoJSON: Data?) throws {
        guard let jsonData = messageUpdateInfoJSON else {
            return
        }

        let updateInfo = try Parser.decodeMessageUpdateInfo(from: jsonData)

        guard updateInfo.messageIDSet, let newMessageId = updateInfo.messageID else {
            return
        }

        guard let actor = modelActor else {
            return
        }

        let descriptor = FetchDescriptor<ChatMessageModel>(
            predicate: #Predicate { $0.internalId == uuid }
        )

        if let message = try actor.fetch(descriptor).first {
            message.id = newMessageId
            try actor.save()
        }
    }

    private func short(_ data: Data?) -> String {
        guard let d = data else { return "nil" }
        let b64 = d.base64EncodedString()
        return b64.count > 16 ? String(b64.prefix(16)) + "…" : b64
    }

    // Fetch existing Chat by channelId or create a new one
    private func fetchOrCreateChannelChat(
        channelId: String,
        channelName: String
    ) throws -> ChatModel {
        guard let actor = modelActor else {
            throw EventModelError.modelActorNotAvailable
        }
        let descriptor = FetchDescriptor<ChatModel>(
            predicate: #Predicate { $0.id == channelId }
        )
        if let existing = try actor.fetch(descriptor).first {
            return existing
        }
        let newChat = ChatModel(channelId: channelId, name: channelName)
        actor.insert(newChat)
        try actor.save()
        return newChat
    }

    // Persist a message into SwiftData if modelActor is set
    private func persistIncomingMessageIfPossible(
        channelId: String,
        channelName: String,
        text: String,
        senderCodename: String?,
        senderPubKey: Data?,
        messageIdB64: String? = nil,
        replyTo: String? = nil,
        timestamp: Int64,
        dmToken: Int32? = nil,
        color: Int,
        nickname: String? = nil
    ) -> Int64 {
        do {
            guard let actor = modelActor else {
                fatalError("no modelActor")
            }
            let chat = try fetchOrCreateChannelChat(
                channelId: channelId,
                channelName: channelName
            )

            guard let mid = messageIdB64, !mid.isEmpty else {
                fatalError("no message id")
            }

            let msg = try ReceiverHelpers.persistIncomingMessage(
                ctx: actor,
                chat: chat,
                text: text,
                messageId: mid,
                senderPubKey: senderPubKey,
                senderCodename: senderCodename,
                nickname: nickname,
                dmToken: dmToken ?? 0,
                color: color,
                replyTo: replyTo,
                timestamp: timestamp
            )

            return msg.internalId
        } catch {
            AppLogger.storage.critical("persist msg error: \(error.localizedDescription, privacy: .public)")
            fatalError(
                error.localizedDescription
            )
        }
    }

    func joinChannel(_: String?) {}

    func leaveChannel(_: Data?) {}

    func receiveMessage(
        _ channelID: Data?,
        messageID: Data?,
        nickname: String?,
        text: String?,
        pubKey: Data?,
        dmToken: Int32,
        codeset: Int,
        timestamp: Int64,
        lease _: Int64,
        roundID _: Int64,
        messageType: Int64,
        status _: Int64,
        hidden _: Bool
    ) -> Int64 {
        let messageIdB64 = messageID?.base64EncodedString()
        let messageTextB64 = text ?? ""

        // Check if this is a file message (type 40000)
        if messageType == 40000 {
            return handleFileMessage(
                channelID: channelID,
                messageID: messageID,
                text: text,
                pubKey: pubKey,
                dmToken: dmToken,
                codeset: codeset,
                timestamp: timestamp
            )
        }

        do {
            let (codename, color) = try ReceiverHelpers.parseIdentity(pubKey: pubKey, codeset: codeset)
            let channelIdB64 = channelID?.base64EncodedString() ?? "unknown"
            if let decodedText = decodeMessage(messageTextB64) {
                return persistIncomingMessageIfPossible(
                    channelId: channelIdB64,
                    channelName: "Channel \(String(channelIdB64.prefix(8)))",
                    text: decodedText,
                    senderCodename: codename,
                    senderPubKey: pubKey,
                    messageIdB64: messageIdB64,
                    timestamp: timestamp,
                    dmToken: dmToken,
                    color: color,
                    nickname: nickname
                )
            }
            return 0
        } catch {
            fatalError("something went wrong \(error)")
        }
    }

    func receiveReaction(
        _: Data?,
        messageID: Data?,
        reactionTo: Data?,
        nickname: String?,
        reaction: String?,
        pubKey: Data?,
        dmToken: Int32,
        codeset: Int,
        timestamp _: Int64,
        lease _: Int64,
        roundID _: Int64,
        messageType _: Int64,
        status _: Int64,
        hidden _: Bool
    ) -> Int64 {
        let reactionText = reaction ?? ""
        let targetMessageIdB64 = reactionTo?.base64EncodedString()

        guard let targetId = targetMessageIdB64, !targetId.isEmpty else {
            fatalError("no target id")
        }
        guard !reactionText.isEmpty else {
            fatalError("no reaction")
        }

        do {
            guard let actor = modelActor else {
                fatalError("no modelActor")
            }

            let (codename, color) = try ReceiverHelpers.parseIdentity(pubKey: pubKey, codeset: codeset)

            var sender: MessageSenderModel? = nil
            if let pubKey = pubKey {
                sender = try ReceiverHelpers.upsertSender(
                    ctx: actor,
                    pubKey: pubKey,
                    codename: codename,
                    nickname: nickname,
                    dmToken: dmToken,
                    color: color
                )
            }

            let internalId = InternalIdGenerator.shared.next()
            let record = MessageReactionModel(
                id: messageID!.base64EncodedString(),
                internalId: internalId,
                targetMessageId: targetId,
                emoji: reactionText,
                sender: sender
            )
            actor.insert(record)
            try actor.save()
            return record.internalId
        } catch {
            fatalError(
                "failed to store message reaction \(error.localizedDescription)"
            )
        }
    }

    func deleteReaction(messageId: String, emoji: String) {
        do {
            guard let actor = modelActor else {
                return
            }
            let descriptor = FetchDescriptor<MessageReactionModel>(
                predicate: #Predicate {
                    $0.id == messageId && $0.emoji == emoji
                }
            )
            let reactions = try actor.fetch(descriptor)

            for reaction in reactions {
                actor.delete(reaction)
            }

            try actor.save()
        } catch {
            AppLogger.storage.error("EventModel: Failed to delete reaction: \(error.localizedDescription, privacy: .public)")
        }
    }

    func receiveReply(
        _ channelID: Data?,
        messageID: Data?,
        reactionTo: Data?,
        nickname: String?,
        text: String?,
        pubKey: Data?,
        dmToken: Int32,
        codeset: Int,
        timestamp: Int64,
        lease _: Int64,
        roundID _: Int64,
        messageType _: Int64,
        status _: Int64,
        hidden _: Bool
    ) -> Int64 {
        let messageIdB64 = messageID?.base64EncodedString()
        let replyTextB64 = text ?? ""

        let nick: String
        let color: Int
        do {
            (nick, color) = try ReceiverHelpers.parseIdentity(pubKey: pubKey, codeset: codeset)
        } catch {
            fatalError("\(error)")
        }
        let channelIdB64 = channelID?.base64EncodedString() ?? "unknown"
        guard let reactionTo else {
            fatalError("reactionTo is missing")
        }
        if let decodedReply = decodeMessage(replyTextB64) {
            return persistIncomingMessageIfPossible(
                channelId: channelIdB64,
                channelName: "Channel \(String(channelIdB64.prefix(8)))",
                text: decodedReply,
                senderCodename: nick,
                senderPubKey: pubKey,
                messageIdB64: messageIdB64,
                replyTo: reactionTo.base64EncodedString(),
                timestamp: timestamp,
                dmToken: dmToken, color: color,
                nickname: nickname
            )
        }
        return 0
    }

    func updateFromMessageID(
        _: Data?,
        messageUpdateInfoJSON _: Data?,
        ret0_ _: UnsafeMutablePointer<Int64>?
    ) throws -> Bool {
        return true
    }

    func updateFromUUID(_ uuid: Int64, messageUpdateInfoJSON: Data?) throws
        -> Bool
    {
        guard let jsonData = messageUpdateInfoJSON else {
            return false
        }

        let updateInfo = try Parser.decodeMessageUpdateInfo(from: jsonData)

        guard updateInfo.messageIDSet, let newMessageId = updateInfo.messageID else {
            return false
        }

        guard let actor = modelActor else {
            return false
        }

        let descriptor = FetchDescriptor<ChatMessageModel>(
            predicate: #Predicate { $0.internalId == uuid }
        )

        if let message = try actor.fetch(descriptor).first {
            message.id = newMessageId
            try actor.save()
            return true
        }

        return false
    }

    func getMessage(_ messageID: Data?) throws -> Data {
        guard let messageID = messageID else {
            throw EventModelError.messageNotFound
        }

        let messageIdB64 = messageID.base64EncodedString()

        guard let actor = modelActor else {
            throw EventModelError.modelActorNotAvailable
        }

        // Check ChatMessage
        let msgDescriptor = FetchDescriptor<ChatMessageModel>(
            predicate: #Predicate { $0.id == messageIdB64 }
        )
        if let msg = try? actor.fetch(msgDescriptor).first {
            let pubKeyData = msg.sender?.pubkey ?? Data()
            let modelMsg = ModelMessageJSON(
                pubKey: pubKeyData,
                messageID: messageID
            )
            return try Parser.encodeModelMessage(modelMsg)
        }

        // Check MessageReaction - if message not found, check if it's a reaction
        let reactionDescriptor = FetchDescriptor<MessageReactionModel>(
            predicate: #Predicate { $0.id == messageIdB64 }
        )
        if let reaction = try? actor.fetch(reactionDescriptor).first {
            let pubKeyData = reaction.sender?.pubkey ?? Data()
            let modelMsg = ModelMessageJSON(
                pubKey: pubKeyData,
                messageID: messageID
            )
            return try Parser.encodeModelMessage(modelMsg)
        }
        // Not found
        throw EventModelError.messageNotFound
    }

    func deleteMessage(_ messageID: Data?) throws {
        guard let messageID = messageID else {
            fatalError("message id is nil")
        }

        let messageIdB64 = messageID.base64EncodedString()

        guard let actor = modelActor else {
            fatalError("deleteMessage: no modelActor available")
        }

        do {
            // First, try to find and delete a ChatMessage
            let messageDescriptor = FetchDescriptor<ChatMessageModel>(
                predicate: #Predicate { $0.id == messageIdB64 }
            )
            let messages = try actor.fetch(messageDescriptor)

            if !messages.isEmpty {
                for message in messages {
                    actor.delete(message)
                }
                try actor.save()
                return
            }

            // If no message found, check for reactions
            let reactionDescriptor = FetchDescriptor<MessageReactionModel>(
                predicate: #Predicate { $0.id == messageIdB64 }
            )
            let reactions = try actor.fetch(reactionDescriptor)

            if !reactions.isEmpty {
                for reaction in reactions {
                    actor.delete(reaction)
                }
                try actor.save()
                return
            }

        } catch {
            AppLogger.storage.error("EventModel: Failed to delete message/reaction: \(error.localizedDescription, privacy: .public)")
        }
    }

    func muteUser(_ channelID: Data?, pubkey _: Data?, unmute _: Bool) {
        // Post notification for UI to refresh mute status
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .userMuteStatusChanged,
                object: nil,
                userInfo: ["channelID": channelID?.base64EncodedString() ?? ""]
            )
        }
    }

    func deleteFile(_: Data?) throws {}

    func getFile(_: Data?) throws -> Data {
        // TODO: Look up file in storage by fileID and return its data
        // For now, return the standard "no message" error that Go code recognizes
        throw EventModelError.messageNotFound
    }

    func receiveFile(
        _ fileID: Data?,
        fileLink: Data?,
        fileData: Data?,
        timestamp _: Int64,
        status: Int
    ) throws {
        // Cache file data for later use when file message arrives
        if let fileID = fileID, let fileData = fileData, !fileData.isEmpty {
            let fileIdStr = fileID.base64EncodedString()
            cacheFileData(fileID: fileIdStr, data: fileData)
        }

        // Post notification with file link for pending uploads
        if let fileID = fileID, let fileLink = fileLink {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .fileLinkReceived,
                    object: nil,
                    userInfo: [
                        "fileID": fileID,
                        "fileLink": fileLink,
                        "status": status,
                    ]
                )
            }
        }
    }

    func updateFile(
        _ fileID: Data?,
        fileLink: Data?,
        fileData: Data?,
        timestamp _: Int64,
        status: Int
    ) throws {
        // Cache file data for later use when file message arrives
        if let fileID = fileID, let fileData = fileData, !fileData.isEmpty {
            let fileIdStr = fileID.base64EncodedString()
            cacheFileData(fileID: fileIdStr, data: fileData)

            // Update existing ChatMessage with file data (for downloads)
            updateMessageWithFileData(fileID: fileIdStr, fileData: fileData)
        }

        // Post notification with file link for pending uploads
        if let fileID = fileID, let fileLink = fileLink {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .fileLinkReceived,
                    object: nil,
                    userInfo: [
                        "fileID": fileID,
                        "fileLink": fileLink,
                        "status": status,
                    ]
                )
            }
        }
    }

    private func updateMessageWithFileData(fileID: String, fileData: Data) {
        guard let actor = modelActor else {
            return
        }

        Task {
            do {
                // Find ALL messages with matching fileID in fileLinkJSON
                let allMessages = try actor.fetch(FetchDescriptor<ChatMessageModel>())
                var updatedCount = 0
                for message in allMessages {
                    if let linkJSON = message.fileLinkJSON,
                       linkJSON.contains(fileID),
                       message.fileData == nil
                    {
                        message.fileData = fileData
                        updatedCount += 1
                    }
                }

                if updatedCount > 0 {
                    try actor.save()

                    // Notify UI to refresh
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .fileDataUpdated, object: nil)
                    }
                }
            } catch {
                // Error updating message with file data
            }
        }
    }

    private func handleFileMessage(
        channelID: Data?,
        messageID: Data?,
        text: String?,
        pubKey: Data?,
        dmToken: Int32,
        codeset: Int,
        timestamp: Int64
    ) -> Int64 {
        guard let actor = modelActor else {
            return 0
        }

        guard let text = text, !text.isEmpty else {
            return 0
        }

        // Try to decode - might be base64 encoded or raw JSON
        var textData: Data
        if let decoded = Data(base64Encoded: text) {
            textData = decoded
        } else if let utf8Data = text.data(using: .utf8) {
            textData = utf8Data
        } else {
            return 0
        }

        do {
            let fileInfo = try Parser.decodeFileInfo(from: textData)
            let (codename, color) = try ReceiverHelpers.parseIdentity(pubKey: pubKey, codeset: codeset)
            let channelIdB64 = channelID?.base64EncodedString() ?? "unknown"
            let messageIdB64 = messageID?.base64EncodedString() ?? ""

            // Get or create chat
            let chat = try fetchOrCreateChannelChat(
                channelId: channelIdB64,
                channelName: "Channel \(String(channelIdB64.prefix(8)))"
            )

            // Get or create sender
            var sender: MessageSenderModel? = nil
            if let pubKey = pubKey {
                sender = try ReceiverHelpers.upsertSender(
                    ctx: actor,
                    pubKey: pubKey,
                    codename: codename,
                    nickname: nil,
                    dmToken: dmToken,
                    color: color
                )
            }

            // Create file message
            let isIncoming = !ReceiverHelpers.isSenderSelf(senderPubKey: pubKey, ctx: actor)
            let internalId = InternalIdGenerator.shared.next()

            // Try to get cached file data
            let cachedFileData = retrieveFileData(fileID: fileInfo.fileID)

            let fileMessage = ChatMessageModel.fileMessage(
                fileName: fileInfo.name,
                fileType: fileInfo.type,
                fileData: cachedFileData,
                filePreview: fileInfo.preview,
                fileLinkJSON: text,
                isIncoming: isIncoming,
                chat: chat,
                sender: sender,
                id: messageIdB64,
                internalId: internalId,
                timestamp: timestamp
            )
            let precomputedRender = NewMessageHTMLPrecomputer.precompute(rawHTML: fileMessage.message)
            NewMessageRenderPersistence.apply(precomputedRender, to: fileMessage)

            actor.insert(fileMessage)
            chat.messages.append(fileMessage)

            if isIncoming && timestamp > Int64(chat.joinedAt.timeIntervalSince1970 * 1e9) {
                chat.unreadCount += 1
            }

            try actor.save()

            // Trigger download for incoming files without cached data
            if isIncoming && cachedFileData == nil {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .fileDownloadNeeded,
                        object: nil,
                        userInfo: [
                            "fileInfoJSON": textData,
                            "messageId": messageIdB64,
                        ]
                    )
                }
            }

            return internalId
        } catch {
            return 0
        }
    }
}
