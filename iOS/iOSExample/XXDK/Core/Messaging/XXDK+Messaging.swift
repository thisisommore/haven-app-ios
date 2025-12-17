//
//  XXDK+Messaging.swift
//  iOSExample
//

import Bindings
import Foundation
import SwiftData

extension XXDK {
    // Persist a reaction to SwiftData
    func persistReaction(
        messageIdB64: String,
        emoji: String,
        targetMessageId: String,
        isMe: Bool = true
    ) {
        guard let actor = modelActor else {
            print("persistReaction: modelActor not set")
            return
        }
        Task {
            do {
                let reaction = MessageReactionModel(
                    id: messageIdB64,
                    internalId: InternalIdGenerator.shared.next(),
                    targetMessageId: targetMessageId,
                    emoji: emoji,
                    isMe: isMe
                )
                actor.insert(reaction)
                try actor.save()
            } catch {
                print("persistReaction failed: \(error)")
            }
        }
    }

    // Send a message to a channel by Channel ID (base64-encoded)
    func sendDM(msg: String, channelId: String) {
        guard let cm = channelsManager else {
            fatalError("sendDM(channel): Channels Manager not initialized")
        }
        let channelIdData =
            Data(base64Encoded: channelId) ?? channelId.data(using: .utf8)
                ?? Data()
        do {
            let reportData = try cm.sendMessage(
                channelIdData,
                message: encodeMessage("<p>\(msg)</p>"),
                validUntilMS: 0,
                cmixParamsJSON: "".data,
                pingsJSON: nil
            )
            do {
                let report = try Parser.decodeChannelSendReport(
                    from: reportData
                )
                if let mid = report.messageID {
                    print(
                        "Channel sendMessage messageID: \(msg) \(mid.base64EncodedString())"
                    )
                } else {
                    print("Channel sendMessage returned no messageID")
                }
            } catch {
                print("Failed to decode ChannelSendReport: \(error)")
            }
        } catch {
            print("sendDM(channel) failed: \(error.localizedDescription)")
        }
    }

    // Send a reply to a specific message in a channel
    func sendReply(msg: String, channelId: String, replyToMessageIdB64: String) {
        guard let cm = channelsManager else {
            fatalError("sendReply(channel): Channels Manager not initialized")
        }
        let channelIdData =
            Data(base64Encoded: channelId) ?? channelId.data(using: .utf8)
                ?? Data()
        guard let replyToMessageId = Data(base64Encoded: replyToMessageIdB64)
        else {
            print("sendReply(channel): invalid reply message id base64")
            return
        }
        do {
            let reportData = try cm.sendReply(
                channelIdData,
                message: encodeMessage("<p>\(msg)</p>"),
                messageToReactTo: replyToMessageId,
                validUntilMS: 0,
                cmixParamsJSON: "".data,
                pingsJSON: nil
            )
            do {
                let report = try Parser.decodeChannelSendReport(
                    from: reportData
                )
                if let mid = report.messageID {
                    print(
                        "Channel sendReply messageID: \(mid.base64EncodedString())"
                    )
                } else {
                    print("Channel sendReply returned no messageID")
                }
            } catch {
                print("Failed to decode ChannelSendReport (reply): \(error)")
            }
        } catch {
            print("sendReply(channel) failed: \(error.localizedDescription)")
        }
    }

    // Send a reaction to a specific message in a channel
    public func sendReaction(
        emoji: String,
        toMessageIdB64: String,
        inChannelId channelId: String
    ) {
        guard let cm = channelsManager else {
            fatalError(
                "sendReaction(channel): Channels Manager not initialized"
            )
        }
        let channelIdData =
            Data(base64Encoded: channelId) ?? channelId.data(using: .utf8)
                ?? Data()
        guard let targetMessageId = Data(base64Encoded: toMessageIdB64) else {
            print("sendReaction(channel): invalid target message id base64")
            return
        }
        do {
            let reportData = try cm.sendReaction(
                channelIdData,
                reaction: emoji,
                messageToReactTo: targetMessageId,
                validUntilMS: Bindings.BindingsValidForeverBindings,
                cmixParamsJSON: "".data
            )
            do {
                let report = try Parser.decodeChannelSendReport(
                    from: reportData
                )
                if let mid = report.messageID {
                    print(
                        "Channel sendReaction messageID: \(mid.base64EncodedString())"
                    )
                } else {
                    print("Channel sendReaction returned no messageID")
                }
                persistReaction(
                    messageIdB64: report.messageID!.base64EncodedString(),
                    emoji: emoji,
                    targetMessageId: toMessageIdB64,
                    isMe: true
                )
            } catch {
                print("Failed to decode ChannelSendReport (reaction): \(error)")
            }
        } catch {
            print("sendReaction(channel) failed: \(error.localizedDescription)")
        }
    }

    func sendDM(msg: String, toPubKey: Data, partnerToken: Int32) {
        guard let DM else {
            print("ERROR: DM not there")
            fatalError("DM not there")
        }
        do {
            let reportData = try DM.sendText(
                toPubKey,
                partnerToken: partnerToken,
                message: msg,
                leaseTimeMS: 0,
                cmixParamsJSON: "".data
            )

            do {
                let report = try Parser.decodeChannelSendReport(
                    from: reportData
                )
                if let mid = report.messageID {
                    print("DM sendText messageID: \(mid.base64EncodedString())")
                    let chatId = toPubKey.base64EncodedString()
                    let _: String = {
                        if let actor = self.modelActor {
                            let descriptor = FetchDescriptor<ChatModel>(
                                predicate: #Predicate { $0.id == chatId }
                            )
                            if let found = try? actor.fetch(descriptor).first {
                                return found.name
                            }
                        }
                        return "Direct Message"
                    }()

                } else {
                    print("DM sendText returned no messageID")
                }
            } catch {
                print("Failed to decode ChannelSendReport: \(error)")
            }
        } catch {
            print("ERROR: Unable to send: " + error.localizedDescription)
        }
    }

    // Send a reply to a specific message in a DM conversation
    func sendReply(
        msg: String,
        toPubKey: Data,
        partnerToken: Int32,
        replyToMessageIdB64: String
    ) {
        guard let DM else {
            print("ERROR: DM not there")
            fatalError("DM not there")
        }
        guard let replyToMessageId = Data(base64Encoded: replyToMessageIdB64)
        else {
            print("sendReply(DM): invalid reply message id base64")
            return
        }
        do {
            let reportData = try DM.sendReply(
                toPubKey,
                partnerToken: partnerToken,
                replyMessage: encodeMessage("<p>\(msg)</p>"),
                replyToBytes: replyToMessageId,
                leaseTimeMS: 0,
                cmixParamsJSON: "".data
            )
            do {
                let report = try Parser.decodeChannelSendReport(
                    from: reportData
                )
                if let mid = report.messageID {
                    print(
                        "DM sendReply messageID: \(mid.base64EncodedString())"
                    )
                    let chatId = toPubKey.base64EncodedString()
                    let _: String = {
                        if let actor = self.modelActor {
                            let descriptor = FetchDescriptor<ChatModel>(
                                predicate: #Predicate { $0.id == chatId }
                            )
                            if let found = try? actor.fetch(descriptor).first {
                                return found.name
                            }
                        }
                        return "Direct Message"
                    }()

                } else {
                    print("DM sendReply returned no messageID")
                }
            } catch {
                print("Failed to decode ChannelSendReport (DM reply): \(error)")
            }
        } catch {
            print("ERROR: Unable to send reply: " + error.localizedDescription)
            fatalError("Unable to send reply: " + error.localizedDescription)
        }
    }

    // Send a reaction to a specific message in a DM conversation
    public func sendReaction(
        emoji: String,
        toMessageIdB64: String,
        toPubKey: Data,
        partnerToken: Int32
    ) {
        guard let DM else {
            print("ERROR: DM not there")
            fatalError("DM not there")
        }
        guard let targetMessageId = Data(base64Encoded: toMessageIdB64) else {
            print("sendReaction(DM): invalid target message id base64")
            return
        }
        do {
            let reportData = try DM.sendReaction(
                toPubKey,
                partnerToken: partnerToken,
                reaction: emoji,
                reactToBytes: targetMessageId,
                cmixParamsJSON: "".data
            )
            do {
                let report = try Parser.decodeChannelSendReport(
                    from: reportData
                )
                if let mid = report.messageID {
                    print(
                        "DM sendReaction messageID: \(mid.base64EncodedString())"
                    )
                } else {
                    print("DM sendReaction returned no messageID")
                }
                persistReaction(
                    messageIdB64: report.messageID!.base64EncodedString(),
                    emoji: emoji,
                    targetMessageId: toMessageIdB64,
                    isMe: true
                )
            } catch {
                print(
                    "Failed to decode ChannelSendReport (DM reaction): \(error)"
                )
            }
        } catch {
            print(
                "ERROR: Unable to send reaction: " + error.localizedDescription
            )
            fatalError("Unable to send reaction: " + error.localizedDescription)
        }
    }

    /// Delete a message from a channel (admin or message owner only)
    public func deleteMessage(channelId: String, messageId: String) {
        guard let cm = channelsManager else {
            print("deleteMessage: Channels Manager not initialized")
            return
        }

        let channelIdData = Data(base64Encoded: channelId) ?? channelId.data(using: .utf8) ?? Data()
        guard let messageIdData = Data(base64Encoded: messageId) else {
            print("deleteMessage: invalid message id base64")
            return
        }

        do {
            try cm.deleteMessage(channelIdData, targetMessageIdBytes: messageIdData, cmixParamsJSON: "".data)
            print("Successfully deleted message: \(messageId)")
        } catch {
            print("deleteMessage failed: \(error.localizedDescription)")
        }
    }
}
