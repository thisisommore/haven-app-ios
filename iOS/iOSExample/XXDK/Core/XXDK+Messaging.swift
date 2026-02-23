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
        guard let modelActor else {
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
                modelActor.insert(reaction)
                try modelActor.save()
            } catch {
                AppLogger.messaging.error("persistReaction failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // Send a message to a channel by Channel ID (base64-encoded)
    func sendDM(msg: String, channelId: String) {
        guard let channelsManager else {
            fatalError("sendDM(channel): Channels Manager not initialized")
        }
        let channelIdData =
            Data(base64Encoded: channelId) ?? channelId.data(using: .utf8)
                ?? Data()
        do {
            let reportData = try channelsManager.sendMessage(
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
                } else {}
            } catch {
                AppLogger.messaging.error("Failed to decode ChannelSendReport: \(error.localizedDescription, privacy: .public)")
            }
        } catch {
            AppLogger.messaging.error("sendDM(channel) failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // Send a reply to a specific message in a channel
    func sendReply(msg: String, channelId: String, replyToMessageIdB64: String) {
        guard let channelsManager else {
            fatalError("sendReply(channel): Channels Manager not initialized")
        }
        let channelIdData =
            Data(base64Encoded: channelId) ?? channelId.data(using: .utf8)
                ?? Data()
        guard let replyToMessageId = Data(base64Encoded: replyToMessageIdB64)
        else {
            return
        }
        do {
            let reportData = try channelsManager.sendReply(
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
                } else {}
            } catch {
                AppLogger.messaging.error("Failed to decode ChannelSendReport (reply): \(error.localizedDescription, privacy: .public)")
            }
        } catch {
            AppLogger.messaging.error("sendReply(channel) failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // Send a reaction to a specific message in a channel
    public func sendReaction(
        emoji: String,
        toMessageIdB64: String,
        inChannelId channelId: String
    ) {
        guard let channelsManager else {
            fatalError(
                "sendReaction(channel): Channels Manager not initialized"
            )
        }
        let channelIdData =
            Data(base64Encoded: channelId) ?? channelId.data(using: .utf8)
                ?? Data()
        guard let targetMessageId = Data(base64Encoded: toMessageIdB64) else {
            return
        }
        do {
            let reportData = try channelsManager.sendReaction(
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
                } else {}
                persistReaction(
                    messageIdB64: report.messageID!.base64EncodedString(),
                    emoji: emoji,
                    targetMessageId: toMessageIdB64,
                    isMe: true
                )
            } catch {
                AppLogger.messaging.error("Failed to decode ChannelSendReport (reaction): \(error.localizedDescription, privacy: .public)")
            }
        } catch {
            AppLogger.messaging.error("sendReaction(channel) failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func sendDM(msg: String, toPubKey: Data, partnerToken: Int32) {
        guard let DM else {
            AppLogger.messaging.critical("DM not there")
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
                    let chatId = toPubKey.base64EncodedString()
                    let _: String = {
                        if let modelActor {
                            let descriptor = FetchDescriptor<ChatModel>(
                                predicate: #Predicate { $0.id == chatId }
                            )
                            if let found = try? modelActor.fetch(descriptor).first {
                                return found.name
                            }
                        }
                        return "Direct Message"
                    }()

                } else {}
            } catch {
                AppLogger.messaging.error("Failed to decode ChannelSendReport: \(error.localizedDescription, privacy: .public)")
            }
        } catch {
            AppLogger.messaging.error("Unable to send: \(error.localizedDescription, privacy: .public)")
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
            AppLogger.messaging.critical("DM not there")
            fatalError("DM not there")
        }
        guard let replyToMessageId = Data(base64Encoded: replyToMessageIdB64)
        else {
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
                    AppLogger.messaging.debug("DM sendReply messageID: \(mid.base64EncodedString(), privacy: .public)")
                    let chatId = toPubKey.base64EncodedString()
                    let _: String = {
                        if let modelActor {
                            let descriptor = FetchDescriptor<ChatModel>(
                                predicate: #Predicate { $0.id == chatId }
                            )
                            if let found = try? modelActor.fetch(descriptor).first {
                                return found.name
                            }
                        }
                        return "Direct Message"
                    }()

                } else {
                    AppLogger.messaging.warning("DM sendReply returned no messageID")
                }
            } catch {
                AppLogger.messaging.error("Failed to decode ChannelSendReport (DM reply): \(error.localizedDescription, privacy: .public)")
            }
        } catch {
            AppLogger.messaging.critical("Unable to send reply: \(error.localizedDescription, privacy: .public)")
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
            AppLogger.messaging.critical("DM not there")
            fatalError("DM not there")
        }
        guard let targetMessageId = Data(base64Encoded: toMessageIdB64) else {
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
                } else {}
                persistReaction(
                    messageIdB64: report.messageID!.base64EncodedString(),
                    emoji: emoji,
                    targetMessageId: toMessageIdB64,
                    isMe: true
                )
            } catch {
                AppLogger.messaging.error("Failed to decode ChannelSendReport (DM reaction): \(error.localizedDescription, privacy: .public)")
            }
        } catch {
            AppLogger.messaging.critical("Unable to send reaction: \(error.localizedDescription, privacy: .public)")
            fatalError("Unable to send reaction: " + error.localizedDescription)
        }
    }

    /// Delete a message from a channel (admin or message owner only)
    public func deleteMessage(channelId: String, messageId: String) {
        guard let channelsManager else {
            return
        }

        let channelIdData = Data(base64Encoded: channelId) ?? channelId.data(using: .utf8) ?? Data()
        guard let messageIdData = Data(base64Encoded: messageId) else {
            return
        }

        do {
            try channelsManager.deleteMessage(channelIdData, targetMessageIdBytes: messageIdData, cmixParamsJSON: "".data)
        } catch {
            AppLogger.messaging.error("deleteMessage failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
