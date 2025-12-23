//
//  DMReceiver.swift
//  iOSExample
//
//  Created by Om More on 24/09/25.
//

import Bindings
import SwiftData

class DMReceiverBuilder: NSObject, Bindings.BindingsDMReceiverBuilderProtocol {
    private var r: DMReceiver

    init(receiver: DMReceiver) {
        r = receiver
        super.init()
    }

    func build(_: String?) -> (any BindingsDMReceiverProtocol)? {
        return r
    }
}

// DMReceiver's are callbacks for message processing. These include
// message reception and retrieval of specific data to process a message.
// DmCallbacks are events that signify the UI should be updated
// for full details see the docstrings or the "bindings" folder
// inside the core codebase.
// We implement them both inside the same object for convenience of passing updates to the UI.
// Your implementation may vary based on your needs.

struct ReceivedMessage: Identifiable {
    var Msg: String
    var id = UUID()
}

class DMReceiver: NSObject, ObservableObject, Bindings.BindingsDMReceiverProtocol, Bindings.BindingsDmCallbacksProtocol {
    var modelActor: SwiftDataActor?
    func eventUpdate(_: Int64, jsonData _: Data?) {}

    func deleteMessage(_: Data?, senderPubKey _: Data?) -> Bool {
        return true
    }

    func getConversation(_: Data?) -> Data? {
        return "".data
    }

    func getConversations() -> Data? {
        return "[]".data
    }

    func receive(_ messageID: Data?, nickname _: String?, text: Data?, partnerKey: Data?, senderKey: Data?, dmToken: Int32, codeset: Int, timestamp _: Int64, roundId _: Int64, mType _: Int64, status _: Int64) -> Int64 {
        // Ensure UI updates happen on main thread

        guard let messageID else { fatalError("no msg id") }
        guard let text else { fatalError("no text") }
        guard let decodedMessage = decodeMessage(text.base64EncodedString()) else { fatalError("decode failed") }

        // Get codename using same approach as EventModelBuilder
        var err: NSError?
        let identityData = Bindings.BindingsConstructIdentity(partnerKey, codeset, &err)
        let codename: String
        let color: Int
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

        let internalId = InternalIdGenerator.shared.next()
        persistIncoming(message: decodedMessage, codename: codename, partnerKey: partnerKey, senderKey: senderKey, dmToken: dmToken, messageId: messageID, color: color, internalId: internalId)
        // Note: this should be a UUID in your database so
        // you can uniquely identify the message.
        return internalId
    }

    func receiveReaction(_: Data?, reactionTo _: Data?, nickname _: String?, reaction _: String?, partnerKey _: Data?, senderKey _: Data?, dmToken _: Int32, codeset _: Int, timestamp _: Int64, roundId _: Int64, status _: Int64) -> Int64 {
        // Note: this should be a UUID in your database so
        // you can uniquely identify the message.
        return InternalIdGenerator.shared.next()
    }

    func receiveReply(_ messageID: Data?, reactionTo _: Data?, nickname _: String?, text: String?, partnerKey: Data?, senderKey: Data?, dmToken: Int32, codeset: Int, timestamp _: Int64, roundId _: Int64, status _: Int64) -> Int64 {
        guard let messageID else { fatalError("no msg id") }

        // Get codename using same approach as EventModelBuilder
        var err: NSError?
        let identityData = Bindings.BindingsConstructIdentity(partnerKey, codeset, &err)
        let codename: String
        let color: Int
        do {
            let identity = try Parser.decodeIdentity(from: identityData!)
            codename = identity.codename
            var _color: String = identity.color
            if _color.hasPrefix("0x") || _color.hasPrefix("0X") {
                _color.removeFirst(2)
            }
            color = Int(_color, radix: 16)!
        } catch {
            // TODO:
            fatalError("\(error)")
        }

        let internalId = InternalIdGenerator.shared.next()
        persistIncoming(message: text ?? "empty text", codename: codename, partnerKey: partnerKey, senderKey: senderKey, dmToken: dmToken, messageId: messageID, color: color, internalId: internalId)
        return internalId
    }

    func receiveText(_ messageID: Data?, nickname _: String?, text: String?, partnerKey: Data?, senderKey: Data?, dmToken: Int32, codeset: Int, timestamp _: Int64, roundId _: Int64, status _: Int64) -> Int64 {
        guard let messageID else { fatalError("no msg id") }

        // Get codename using same approach as EventModelBuilder
        var err: NSError?
        let identityData = Bindings.BindingsConstructIdentity(partnerKey, codeset, &err)
        let codename: String
        let color: Int
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

        let internalId = InternalIdGenerator.shared.next()
        persistIncoming(message: text ?? "empty text", codename: codename, partnerKey: partnerKey, senderKey: senderKey, dmToken: dmToken, messageId: messageID, color: color, internalId: internalId)
        return internalId
    }

    func updateSentStatus(_: Int64, messageID _: Data?, timestamp _: Int64, roundID _: Int64, status _: Int64) {}

    private func persistIncoming(message: String, codename: String?, partnerKey: Data?, senderKey: Data?, dmToken: Int32, messageId: Data, color: Int, internalId: Int64) {
        guard let backgroundContext = modelActor else { return }
        guard let partnerKey else { fatalError("partner key is not available") }
        let name = (codename?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "Unknown"

        Task { @MainActor in
            do {
                let chat = try fetchOrCreateDMChat(codename: name, ctx: backgroundContext, pubKey: partnerKey, dmToken: dmToken, color: color)

                // Create or update Sender object
                let senderId = partnerKey.base64EncodedString()
                let senderDescriptor = FetchDescriptor<MessageSenderModel>(
                    predicate: #Predicate { $0.id == senderId }
                )
                let sender: MessageSenderModel
                if let existingSender = try? backgroundContext.fetch(senderDescriptor).first {
                    // Update existing sender's dmToken
                    existingSender.dmToken = dmToken
                    sender = existingSender
                } else {
                    // Create new sender
                    sender = MessageSenderModel(id: senderId, pubkey: partnerKey, codename: name, dmToken: dmToken, color: color)
                }

                // Check if sender's pubkey matches the pubkey of chat with id "<self>"
                let isIncoming = !isSenderSelf(chat: chat, senderPubKey: senderKey, ctx: backgroundContext)
                let msg = ChatMessageModel(message: message, isIncoming: isIncoming, chat: chat, sender: sender, id: messageId.base64EncodedString(), internalId: internalId)
                chat.messages.append(msg)
                // Increment unread count for incoming messages after join time
                if isIncoming && msg.timestamp > chat.joinedAt {
                    chat.unreadCount += 1
                }
                try backgroundContext.save()
            } catch {}
        }
    }

    private func fetchOrCreateDMChat(codename: String, ctx: SwiftDataActor, pubKey: Data?, dmToken: Int32?, color: Int) throws -> ChatModel {
        if let pubKey {
            let pubKeyB64 = pubKey.base64EncodedString()
            let byKey = FetchDescriptor<ChatModel>(predicate: #Predicate { $0.id == pubKeyB64 })
            if let existingByKey = try ctx.fetch(byKey).first {
                return existingByKey
            } else {
                guard let dmToken else { throw MyError.runtimeError("dmToken is required to create chat with pubKey") }
                let newChat = ChatModel(pubKey: pubKey, name: codename, dmToken: dmToken, color: color)
                ctx.insert(newChat)
                try ctx.save()
                return newChat
            }
        } else {
            // Fallback to codename-based lookup (may collide)
            let byName = FetchDescriptor<ChatModel>(predicate: #Predicate { $0.name == codename })
            if let existingByName = try ctx.fetch(byName).first {
                return existingByName
            } else {
                throw MyError.runtimeError("pubkey is required to create chat")
            }
        }
    }

    private func isSenderSelf(chat _: ChatModel, senderPubKey: Data?, ctx: SwiftDataActor) -> Bool {
        // Check if there's a chat with id "<self>" and compare its pubkey with sender's pubkey
        let selfChatDescriptor = FetchDescriptor<ChatModel>(predicate: #Predicate { $0.name == "<self>" })
        if let selfChat = try? ctx.fetch(selfChatDescriptor).first {
            guard let senderPubKey = senderPubKey else { return false }
            return Data(base64Encoded: selfChat.id) == senderPubKey
        }

        return false
    }
}
