//
//  MacChatMessages+Controller.swift
//  haven
//
//  AppKit message list: NSCollectionView with a diffable data source fed by a
//  GRDB ValueObservation (paged, 40 per page), mirroring the iOS
//  ChatMessagesVC. Handles sender grouping, date separators, scroll-to-bottom
//  stickiness, prepend anchoring, and reply scroll-and-highlight.
//

import AppKit
import GRDB
import SQLiteData
import SwiftUI

final class MacChatMessagesVC: NSViewController {
  typealias Section = Int
  typealias Item = Message
  typealias ObservedMessages = [(
    ChatMessageModel,
    MessageSenderModel,
    SQLiteData.TableAlias<ChatMessageModel, ReplyTo>?.QueryOutput,
    [String]
  )]

  enum ReplyTo: AliasName {}

  static let limit = 40
  static let loadNewMessagesThreshold: CGFloat = 200

  private let chatId: UUID
  private let pageController: ChatPageController
  private let xxdk: XXDK
  private let onShowReactors: (ChatMessageModel) -> Void

  @Dependency(\.defaultDatabase) private var database

  private var scrollView: NSScrollView!
  private var cv: NSCollectionView!
  private var dataSource: NSCollectionViewDiffableDataSource<Section, Item>!
  private var scrollToBottomButton: NSButton!
  private var boundsObserver: NSObjectProtocol?

  private var cancellable: DatabaseCancellable?
  private var messages: [MessageWithSender] = []
  private var page = 1
  private var isFetchingNextPage = false
  private var initDataDone = false
  private var didInitialScroll = false
  private var isNearBottom = true
  private var targetScrollMessageId: Int64?

  init(
    chatId: UUID,
    pageController: ChatPageController,
    xxdk: XXDK,
    onShowReactors: @escaping (ChatMessageModel) -> Void
  ) {
    self.chatId = chatId
    self.pageController = pageController
    self.xxdk = xxdk
    self.onShowReactors = onShowReactors
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func loadView() {
    self.view = NSView()
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.makeUI()
    self.startObservation()
  }

  deinit {
    self.cancellable?.cancel()
    if let boundsObserver {
      NotificationCenter.default.removeObserver(boundsObserver)
    }
  }
}

// MARK: - UI setup

extension MacChatMessagesVC {
  private func makeUI() {
    self.scrollView = NSScrollView()
    self.scrollView.hasVerticalScroller = true
    self.scrollView.drawsBackground = false
    self.scrollView.translatesAutoresizingMaskIntoConstraints = false
    self.view.addSubview(self.scrollView)
    NSLayoutConstraint.activate([
      self.scrollView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
      self.scrollView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
      self.scrollView.topAnchor.constraint(equalTo: self.view.topAnchor),
      self.scrollView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
    ])

    self.cv = NSCollectionView()
    self.cv.backgroundColors = [.clear]
    self.cv.isSelectable = false
    self.cv.collectionViewLayout = Self.makeLayout()
    self.scrollView.documentView = self.cv

    self.cv.register(MacHostingCell.self, forItemWithIdentifier: MacHostingCell.messageReuseId)
    self.cv.register(MacHostingCell.self, forItemWithIdentifier: MacHostingCell.dateReuseId)

    self.dataSource = NSCollectionViewDiffableDataSource<Section, Item>(
      collectionView: self.cv
    ) { [weak self] collectionView, indexPath, item in
      guard let self else { return nil }
      switch item {
      case let .text(messageWithSender):
        let cell = collectionView.makeItem(
          withIdentifier: MacHostingCell.messageReuseId,
          for: indexPath
        ) as! MacHostingCell
        cell.setContent(
          MacMessageBubble(
            message: messageWithSender.message,
            sender: messageWithSender.sender,
            reactionEmojis: messageWithSender.reactionEmojis,
            showsSender: !messageWithSender.sender.codename.isEmpty,
            isChannel: self.isChannel,
            isHighlighted: false,
            controller: self.pageController,
            onReplyPreviewTap: { [weak self] externalId in
              self?.scrollToMessage(externalId: externalId)
            },
            onShowReactors: { [weak self] in
              self?.onShowReactors(messageWithSender.message)
            }
          )
          .environmentObject(self.xxdk)
        )
        return cell

      case let .date(text):
        let cell = collectionView.makeItem(
          withIdentifier: MacHostingCell.dateReuseId,
          for: indexPath
        ) as! MacHostingCell
        cell.setContent(MacDateBadge(text: text))
        return cell
      }
    }

    // Scroll-to-bottom button
    let button = NSButton(title: "↓", target: self, action: #selector(self.scrollToBottomTapped))
    button.bezelStyle = .regularSquare
    button.isBordered = false
    button.wantsLayer = true
    button.layer?.cornerRadius = 14
    button.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    button.font = .systemFont(ofSize: 14, weight: .semibold)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.isHidden = true
    self.view.addSubview(button)
    NSLayoutConstraint.activate([
      button.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -16),
      button.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: -12),
      button.widthAnchor.constraint(equalToConstant: 28),
      button.heightAnchor.constraint(equalToConstant: 28),
    ])
    self.scrollToBottomButton = button

    // Scroll position tracking (paging trigger + near-bottom state)
    let clipView = self.scrollView.contentView
    clipView.postsBoundsChangedNotifications = true
    self.boundsObserver = NotificationCenter.default.addObserver(
      forName: NSView.boundsDidChangeNotification,
      object: clipView,
      queue: .main
    ) { [weak self] _ in
      self?.handleScrollPositionChanged()
    }
  }

  private static func makeLayout() -> NSCollectionViewLayout {
    // Estimated height must be large enough for a typical bubble+sender so the
    // first layout pass is close; self-sizing then resolves via the cell's
    // measured height constraint (see MacHostingCell).
    let itemSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(72)
    )
    let item = NSCollectionLayoutItem(layoutSize: itemSize)

    let groupSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(72)
    )
    let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])

    let section = NSCollectionLayoutSection(group: group)
    section.interGroupSpacing = 4
    section.contentInsets = NSDirectionalEdgeInsets(
      top: 10, leading: 16, bottom: 10, trailing: 16
    )
    return NSCollectionViewCompositionalLayout(section: section)
  }

  private var isChannel: Bool {
    guard let chat = pageController.chat else { return false }
    return chat.id != UUID.selfId && chat.dmToken == nil
  }
}

// MARK: - Scrolling

extension MacChatMessagesVC {
  @objc private func scrollToBottomTapped() {
    self.scrollToBottom(animated: true)
  }

  private func handleScrollPositionChanged() {
    let clipBounds = self.scrollView.contentView.bounds
    let contentHeight = self.cv.frame.height
    let distanceFromBottom = contentHeight - clipBounds.maxY
    self.isNearBottom = distanceFromBottom < 80
    self.scrollToBottomButton.isHidden = self.isNearBottom

    // Near the visual top → load older messages
    if clipBounds.minY < Self.loadNewMessagesThreshold,
           self.isCurrentPageFull(),
           !self.isFetchingNextPage {
      self.nextPage()
    }
  }

  private func scrollToBottom(animated: Bool) {
    let contentHeight = self.cv.frame.height
    let clipHeight = self.scrollView.contentView.bounds.height
    guard contentHeight > clipHeight else { return }
    let target = NSPoint(x: 0, y: contentHeight - clipHeight)
    if animated {
      self.scrollView.contentView.animator().setBoundsOrigin(target)
    } else {
      self.scrollView.contentView.setBoundsOrigin(target)
    }
  }

  func scrollToMessage(externalId: String) {
    guard let target = self.messages.first(where: { $0.message.externalId == externalId })
    else {
      // Older message not loaded yet: page up until it shows, then scroll.
      guard self.isCurrentPageFull() else { return }
      self.targetScrollMessageId = self.messages.last?.message.id
      self.nextPage()
      return
    }
    self.targetScrollMessageId = target.message.id
    self.applyTargetScrollIfPossible()
  }

  private func applyTargetScrollIfPossible() {
    guard let targetId = targetScrollMessageId,
          let index = self.messages.firstIndex(where: { $0.message.id == targetId })
    else { return }
    self.targetScrollMessageId = nil

    // Item index in the snapshot differs from the messages index because of
    // date separators; find it via the data source snapshot.
    let snapshot = self.dataSource.snapshot()
    guard let snapshotIndex = snapshot.itemIdentifiers.firstIndex(where: {
      if case let .text(m) = $0 { return m.message.id == targetId }
      return false
    }) else { return }

    let indexPath = IndexPath(item: snapshotIndex, section: 0)
    self.cv.animator().scrollToItems(
      at: [indexPath],
      scrollPosition: .centeredVertically
    )

    // Flash-highlight the bubble briefly
    let identifier = snapshot.itemIdentifiers[snapshotIndex]
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
      guard let self,
            let cell = self.cv.item(at: indexPath) as? MacHostingCell
      else { return }
      self.flash(cell: cell, identifier: identifier)
    }
  }

  private func flash(cell: MacHostingCell, identifier: Item) {
    guard case let .text(mws) = identifier else { return }
    cell.setContent(
      MacMessageBubble(
        message: mws.message,
        sender: mws.sender,
        reactionEmojis: mws.reactionEmojis,
        showsSender: !mws.sender.codename.isEmpty,
        isChannel: self.isChannel,
        isHighlighted: true,
        controller: self.pageController,
        onReplyPreviewTap: { [weak self] externalId in
          self?.scrollToMessage(externalId: externalId)
        },
        onShowReactors: { [weak self] in
          self?.onShowReactors(mws.message)
        }
      )
      .environmentObject(self.xxdk)
    )
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
      guard let self else { return }
      cell.setContent(
        MacMessageBubble(
          message: mws.message,
          sender: mws.sender,
          reactionEmojis: mws.reactionEmojis,
          showsSender: !mws.sender.codename.isEmpty,
          isChannel: self.isChannel,
          isHighlighted: false,
          controller: self.pageController,
          onReplyPreviewTap: { [weak self] externalId in
            self?.scrollToMessage(externalId: externalId)
          },
          onShowReactors: { [weak self] in
            self?.onShowReactors(mws.message)
          }
        )
        .environmentObject(self.xxdk)
      )
    }
  }
}

// MARK: - Paging

extension MacChatMessagesVC {
  func nextPage() {
    self.isFetchingNextPage = true
    self.page += 1
    self.startObservation()
  }

  func isCurrentPageFull() -> Bool {
    self.messages.count >= Self.limit * self.page
  }
}

// MARK: - Data observation

extension MacChatMessagesVC {
  func startObservation() {
    self.cancellable?.cancel()

    let observation = ValueObservation.tracking { db in
      try self.makeObservationPayload(db: db)
    }

    self.cancellable = observation.start(in: self.database, scheduling: .immediate) { _ in
      // Handle error
    } onChange: { [weak self] (_messages: ObservedMessages) in
      guard let self else { return }
      self.isFetchingNextPage = false
      self.messages = _messages.reversed().map {
        var emojis = $0.3
        if emojis.count >= 3 {
          emojis[2] = "+"
        }
        return MessageWithSender(
          message: $0.0, sender: $0.1, replyTo: $0.2,
          reactionEmojis: emojis
        )
      }

      var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
      snapshot.appendSections([0])
      snapshot.appendItems(
        self.messages.enumerated()
          .map { index, message -> [Item] in
            let dateChanged =
              index == 0
                || !Calendar.current.isDate(
                  self.messages[index - 1].message.timestamp,
                  inSameDayAs: message.message.timestamp
                )
            let senderChanged =
              index == 0
                || self.messages[index - 1].message.senderId != message.message.senderId
                || self.messages[index - 1].sender != message.sender
            let showsSender = dateChanged || senderChanged
            let messageWithDisplaySender: MessageWithSender = {
              if showsSender {
                return message
              }
              var sender = message.sender
              sender.codename = ""
              return MessageWithSender(
                message: message.message, sender: sender, replyTo: message.replyTo,
                reactionEmojis: message.reactionEmojis
              )
            }()

            if dateChanged {
              return [
                .date(
                  message.message.timestamp.formatted(
                    date: .abbreviated, time: .omitted
                  )
                ),
                .text(messageWithDisplaySender),
              ]
            }
            return [.text(messageWithDisplaySender)]
          }
          .flatMap { $0 }
      )
      self.applySnapshot(snapshot)
    }
  }

  private func applySnapshot(_ snapshot: NSDiffableDataSourceSnapshot<Section, Item>) {
    if self.initDataDone {
      // Anchor the scroll position to the first visible message so
      // prepends/updates don't cause jumps.
      var anchor: (messageId: Int64, offsetFromTop: CGFloat)?
      if !self.isNearBottom {
        let clipBounds = self.scrollView.contentView.bounds
        if let firstVisible = self.cv.indexPathsForVisibleItems().sorted().first,
           let item = self.dataSource.itemIdentifier(for: firstVisible),
           case let .text(m) = item,
           let attrs = self.cv.layoutAttributesForItem(at: firstVisible) {
          anchor = (m.message.id, attrs.frame.minY - clipBounds.minY)
        }
      }

      let wasNearBottom = self.isNearBottom
      self.dataSource.apply(snapshot, animatingDifferences: false)
      // Two-pass layout: first configures cells and measures SwiftUI heights;
      // invalidate then re-layout so estimated item sizes converge on the
      // measured height constraints (avoids overlapping bubbles on Mac).
      self.cv.layoutSubtreeIfNeeded()
      self.cv.collectionViewLayout?.invalidateLayout()
      self.cv.layoutSubtreeIfNeeded()

      if wasNearBottom {
        self.scrollToBottom(animated: false)
      } else if let anchor,
                let snapshotIndex = snapshot.itemIdentifiers.firstIndex(where: {
                  if case let .text(m) = $0 { return m.message.id == anchor.messageId }
                  return false
                }) {
        let indexPath = IndexPath(item: snapshotIndex, section: 0)
        if let attrs = self.cv.layoutAttributesForItem(at: indexPath) {
          self.scrollView.contentView.setBoundsOrigin(
            NSPoint(x: 0, y: attrs.frame.minY - anchor.offsetFromTop)
          )
        }
      }
    } else {
      self.dataSource.apply(snapshot, animatingDifferences: false)
      self.initDataDone = true
      self.cv.layoutSubtreeIfNeeded()
      self.cv.collectionViewLayout?.invalidateLayout()
      self.cv.layoutSubtreeIfNeeded()
      if !self.didInitialScroll {
        self.didInitialScroll = true
        self.scrollToBottom(animated: false)
      }
    }

    if self.targetScrollMessageId != nil {
      DispatchQueue.main.async {
        self.applyTargetScrollIfPossible()
      }
    }
  }

  private func makeObservationPayload(db: Database) throws -> ObservedMessages {
    let whereC = ChatMessageModel
      .where {
        $0.chatId.eq(self.chatId)
          && $0.status.neq(MessageStatus.failed)
      }

    let joinSender = whereC.join(MessageSenderModel.all) { message, sender in
      message.senderId.eq(sender.id)
    }

    let joinReplyTo = joinSender.leftJoin(ChatMessageModel.as(ReplyTo.self).all) { message, _, reply in
      message.replyTo.eq(reply.externalId)
    }
    return try
      joinReplyTo.select { message, sender, reply in
        let first3UniqueReactions = MessageReactionModel
          .where { $0.targetMessageId.eq(message.externalId) && $0.status.neq(MessageStatus.failed) }
          .select(\.emoji)
          .distinct()
          .limit(3)

        return (
          message,
          sender,
          reply,
          #sql(
            "coalesce((SELECT json_group_array(emoji) FROM (\(first3UniqueReactions))), '[]')",
            as: [String].JSONRepresentation.self
          )
        )
      }
      .order { message, _, _ in
        message.timestamp.desc()
      }
      .limit(Self.limit * self.page)
      .fetchAll(db)
  }
}
