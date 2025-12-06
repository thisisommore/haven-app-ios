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
        self.r = receiver
        super.init()
    }
    
    func build(_ path: String?) -> (any BindingsDMReceiverProtocol)? {
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
    // Optional SwiftData container injected from SwiftUI
//    public var modelContainer: ModelContainer?
    public var modelActor: SwiftDataActor?
    private var msgCnt: Int64 = 0
    func eventUpdate(_ eventType: Int64, jsonData: Data?) {
        print("[DMReceiver] eventUpdate called with eventType: \(eventType), jsonData: \(jsonData?.count ?? 0) bytes")
    }
        
    func deleteMessage(_ messageID: Data?, senderPubKey: Data?) -> Bool {
        print("[DMReceiver] deleteMessage called with messageID: \(messageID?.count ?? 0) bytes, senderPubKey: \(senderPubKey?.count ?? 0) bytes")
        return true
    }
    
    func getConversation(_ senderPubKey: Data?) -> Data? {
        print("[DMReceiver] getConversation called with senderPubKey: \(senderPubKey?.count ?? 0) bytes")
        return "".data
    }
    
    func getConversations() -> Data? {
        print("[DMReceiver] getConversations called")
        return "[]".data
    }
    
    func receive(_ messageID: Data?, nickname: String?, text: Data?, partnerKey: Data?, senderKey: Data?, dmToken: Int32, codeset: Int, timestamp: Int64, roundId: Int64, mType: Int64, status: Int64) -> Int64 {
        print("[DMReceiver] receive called with nickname: \(nickname ?? "nil"), text: \(text?.count ?? 0) bytes, dmToken: \(dmToken), timestamp: \(timestamp), roundId: \(roundId)")
        // Ensure UI updates happen on main thread

        guard let messageID else { fatalError("no msg id") }
        guard let text else { fatalError("no text") }
        guard let decodedMessage = decodeMessage(text.base64EncodedString())  else { fatalError("decode failed") }

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
        
 

        persistIncoming(message: decodedMessage, codename: codename, partnerKey: partnerKey, senderKey: senderKey, dmToken: dmToken, messageId: messageID, color: color)
        // Note: this should be a UUID in your database so
        // you can uniquely identify the message.
        msgCnt += 1;
        return msgCnt;
    }
    
    func receiveReaction(_ messageID: Data?, reactionTo: Data?, nickname: String?, reaction: String?, partnerKey: Data?, senderKey: Data?, dmToken: Int32, codeset: Int, timestamp: Int64, roundId: Int64, status: Int64) -> Int64 {
        print("[DMReceiver] receiveReaction called with nickname: \(nickname ?? "nil"), reaction: \(reaction ?? "nil"), dmToken: \(dmToken), timestamp: \(timestamp)")
        // Note: this should be a UUID in your database so
        // you can uniquely identify the message.
        msgCnt += 1;
        return msgCnt;
    }
    
    func receiveReply(_ messageID: Data?, reactionTo: Data?, nickname: String?, text: String?, partnerKey: Data?, senderKey: Data?, dmToken: Int32, codeset: Int, timestamp: Int64, roundId: Int64, status: Int64) -> Int64 {
        print("[DMReceiver] receiveReply called with nickname: \(nickname ?? "nil"), text: \(text ?? "nil"), dmToken: \(dmToken), timestamp: \(timestamp)")
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
            //TODO
            fatalError("\(error)")
        }

        persistIncoming(message: text ?? "empty text", codename: codename, partnerKey: partnerKey, senderKey: senderKey, dmToken: dmToken, messageId: messageID, color: color)
        msgCnt += 1;
        return msgCnt;
    }
    
    func receiveText(_ messageID: Data?, nickname: String?, text: String?, partnerKey: Data?, senderKey: Data?, dmToken: Int32, codeset: Int, timestamp: Int64, roundId: Int64, status: Int64) -> Int64 {
        print("[DMReceiver] receiveText called with nickname: \(nickname ?? "nil"), text: \(text ?? "nil"), dmToken: \(dmToken), timestamp: \(timestamp)")
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

        persistIncoming(message: text ?? "empty text", codename: codename, partnerKey: partnerKey, senderKey: senderKey, dmToken: dmToken, messageId: messageID, color: color)
        msgCnt += 1;
        return msgCnt;
    }
    
    func updateSentStatus(_ uuid: Int64, messageID: Data?, timestamp: Int64, roundID: Int64, status: Int64) {
        print("[DMReceiver] updateSentStatus called with uuid: \(uuid), messageID: \(messageID?.count ?? 0) bytes, timestamp: \(timestamp), roundID: \(roundID), status: \(status)")
    }
    
    // MARK: - Persistence Helpers
    private func persistIncomingIfPossible(message: String, codename: String?, messageId: Data, ctx: SwiftDataActor? = nil, color: Int) {
        let contextToUse = ctx ?? modelActor
        guard let contextToUse else { return }

        let name = (codename?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "Unknown"
        Task { @MainActor in
            do {
                let chat = try fetchOrCreateDMChat(codename: name, ctx: contextToUse, pubKey: nil, dmToken: nil, color: color)

                // Check if sender's pubkey matches the pubkey of chat with id "<self>"
                let isIncoming = !isSenderSelf(chat: chat, senderPubKey: nil, ctx: contextToUse)
                let internalId = InternalIdGenerator.shared.next()
                let msg = ChatMessage(message: message, isIncoming: isIncoming, chat: chat, id: messageId.base64EncodedString(), internalId: internalId)
                chat.messages.append(msg)
                try contextToUse.save()
                print("DMReceiver: ChatMessage(message: \"\(message)\", isIncoming: \(isIncoming), chat: \(chat.id), id: \(messageId.base64EncodedString()))")
            } catch {
                print("DMReceiver: Failed to save incoming message for \(name): \(error)")
            }
        }
    }

    private func persistIncoming(message: String, codename: String?, partnerKey: Data?, senderKey: Data?, dmToken: Int32, messageId: Data, color: Int) {
        guard let backgroundContext = modelActor else { return }
        let name = (codename?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "Unknown"

        Task { @MainActor in
            do {
                if let partnerKey {
                    let chat = try fetchOrCreateDMChat(codename: name, ctx: backgroundContext, pubKey: partnerKey, dmToken: dmToken, color: color)
                    print("DMReceiver: ChatMessage(message: \"\(message)\", isIncoming: \(chat.name != "<self>"), chat: \(chat.id), id: \(messageId.base64EncodedString()))")

                    // Create or update Sender object
                    let senderId = partnerKey.base64EncodedString()
                    let senderDescriptor = FetchDescriptor<Sender>(
                        predicate: #Predicate { $0.id == senderId }
                    )
                    let sender: Sender
                    if let existingSender = try? backgroundContext.fetch(senderDescriptor).first {
                        // Update existing sender's dmToken
                        existingSender.dmToken = dmToken
                        sender = existingSender
                    } else {
                        // Create new sender
                        sender = Sender(id: senderId, pubkey: partnerKey, codename: name, dmToken: dmToken, color: color)
                        print("DMReceiver: Created new Sender for \(name) with dmToken: \(dmToken)")
                    }

                    // Check if sender's pubkey matches the pubkey of chat with id "<self>"
                    let isIncoming = !isSenderSelf(chat: chat, senderPubKey: senderKey, ctx: backgroundContext)
                    let internalId = InternalIdGenerator.shared.next()
                    let msg = ChatMessage(message: message, isIncoming: isIncoming, chat: chat, sender: sender, id: messageId.base64EncodedString(), internalId: internalId)
                    chat.messages.append(msg)
                    try backgroundContext.save()
                } else {
                    // Fallback if no partner key available
                    persistIncomingIfPossible(message: message, codename: name, messageId: messageId, ctx: backgroundContext, color: color)
                }
            } catch {
                print("DMReceiver: Failed to save incoming message for \(name): \(error)")
            }
        }
    }

    private func fetchOrCreateDMChat(codename: String, ctx: SwiftDataActor, pubKey: Data?, dmToken: Int32?, color: Int) throws -> Chat {
        if let pubKey {
            let pubKeyB64 = pubKey.base64EncodedString()
            let byKey = FetchDescriptor<Chat>(predicate: #Predicate { $0.id == pubKeyB64 })
            if let existingByKey = try ctx.fetch(byKey).first {
                return existingByKey
            } else {
                guard let dmToken else { throw MyError.runtimeError("dmToken is required to create chat with pubKey") }
                let newChat = Chat(pubKey: pubKey, name: codename, dmToken: dmToken, color: color)
                ctx.insert(newChat)
                try ctx.save()
                return newChat
            }
        } else {
            // Fallback to codename-based lookup (may collide)
            let byName = FetchDescriptor<Chat>(predicate: #Predicate { $0.name == codename })
            if let existingByName = try ctx.fetch(byName).first {
                return existingByName
            } else {
                throw MyError.runtimeError("pubkey is required to create chat")
            }
        }
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
