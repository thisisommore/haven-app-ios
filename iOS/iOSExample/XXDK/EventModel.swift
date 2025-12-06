import Bindings
import Foundation
import SwiftData
import Dispatch

/// Thread-safe atomic counter for generating unique Int64 IDs
final class InternalIdGenerator {
    static let shared = InternalIdGenerator()
    private var counter: Int64
    private let lock = NSLock()
    private let key = "InternalIdGenerator.counter"
    
    private init() {
        counter = Int64(UserDefaults.standard.integer(forKey: key))
    }
    
    func next() -> Int64 {
        lock.lock()
        defer { lock.unlock() }
        counter += 1
        UserDefaults.standard.set(Int(counter), forKey: key)
        return counter
    }
}
final class EventModelBuilder: NSObject, BindingsEventModelBuilderProtocol {
    private var r: EventModel

    // Optional SwiftData container for the built EventModel
    public var modelContainer: ModelContainer?
    public var modelActor: SwiftDataActor?

    // Allow late injection from the app so the EventModel can persist messages
    public func configure(modelActor: SwiftDataActor) {
        self.modelActor = modelActor
        // Propagate immediately to the underlying model if already created
        r.configure(modelActor: modelActor)
    }

    init(model: EventModel) {
        self.r = model
        super.init()
    }

    func build(_ path: String?) -> (any BindingsEventModelProtocol)? {
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
    // Allow late injection of the model container without changing initializer signature
    public func configure(modelActor: SwiftDataActor) {
        self.modelActor = modelActor
    }

    func update(
        fromMessageID messageID: Data?,
        messageUpdateInfoJSON: Data?,
        ret0_: UnsafeMutablePointer<Int64>?
    ) throws {
        log(
            "update - messageID \(short(messageID)) | messageUpdateInfoJSON \(messageUpdateInfoJSON!.utf8)"
        )
    }

    func update(fromUUID uuid: Int64, messageUpdateInfoJSON: Data?) throws {
        log(
            "update - uuid \(uuid) | messageUpdateInfoJSON \(messageUpdateInfoJSON?.utf8 ?? "nil")"
        )

        guard let jsonData = messageUpdateInfoJSON else {
            return
        }

        let updateInfo = try Parser.decodeMessageUpdateInfo(from: jsonData)

        guard updateInfo.messageIDSet, let newMessageId = updateInfo.messageID else {
            return
        }

        guard let actor = modelActor else {
            log("update(fromUUID): no modelActor available")
            return
        }

        let descriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate { $0.internalId == uuid }
        )

        if let message = try actor.fetch(descriptor).first {
            message.id = newMessageId
            try actor.save()
            log("update(fromUUID): Updated message internalId=\(uuid) with new id=\(newMessageId)")
        } else {
            log("update(fromUUID): No message found with internalId=\(uuid)")
        }
    }

    // MARK: - Helpers
    private func log(_ message: String) {
        print("[EventModel] \(message)")
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
    ) throws -> Chat {
        guard let actor = modelActor else {
            throw NSError(domain: "EventModel", code: 500, userInfo: [NSLocalizedDescriptionKey: "modelActor not available"])
        }
        let descriptor = FetchDescriptor<Chat>(
            predicate: #Predicate { $0.id == channelId }
        )
        if let existing = try actor.fetch(descriptor).first {
            return existing
        }
        log("Chat(channelId: \(channelId), name: \(channelName))")
        let newChat = Chat(channelId: channelId, name: channelName)
        actor.insert(newChat)
        try actor.save()
        return newChat
    }

    // Persist a message into SwiftData if modelContainer is set
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
        color: Int
    ) -> Int64 {
        

        do {
            guard let actor = modelActor else {
                fatalError("no modelActor")
            }
            let chat = try fetchOrCreateChannelChat(
                channelId: channelId,
                channelName: channelName
            )

            // Create or update Sender object if we have codename and pubkey
            var sender: Sender? = nil
            if let codename = senderCodename, let pubKey = senderPubKey {
                let senderId = pubKey.base64EncodedString()

                // Check if sender already exists and update dmToken
                let senderDescriptor = FetchDescriptor<Sender>(
                    predicate: #Predicate { $0.id == senderId }
                )
                if let existingSender = try? actor.fetch(
                    senderDescriptor
                ).first {
                    log("text=\(text) sender= id=\(existingSender.id) codename=\(existingSender.codename) dmToken=\(existingSender.dmToken)")
                    // Update existing sender's dmToken
                    existingSender.dmToken = dmToken ?? 0
                    sender = existingSender
                    try modelActor?.save()
    
                } else {
                    // Create new sender
                    sender = Sender(
                        id: senderId,
                        pubkey: pubKey,
                        codename: codename,
                        dmToken: dmToken ?? 0,
                        color: color
                    )
                    actor.insert(sender!)
                    try modelActor?.save()
                    log(
                        "Created new Sender for \(codename) with dmToken: \(dmToken ?? 0)"
                    )
                }
            }
            
            
            let msg: ChatMessage
            if let mid = messageIdB64, !mid.isEmpty {
                // Check if sender's pubkey matches the pubkey of chat with id "<self>"
                let isIncoming = !isSenderSelf(chat: chat, senderPubKey: senderPubKey, ctx: actor)
                let internalId = InternalIdGenerator.shared.next()
                log(
                    "ChatMessage(message: \(text), isIncoming: \(isIncoming), chat: \(chat.name), sender: \(sender!.codename), id: \(mid), internalId: \(internalId))"
                )
                log(
                    "Sender(codename: \(sender!.codename), dmToken: \(sender!.dmToken))"
                )
                msg = ChatMessage(
                    message: text,
                    isIncoming: isIncoming,
                    chat: chat,
                    sender: sender,
                    id: mid,
                    internalId: internalId,
                    replyTo: replyTo,
                    timestamp: timestamp
                )
                
             
                    modelActor?.insert(msg)
                 
          
              
            } else {
                fatalError("no message id")
            }
            
            chat.messages.append(msg)
            try modelActor?.save()
            return msg.internalId
        } catch {
            print("persist msg error \(error)")
            fatalError(
                error.localizedDescription
            )
        }

    }



    func joinChannel(_ channel: String?) {
    }

    func leaveChannel(_ channelID: Data?) {
    }

    func receiveMessage(
        _ channelID: Data?,
        messageID: Data?,
        nickname: String?,
        text: String?,
        pubKey: Data?,
        dmToken: Int32,
        codeset: Int,
        timestamp: Int64,
        lease: Int64,
        roundID: Int64,
        messageType: Int64,
        status: Int64,
        hidden: Bool
    ) -> Int64 {
        let messageIdB64 = messageID?.base64EncodedString()
        let messageTextB64 = text ?? ""
        if let decodedText = decodeMessage(messageTextB64) {
            log(
                "[EventReceived] new | \(messageIdB64 ?? "nil") | | \(decodedText)"
            )
        }

        var err: NSError?
        let identityData = Bindings.BindingsConstructIdentity(
            pubKey,
            codeset,
            &err
        )
        do {
            let identity = try Parser.decodeIdentity(from: identityData!)
            let channelIdB64 = channelID?.base64EncodedString() ?? "unknown"
            let nick = identity.codename
            var _color: String = identity.color
            if _color.hasPrefix("0x") || _color.hasPrefix("0X") {
                _color.removeFirst(2)
                }
            if let decodedText = decodeMessage(messageTextB64) {
                // Persist into SwiftData chat if available
                return persistIncomingMessageIfPossible(
                    channelId: channelIdB64,
                    channelName: "Channel \(String(channelIdB64.prefix(8)))",
                    text: decodedText,
                    senderCodename: nick,
                    senderPubKey: pubKey,
                    messageIdB64: messageIdB64,
                    timestamp: timestamp,
                    dmToken: dmToken, color: Int(_color, radix: 16)!
                )
            }
            return 0
        } catch {
            fatalError("something went wrong \(error)")
        }

    }

    func receiveReaction(
        _ channelID: Data?,
        messageID: Data?,
        reactionTo: Data?,
        nickname: String?,
        reaction: String?,
        pubKey: Data?,
        dmToken: Int32,
        codeset: Int,
        timestamp: Int64,
        lease: Int64,
        roundID: Int64,
        messageType: Int64,
        status: Int64,
        hidden: Bool
    ) -> Int64 {
        log(
            "[EventReceived] new | \(messageID?.base64EncodedString() ?? "nil") | \(reactionTo?.base64EncodedString() ?? "nil") | \(reaction ?? "")"
        )

        let reactionText = reaction ?? ""
        let targetMessageIdB64 = reactionTo?.base64EncodedString()

        // Get codename using same approach as EventModelBuilder
        var err: NSError?
        let identityData = Bindings.BindingsConstructIdentity(pubKey, codeset, &err)
        let color: Int
        let codename: String
        do {
            let identity = try Parser.decodeIdentity(from: identityData!)
            codename = identity.codename
            var _color: String = identity.color
            if _color.hasPrefix("0x") || _color.hasPrefix("0X") {
                _color.removeFirst(2)
                }
             color = Int(_color, radix: 16)!
        } catch {
            fatalError("\(error)")
        }

        // Validate inputs

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

            // Create or update Sender object if we have codename and pubkey
            var sender: Sender? = nil
            if let pubKey = pubKey {
                let senderId = pubKey.base64EncodedString()

                // Check if sender already exists and update dmToken
                let senderDescriptor = FetchDescriptor<Sender>(
                    predicate: #Predicate { $0.id == senderId }
                )
                
               
                if let existingSender = try? actor.fetch(senderDescriptor).first {
                    // Update existing sender's dmToken
                    existingSender.dmToken = dmToken
                    sender = existingSender
           
                } else {
                    // Create new sender
                    sender = Sender(
                        id: senderId,
                        pubkey: pubKey,
                        codename: codename,
                        dmToken: dmToken, color: color
                    )
                    log(
                        "Created new Sender for \(codename) with dmToken: \(dmToken)"
                    )
                }
            }

            let internalId = InternalIdGenerator.shared.next()
            let record = MessageReaction(
                id: messageID!.base64EncodedString(),
                internalId: internalId,
                targetMessageId: targetId,
                emoji: reactionText,
                sender: sender
            )
            actor.insert(record)
            try actor.save()
            log(
                "MessageReaction(id: \(messageID!.base64EncodedString()), internalId: \(internalId), targetMessageId: \(targetId), emoji: \(reactionText), sender: \(sender))"
            )
            return record.internalId
        } catch {
            fatalError(
                "failed to store message reaction \(error.localizedDescription)"
            )
        }

    }

    func deleteReaction(messageId: String, emoji: String) {
        log("[EventReceived] delete | \(messageId) | | \(emoji)")


        do {
            guard let actor = modelActor else {
                log("deleteReaction: no modelActor available")
                return
            }
            let descriptor = FetchDescriptor<MessageReaction>(
                predicate: #Predicate {
                    $0.id == messageId && $0.emoji == emoji
                }
            )
            let reactions = try actor.fetch(descriptor)

            for reaction in reactions {
                actor.delete(reaction)
                log("Deleted reaction: \(emoji) from message \(messageId)")
            }

            try actor.save()
        } catch {
            print("EventModel: Failed to delete reaction: \(error)")
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
        lease: Int64,
        roundID: Int64,
        messageType: Int64,
        status: Int64,
        hidden: Bool
    ) -> Int64 {
        let messageIdB64 = messageID?.base64EncodedString()
        let replyTextB64 = text ?? ""
        if let decodedReply = decodeMessage(replyTextB64) {
            log(
                "[EventReceived] reply | \(messageIdB64 ?? "nil") | \(reactionTo?.base64EncodedString() ?? "nil") | \(decodedReply)"
            )
        }

        var err: NSError?
        let identityData = Bindings.BindingsConstructIdentity(
            pubKey,
            codeset,
            &err
        )
        let nick: String
        let color: Int
        do {
            let identity = try Parser.decodeIdentity(from: identityData!)
            nick = identity.codename
            var _color: String = identity.color
            if _color.hasPrefix("0x") || _color.hasPrefix("0X") {
                _color.removeFirst(2)
                }
             color = Int(_color, radix: 16)!
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
                dmToken: dmToken, color: color
            )
        }
        return 0
    }

    func updateFromMessageID(
        _ messageID: Data?,
        messageUpdateInfoJSON: Data?,
        ret0_: UnsafeMutablePointer<Int64>?
    ) throws -> Bool {
        log(
            "updateFromMessageID - messageID \(messageID?.utf8) | messageUpdateInfoJSON \(messageUpdateInfoJSON?.utf8)"
        )
        return true
    }

    func updateFromUUID(_ uuid: Int64, messageUpdateInfoJSON: Data?) throws
        -> Bool
    {
        log(
            "updateFromUUID - uuid \(uuid) | messageUpdateInfoJSON \(messageUpdateInfoJSON?.utf8 ?? "nil")"
        )

        guard let jsonData = messageUpdateInfoJSON else {
            return false
        }

        let updateInfo = try Parser.decodeMessageUpdateInfo(from: jsonData)

        guard updateInfo.messageIDSet, let newMessageId = updateInfo.messageID else {
            return false
        }

        guard let actor = modelActor else {
            log("updateFromUUID: no modelActor available")
            return false
        }

        let descriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate { $0.internalId == uuid }
        )

        if let message = try actor.fetch(descriptor).first {
            message.id = newMessageId
            try actor.save()
            log("updateFromUUID: Updated message internalId=\(uuid) with new id=\(newMessageId)")
            return true
        }

        log("updateFromUUID: No message found with internalId=\(uuid)")
        return false
    }

    func getMessage(_ messageID: Data?) throws -> Data {
        guard let messageID = messageID else {
            throw NSError(
                domain: "EventModel",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: BindingsGetNoMessageErr()]
            )
        }

        let messageIdB64 = messageID.base64EncodedString()
        log("[EventReceived] get | \(messageIdB64) | | ")

        guard let actor = modelActor else {
            throw NSError(domain: "EventModel", code: 500, userInfo: [NSLocalizedDescriptionKey: "modelActor not available"])
        }

        // Check ChatMessage
        let msgDescriptor = FetchDescriptor<ChatMessage>(
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
        let reactionDescriptor = FetchDescriptor<MessageReaction>(
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
        throw NSError(
            domain: "EventModel",
            code: 404,
            userInfo: [NSLocalizedDescriptionKey: BindingsGetNoMessageErr()]
        )
    }

    func deleteMessage(_ messageID: Data?) throws {
        guard let messageID = messageID else {
            fatalError("message id is nil")
        }

        let messageIdB64 = messageID.base64EncodedString()
        log("[EventReceived] delete | \(messageIdB64) | | ")

        guard let actor = modelActor else {
            fatalError("deleteMessage: no modelActor available")
        }

        do {
            // First, try to find and delete a ChatMessage
            let messageDescriptor = FetchDescriptor<ChatMessage>(
                predicate: #Predicate { $0.id == messageIdB64 }
            )
            let messages = try actor.fetch(messageDescriptor)

            if !messages.isEmpty {
                let chatId = messages.first?.chat.id
                for message in messages {
                    log(
                        "deleteMessage: Deleting ChatMessage with id=\(messageIdB64)"
                    )
                    actor.delete(message)
                }
                try actor.save()
                log("deleteMessage: ChatMessage deleted successfully")
                
                // Log remaining messages in the chat
                if let chatId {
                    let chatDescriptor = FetchDescriptor<Chat>(predicate: #Predicate { $0.id == chatId })
                    if let chat = try? actor.fetch(chatDescriptor).first {
                        log("deleteMessage: Remaining messages in chat '\(chat.name)':")
                        for msg in chat.messages {
                            log("  - id=\(msg.id), text=\(msg.message)")
                        }
                    }
                }
                return
            }

            // If no message found, check for reactions
            log(
                "deleteMessage: No ChatMessage found, checking for MessageReaction"
            )
            let reactionDescriptor = FetchDescriptor<MessageReaction>(
                predicate: #Predicate { $0.id == messageIdB64 }
            )
            let reactions = try actor.fetch(reactionDescriptor)

            if !reactions.isEmpty {
                for reaction in reactions {
                    log(
                        "deleteMessage: Deleting MessageReaction with messageId=\(messageIdB64), emoji=\(reaction.emoji)"
                    )
                    actor.delete(reaction)
                }
                try actor.save()
                log("deleteMessage: MessageReaction(s) deleted successfully")
                return
            }

            // Neither message nor reaction found
            log(
                "deleteMessage: Warning - No ChatMessage or MessageReaction found for id=\(messageIdB64)"
            )
            
            // Debug: Log ChatMessages for chat "Bho"
            let chatName = "Bho"
            let bhoMessagesDescriptor = FetchDescriptor<ChatMessage>(
                predicate: #Predicate { $0.chat.name == chatName }
            )
            if let bhoMessages = try? actor.fetch(bhoMessagesDescriptor) {
                log("deleteMessage: ChatMessages in '\(chatName)' (\(bhoMessages.count) total):")
                for msg in bhoMessages {
                    log("  - id=\(msg.id), text=\(msg.message.prefix(30))")
                }
            }

        } catch {
            print("EventModel: Failed to delete message/reaction: \(error)")
        }

    }

    func muteUser(_ channelID: Data?, pubkey: Data?, unmute: Bool) {
        log(
            "muteUser - channelID \(short(channelID)) | pubkey \(short(pubkey)) | unmute \(unmute)"
        )
    }

    // MARK: - Helper Methods
    private func isSenderSelf(chat: Chat, senderPubKey: Data?, ctx: SwiftDataActor) -> Bool {
        // Check if there's a chat with id "<self>" and compare its pubkey with sender's pubkey
        let selfChatDescriptor = FetchDescriptor<Chat>(predicate: #Predicate { $0.name == "<self>" })
        if let selfChat = try? ctx.fetch(selfChatDescriptor).first {
            guard let senderPubKey = senderPubKey else { return false }
            return Data(base64Encoded: selfChat.id) == senderPubKey
        }

        return false
    }
}
