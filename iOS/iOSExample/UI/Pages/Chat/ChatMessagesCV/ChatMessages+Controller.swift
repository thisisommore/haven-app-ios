//
//  ChatMessages+Controller.swift
//  iOSExample
//
//  Created by Om More on 07/03/26.
//

import Combine
import GRDB
import SnapKit
import SQLiteData
import SwiftUI
import UIKit

final class ChatMessagesVC: UIViewController {
  // Data
  var chat: ChatModel
  var isFetchingNextPage = true
  var onReply: (ChatMessageModel) -> Void
  var onReact: (ChatMessageModel) -> Void

  /// Using externalId
  var onDeleteMessage: (String) -> Void
  func _onDeleteMessage(externalId: String) {
    self.shouldWaitForContentMenu = true
    self.onDeleteMessage(externalId)
  }

  var onMuteUser: (Data) -> Void
  var onDeleteReaction: (MessageReactionModel) -> Void

  typealias Section = Int
  typealias Item = Message
  /// store this since cv.dataSource is weak
  private(set) lazy var dataSource: DataSource = makeDataSource()

  // Database
  @Dependency(\.defaultDatabase) var database
  nonisolated static let limit: Int = 40
  private static let loadNewMessagesThreshold: CGFloat = 200
  private static let padding: CGFloat = 8
  var page = 1
  var initDataDone = false
  var messages: [MessageWithSender] = []
  var cancellable: AnyDatabaseCancellable?
  private(set) var isNearBottom: Bool = true
  var targetScrollMessageId: Int64?
  var highlightMessageId: Int64?

  /// Defers diffable snapshot application while a context menu is visible (see `ChatMessages+CVDelegate`).
  var shouldWaitForContentMenu = false
  var pendingSnapshot: NSDiffableDataSourceSnapshot<Section, Item>?
  //

  // Flag to check if scrollToBottomButton can be shown,
  // useful when new message appear at button and automatic scroll
  // to bottom is trigged
  var tempButtonDisable = true
  private lazy var scrollToBottomButton: UIButton = {
    let btn = UIButton(type: .system)
    let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .light)
    let image = UIImage(systemName: "chevron.down", withConfiguration: config)
    btn.setImage(image, for: .normal)

    btn.tintColor = .white
    btn.backgroundColor = UIColor(named: "Haven")
    btn.layer.cornerRadius = 8

    btn.layer.shadowColor = UIColor.black.cgColor
    btn.layer.shadowOpacity = 0.2
    btn.layer.shadowOffset = CGSize(width: 0, height: 2)
    btn.layer.shadowRadius = 4

    btn.isHidden = true
    btn.addTarget(self, action: #selector(self.scrollToBottomTapped), for: .touchUpInside)
    return btn
  }()

  private(set) var cv: UICollectionView
  private var previousViewSize: CGFloat = 0

  init(
    chat: ChatModel,
    onReply: @escaping ((ChatMessageModel) -> Void),
    onReact: @escaping ((ChatMessageModel) -> Void),
    onDeleteMessage: @escaping ((String) -> Void),
    onMuteUser: @escaping ((Data) -> Void),
    onDeleteReaction: @escaping ((MessageReactionModel) -> Void)
  ) {
    self.chat = chat
    self.onReply = onReply
    self.onReact = onReact
    self.onDeleteMessage = onDeleteMessage
    self.onMuteUser = onMuteUser
    self.onDeleteReaction = onDeleteReaction
    self.cv = UICollectionView(
      frame: .zero, collectionViewLayout: ChatMessagesCollectionViewLayout()
    )
    self.cv.contentInset = UIEdgeInsets(
      top: Self.padding, left: Self.padding, bottom: Self.padding, right: Self.padding
    )
    super.init(nibName: nil, bundle: nil)
    self.startObservation()
  }

  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    // Track if the user is currently near the bottom of the chat
    // We use a threshold (e.g., 100 points) to allow some tolerance
    let distFromBottom = self.distanceFromBottom(
      minY: scrollView.contentOffset.y,
      viewSize: scrollView.bounds.height,
      contentSize: scrollView.contentSize.height
    )
    self.isNearBottom = distFromBottom < 1

    // Show button if more than 30pt from bottom
    let shouldShowButton = distFromBottom > 60
    let shouldHideButton = !shouldShowButton
    if self.scrollToBottomButton.isHidden != shouldHideButton {
      UIView.animate(withDuration: 0.2) {
        self.scrollToBottomButton.isHidden = shouldHideButton
        self.scrollToBottomButton.alpha = shouldHideButton ? 0.0 : 1.0
      }
    }

    if self.isFetchingNextPage || !isCurrentPageFull() { return }
    let distanceFromVisualTop = scrollView.contentOffset.y + scrollView.adjustedContentInset.top

    if distanceFromVisualTop < Self.loadNewMessagesThreshold {
      nextPage()
    }
  }

  deinit {
    cancellable?.cancel()
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    let appBackground = UIColor(Color.appBackground)
    self.cv.backgroundColor = appBackground

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(self.keyboardWillHide),
      name: UIResponder.keyboardWillHideNotification,
      object: nil
    )

    // Collection view
    self.cv.delegate = self
    self.cv.register(MessageBubble.self, forCellWithReuseIdentifier: MessageBubble.identifier)
    self.cv.register(DateBadgeCell.self, forCellWithReuseIdentifier: DateBadgeCell.identifier)
    self.cv.alwaysBounceVertical = true
    self.cv.keyboardDismissMode = .interactive
    view.addSubview(self.cv)

    let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
    tap.cancelsTouchesInView = false
    self.cv.addGestureRecognizer(tap)

    self.cv.snp.makeConstraints {
      $0.top.leading.trailing.equalTo(view)
      $0.bottom.equalTo(view.keyboardLayoutGuide.snp.top)
    }

    view.addSubview(self.scrollToBottomButton)
    self.scrollToBottomButton.snp.makeConstraints {
      $0.trailing.equalTo(view).offset(-20)
      $0.bottom.equalTo(view.keyboardLayoutGuide.snp.top).offset(-20)
      $0.width.height.equalTo(40)
    }
    //
  }

  @objc private func scrollToBottomTapped() {
    let noOfItems = self.cv.numberOfItems(inSection: 0)
    guard noOfItems >= 0 else { return }
    self.cv.scrollToItem(at: (noOfItems - 1).idxPath(), at: .bottom, animated: true)
  }

  func withScrollToButtomDisabled(_ block: (_ enable: @escaping () -> Void) -> Void) {
    // hide button if currently visible
    self.scrollToBottomButton.isHidden = true
    self.tempButtonDisable = true
    block {
      self.tempButtonDisable = false
    }
  }

  @objc private func dismissKeyboard() {
    UIApplication.shared.sendAction(
      #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
    )
  }

  @objc private func keyboardWillHide(_ notification: Notification) {
    guard
      let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey]
      as? TimeInterval,
      let curve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey]
      as? UInt
    else {
      return
    }
    UIView.animate(
      withDuration: duration, delay: 0,
      options: UIView.AnimationOptions(rawValue: curve << 16)
    ) {
      self.view.layoutIfNeeded()
    }
  }

  private func distanceFromBottom(minY: CGFloat, viewSize: CGFloat, contentSize: CGFloat) -> CGFloat {
    let insetBottom = self.cv.adjustedContentInset.bottom
    let maxY = minY + viewSize
    return (contentSize - maxY) + insetBottom
  }

  private func preserveBottomOffset() {
    // When keyboard appears we need to preserve bottom offset of scroll
    let newViewSize = self.cv.bounds.height
    defer {
      // Update the stored height for next pass
      previousViewSize = newViewSize
    }
    // If no change skip
    guard newViewSize > 0, newViewSize != self.previousViewSize else { return }

    // Don't adjust offset programmatically if the user is actively dragging
    // (e.g., during an interactive keyboard dismiss)
    guard !self.cv.isDragging && !self.cv.isTracking else { return }

    let contentSize = self.cv.contentSize.height
    let minY = self.cv.contentOffset.y

    let oldDistanceFromBottom =
      self.distanceFromBottom(minY: minY, viewSize: self.previousViewSize, contentSize: contentSize)

    let newDistanceFromBottom =
      self.distanceFromBottom(minY: minY, viewSize: newViewSize, contentSize: contentSize)

    // When keyboard is on the bottom will shift up
    let changeInDistanceFromBottom = oldDistanceFromBottom - newDistanceFromBottom

    // Skip no change or positive change (when keyboard goes down)
    if changeInDistanceFromBottom == 0 || newDistanceFromBottom < 1 {
      return
    }

    // push minY up so bottom is still visible at same place
    let newMinY = minY - changeInDistanceFromBottom

    self.cv.setContentOffset(
      CGPoint(x: self.cv.contentOffset.x, y: newMinY), animated: false
    )
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    self.preserveBottomOffset()
  }

  override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    coordinator.animate(alongsideTransition: { _ in
      self.cv.collectionViewLayout.invalidateLayout()
    })
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func scrollToMessage(_ msg: ChatMessageModel?) {
    guard let msg else { return }

    // Check if the message is already loaded
    if let index = dataSource.snapshot().itemIdentifiers.firstIndex(where: {
      if case let .text(m) = $0 {
        return m.message.id == msg.id
      }
      return false
    }) {
      let indexPath = IndexPath(item: index, section: 0)
      self.cv.scrollToItem(at: indexPath, at: .centeredVertically, animated: true)

      self.highlightMessageId = msg.id
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        if let cell = self.cv.cellForItem(at: indexPath) as? MessageBubble {
          if self.highlightMessageId == msg.id {
            cell.highlight()
            self.highlightMessageId = nil
          }
        }
      }
      return
    }

    // If not loaded, we need to find its position in the database to load enough pages
    Task {
      let chatId = self.chat.id
      do {
        let position = try await database.read { db in
          try ChatMessageModel
            .where { $0.chatId.eq(chatId) && $0.timestamp.gte(msg.timestamp) }
            .fetchCount(db)
        }

        let requiredPage = Int(ceil(Double(position) / Double(Self.limit)))
        if requiredPage > self.page {
          self.page = requiredPage
          self.targetScrollMessageId = msg.id
          self.startObservation()
        }
      } catch let err {
        AppLogger.chat.error(
          "Failed to find message position: \(err.localizedDescription, privacy: .public)"
        )
      }
    }
  }
}

extension ChatMessagesVC {
  static func reactionPreviewEmojis(from fetchedEmojis: [String]) -> [String] {
    guard !fetchedEmojis.isEmpty else { return [] }
    if fetchedEmojis.count == 3 {
      return Array(fetchedEmojis.prefix(2)) + ["+"]
    }
    return fetchedEmojis
  }

  func showReactors(for message: ChatMessageModel) {
    let view = ReactorsSheet(
      targetMessageId: message.externalId,
      chatId: self.chat.id,
      selectedEmoji: nil,
      onDeleteReaction: { [weak self] reaction in
        self?.onDeleteReaction(reaction)
      }
    )
    let controller = UIHostingController(rootView: view)
    if let sheet = controller.sheetPresentationController {
      sheet.detents = [.medium(), .large()]
    }
    self.present(controller, animated: true)
  }
}
