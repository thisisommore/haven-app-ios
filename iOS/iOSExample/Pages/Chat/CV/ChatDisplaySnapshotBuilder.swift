//
//  ChatDisplaySnapshotBuilder.swift
//  iOSExample
//
//  Created by Cursor on 06/03/26.
//

import Foundation

struct TextRowMeta: Equatable {
  let senderDisplayName: String?
  let senderColor: Int?
  let replyPreviewText: String?
}

struct MessageBatchDiff {
  let inserts: [IndexPath]
  let deletes: [IndexPath]
  let updates: [IndexPath]
}

final class ChatDisplaySnapshotBuilder {
  func buildTextRowMeta(
    messages: [ChatMessageModel],
    senders: [String: MessageSenderModel],
    messageById: [String: ChatMessageModel]
  ) -> [Int64: TextRowMeta] {
    guard !messages.isEmpty else { return [:] }
    let calendar = Calendar.current
    var rowMetaByInternalId: [Int64: TextRowMeta] = [:]
    rowMetaByInternalId.reserveCapacity(messages.count)

    var senderDisplayNameById: [String: String] = [:]
    senderDisplayNameById.reserveCapacity(senders.count)
    for (id, sender) in senders {
      senderDisplayNameById[id] = senderDisplayName(for: sender)
    }

    var replyPreviewByMessageId: [String: String?] = [:]
    replyPreviewByMessageId.reserveCapacity(messages.count)

    for (index, message) in messages.enumerated() {
      let replyPreviewText = replyPreviewText(
        for: message.replyTo,
        messageById: messageById,
        cache: &replyPreviewByMessageId
      )

      guard message.isIncoming else {
        rowMetaByInternalId[message.internalId] = TextRowMeta(
          senderDisplayName: nil,
          senderColor: nil,
          replyPreviewText: replyPreviewText
        )
        continue
      }

      let startsNewDay =
        index == 0
        || !calendar.isDate(message.timestamp, inSameDayAs: messages[index - 1].timestamp)

      let shouldShowSender: Bool
      if startsNewDay {
        shouldShowSender = true
      } else {
        let previous = messages[index - 1]
        shouldShowSender = !(previous.isIncoming && previous.senderId == message.senderId)
      }

      if !shouldShowSender {
        rowMetaByInternalId[message.internalId] = TextRowMeta(
          senderDisplayName: nil,
          senderColor: nil,
          replyPreviewText: replyPreviewText
        )
        continue
      }

      if let senderId = message.senderId, let sender = senders[senderId] {
        rowMetaByInternalId[message.internalId] = TextRowMeta(
          senderDisplayName: senderDisplayNameById[senderId] ?? senderDisplayName(for: sender),
          senderColor: sender.color,
          replyPreviewText: replyPreviewText
        )
      } else {
        rowMetaByInternalId[message.internalId] = TextRowMeta(
          senderDisplayName: "Unknown",
          senderColor: nil,
          replyPreviewText: replyPreviewText
        )
      }
    }

    return rowMetaByInternalId
  }

  func buildReplyPreviewTexts(
    messages: [ChatMessageModel],
    rowMetaByInternalId: [Int64: TextRowMeta]
  ) -> [Int64: String] {
    var previewsByMessageInternalId: [Int64: String] = [:]
    previewsByMessageInternalId.reserveCapacity(messages.count)

    for message in messages {
      if let replyPreviewText = rowMetaByInternalId[message.internalId]?.replyPreviewText {
        previewsByMessageInternalId[message.internalId] = replyPreviewText
      }
    }

    return previewsByMessageInternalId
  }

  func buildBatchDiff(from old: [ChatMessageModel], to new: [ChatMessageModel])
    -> MessageBatchDiff
  {
    let oldByInternalId = Dictionary(
      uniqueKeysWithValues: old.enumerated().map { ($1.internalId, ($0, $1)) }
    )
    let newByInternalId = Dictionary(
      uniqueKeysWithValues: new.enumerated().map { ($1.internalId, ($0, $1)) }
    )

    let deletes: [IndexPath] = old.enumerated().compactMap { index, message in
      guard newByInternalId[message.internalId] == nil else { return nil }
      return IndexPath(item: index + 1, section: 0)
    }.sorted { left, right in
      left.item < right.item
    }

    let inserts: [IndexPath] = new.enumerated().compactMap { index, message in
      guard oldByInternalId[message.internalId] == nil else { return nil }
      return IndexPath(item: index + 1, section: 0)
    }.sorted { left, right in
      left.item < right.item
    }

    let updates =
      new
      .enumerated()
      .compactMap { index, message -> IndexPath? in
        guard let (_, oldMessage) = oldByInternalId[message.internalId] else { return nil }
        guard oldMessage.replyTo != message.replyTo else { return nil }
        return IndexPath(item: index + 1, section: 0)
      }
      .sorted(by: { $0.item < $1.item })

    return MessageBatchDiff(inserts: inserts, deletes: deletes, updates: updates)
  }

  func buildDisplayMessages(from observed: [ChatMessageModel]) -> Messages {
    var display: Messages = [.LoadMore]
    guard !observed.isEmpty else { return display }
    let calendar = Calendar.current

    for (index, message) in observed.enumerated() {
      if index == 0
        || !calendar.isDate(message.timestamp, inSameDayAs: observed[index - 1].timestamp)
      {
        let dayDate = calendar.startOfDay(for: message.timestamp)
        display.append(.DateSeparator(dayDate, isFirst: index == 0))
      }
      if let parsedLink = ParsedChannelLink.parse(from: message.message) {
        display.append(.ChannelLink(message, parsedLink))
      } else {
        display.append(.Text(message))
      }
    }

    return display
  }

  func buildDisplayDiff(
    oldObserved: [ChatMessageModel],
    newObserved: [ChatMessageModel],
    oldDisplay: Messages,
    newDisplay: Messages,
    rawDiff: MessageBatchDiff,
    oldTextRowMeta: [Int64: TextRowMeta],
    newTextRowMeta: [Int64: TextRowMeta]
  ) -> MessageBatchDiff {
    var deleteItems = Set<Int>()
    var insertItems = Set<Int>()
    var updateItems = Set<Int>()

    let oldTextIndices = displayTextIndicesByInternalId(in: oldDisplay)
    let newTextIndices = displayTextIndicesByInternalId(in: newDisplay)

    for indexPath in rawDiff.deletes {
      let rawIndex = indexPath.item - 1
      guard oldObserved.indices.contains(rawIndex) else { continue }
      let key = String(describing: oldObserved[rawIndex].internalId)
      if let item = oldTextIndices[key] {
        deleteItems.insert(item)
      }
    }

    for indexPath in rawDiff.inserts {
      let rawIndex = indexPath.item - 1
      guard newObserved.indices.contains(rawIndex) else { continue }
      let key = String(describing: newObserved[rawIndex].internalId)
      if let item = newTextIndices[key] {
        insertItems.insert(item)
      }
    }

    for indexPath in rawDiff.updates {
      let rawIndex = indexPath.item - 1
      guard newObserved.indices.contains(rawIndex) else { continue }
      let key = String(describing: newObserved[rawIndex].internalId)
      if let item = newTextIndices[key] {
        updateItems.insert(item)
      }
    }

    for message in newObserved {
      guard let oldMeta = oldTextRowMeta[message.internalId],
        let newMeta = newTextRowMeta[message.internalId],
        oldMeta != newMeta
      else {
        continue
      }
      let key = String(describing: message.internalId)
      if let item = newTextIndices[key] {
        updateItems.insert(item)
      }
    }

    let oldDateRows = displayDateRows(in: oldDisplay)
    let newDateRows = displayDateRows(in: newDisplay)

    for (key, oldRow) in oldDateRows where newDateRows[key] == nil {
      deleteItems.insert(oldRow.index)
    }
    for (key, newRow) in newDateRows where oldDateRows[key] == nil {
      insertItems.insert(newRow.index)
    }
    for (key, oldRow) in oldDateRows {
      guard let newRow = newDateRows[key] else { continue }
      if oldRow.isFirst != newRow.isFirst {
        updateItems.insert(newRow.index)
      }
    }

    updateItems.subtract(insertItems)

    return MessageBatchDiff(
      inserts: insertItems.sorted().map { IndexPath(item: $0, section: 0) },
      deletes: deleteItems.sorted().map { IndexPath(item: $0, section: 0) },
      updates: updateItems.sorted().map { IndexPath(item: $0, section: 0) }
    )
  }

  private func senderDisplayName(for sender: MessageSenderModel?) -> String {
    guard let sender else { return "Unknown" }
    guard let nickname = sender.nickname, !nickname.isEmpty else {
      return sender.codename
    }
    let truncatedNickname = nickname.count > 10 ? String(nickname.prefix(10)) + "…" : nickname
    return "\(truncatedNickname) aka \(sender.codename)"
  }

  private func replyPreviewText(
    for replyToMessageId: String?,
    messageById: [String: ChatMessageModel],
    cache: inout [String: String?]
  ) -> String? {
    guard let replyToMessageId else { return nil }
    if let cached = cache[replyToMessageId] {
      return cached
    }

    let previewText = messageById[replyToMessageId].flatMap { message in
      normalizedReplyPreviewText(for: message)
    }
    cache[replyToMessageId] = previewText
    return previewText
  }

  private func normalizedReplyPreviewText(for message: ChatMessageModel) -> String? {
    let renderKind = NewMessageRenderKind(rawValue: message.newRenderKindRaw) ?? .unknown
    let plainText: String
    if message.newRenderVersion == NewMessageRenderVersion.current,
      renderKind != .unknown,
      let storedPlainText = message.newRenderPlainText
    {
      plainText = storedPlainText
    } else {
      plainText = NewMessageHTMLPrecomputer.precompute(rawHTML: message.message).plainText
    }
    let trimmed = plainText.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  private func displayTextIndicesByInternalId(in messages: Messages) -> [String: Int] {
    var map: [String: Int] = [:]
    for (index, message) in messages.enumerated() {
      switch message {
      case .Text(let textMessage), .ChannelLink(let textMessage, _):
        map[String(describing: textMessage.internalId)] = index
      case .DateSeparator, .LoadMore:
        continue
      }
    }
    return map
  }

  private func displayDateRows(in messages: Messages) -> [String: (index: Int, isFirst: Bool)] {
    var map: [String: (index: Int, isFirst: Bool)] = [:]
    for (index, message) in messages.enumerated() {
      guard case .DateSeparator(let date, let isFirst) = message else { continue }
      map[dateSeparatorKey(for: date)] = (index: index, isFirst: isFirst)
    }
    return map
  }

  private func dateSeparatorKey(for date: Date) -> String {
    String(Int(Calendar.current.startOfDay(for: date).timeIntervalSince1970))
  }
}
