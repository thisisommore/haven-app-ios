//
//  ChatMessagesCV.swift
//  iOSExample
//
//  Created by Om More on 07/03/26.
//

import Combine
import GRDB
import SQLiteData
import SnapKit
import SwiftUI
import UIKit

struct MessageWithSender: Hashable {
    let message: ChatMessageModel
    let sender: String?
    let replyTo: ChatMessageModel?
    let colorHex: Int?
}
class ChatMessagesVC: UIViewController {

    // Data
    let chatId: String
    var isFetchingNextPage = true
    var onReply: ((ChatMessageModel) -> Void)

    // DataSource
    enum Message: Hashable {
        case text(MessageWithSender)
        case date(String)

        static func == (lhs: Message, rhs: Message) -> Bool {
            switch (lhs, rhs) {
            case (
                .text(let lhsMessage),
                .text(let rhsMessage)
            ):
                return lhsMessage.message == rhsMessage.message
                    && lhsMessage.sender == rhsMessage.sender
                    && lhsMessage.replyTo == rhsMessage.replyTo
            case (.date(let lhsDate), .date(let rhsDate)):
                return lhsDate == rhsDate
            default:
                return false
            }
        }

        func hash(into hasher: inout Hasher) {
            switch self {
            case .text(let messageWithSender):
                hasher.combine(0)
                hasher.combine(messageWithSender.message)
                hasher.combine(messageWithSender.sender)
                hasher.combine(messageWithSender.replyTo)
            case .date(let date):
                hasher.combine(1)
                hasher.combine(date)
            }
        }
    }
    typealias Section = Int
    typealias Item = Message
    // store this since cv.dataSource is weak
    lazy var dataSource: DataSource = makeDataSource()

    // Database
    @Dependency(\.defaultDatabase) var database
    nonisolated static let limit: Int = 40
    static let loadNewMessagesThreshold: CGFloat = 200
    static let padding: CGFloat = 8
    var page = 1
    var initDataDone = false
    var messages: [MessageWithSender] = []
    var cancellable: AnyDatabaseCancellable?
    var isNearBottom: Bool = true
    var targetScrollMessageId: Int64?
    var highlightMessageId: Int64?
    //

    lazy var scrollToBottomButton: UIButton = {
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
        btn.addTarget(self, action: #selector(scrollToBottomTapped), for: .touchUpInside)
        return btn
    }()

    var cv: UICollectionView
    private var previousViewSize: CGFloat = 0

    init(chatId: String, onReply: @escaping ((ChatMessageModel) -> Void)) {
        print("CV:Controller:init")
        self.chatId = chatId
        self.onReply = onReply
        self.cv = UICollectionView(
            frame: .zero, collectionViewLayout: ChatMessagesCollectionViewLayout())
        self.cv.contentInset = UIEdgeInsets(
            top: Self.padding, left: Self.padding, bottom: Self.padding, right: Self.padding)
        super.init(nibName: nil, bundle: nil)
        startObservation()
        //
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Track if the user is currently near the bottom of the chat
        // We use a threshold (e.g., 100 points) to allow some tolerance
        let distFromBottom = distanceFromBottom(
            minY: scrollView.contentOffset.y,
            viewSize: scrollView.bounds.height,
            contentSize: scrollView.contentSize.height
        )
        isNearBottom = distFromBottom < 1

        // Show button if more than 30pt from bottom
        let shouldShowButton = distFromBottom > 30
        if scrollToBottomButton.isHidden == shouldShowButton {
            UIView.animate(withDuration: 0.2) {
                self.scrollToBottomButton.isHidden = !shouldShowButton
                self.scrollToBottomButton.alpha = shouldShowButton ? 1.0 : 0.0
            }
        }

        if isFetchingNextPage || !isCurrentPageFull() { return }
        let distanceFromVisualTop = scrollView.contentOffset.y + scrollView.adjustedContentInset.top

        if distanceFromVisualTop < Self.loadNewMessagesThreshold {
            nextPage()
        }
    }
    deinit {
        cancellable?.cancel()
    }

    override func viewDidLoad() {
        print("CV:Controller:viewDidLoad")
        super.viewDidLoad()

        // Collection view
        cv.delegate = self
        cv.register(TextCell.self, forCellWithReuseIdentifier: TextCell.identifier)
        cv.register(DateBadgeCell.self, forCellWithReuseIdentifier: DateBadgeCell.identifier)
        cv.alwaysBounceVertical = true
        cv.keyboardDismissMode = .interactive
        view.addSubview(cv)

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        cv.addGestureRecognizer(tap)

        cv.snp.makeConstraints {
            $0.top.leading.trailing.equalTo(view)
            $0.bottom.equalTo(view.keyboardLayoutGuide.snp.top)
        }

        view.addSubview(scrollToBottomButton)
        scrollToBottomButton.snp.makeConstraints {
            $0.trailing.equalTo(view).offset(-20)
            $0.bottom.equalTo(view.keyboardLayoutGuide.snp.top).offset(-20)
            $0.width.height.equalTo(40)
        }
        //
    }

    @objc func scrollToBottomTapped() {
        let noOfItems = cv.numberOfItems(inSection: 0)
        guard noOfItems >= 0 else { return }
        cv.scrollToItem(at: (noOfItems - 1).idxPath(), at: .bottom, animated: true)
    }

    @objc func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    func distanceFromBottom(minY: CGFloat, viewSize: CGFloat, contentSize: CGFloat) -> CGFloat {
        let insetBottom = cv.adjustedContentInset.bottom
        let maxY = minY + viewSize
        return (contentSize - maxY) + insetBottom
    }

    func preserveBottomOffset() {
        // When keyboard appears we need to preserve bottom offset of scroll
        let newViewSize = cv.bounds.height
        defer {
            // Update the stored height for next pass
            previousViewSize = newViewSize
        }
        // If no change skip
        guard newViewSize > 0, newViewSize != previousViewSize else { return }

        // Don't adjust offset programmatically if the user is actively dragging
        // (e.g., during an interactive keyboard dismiss)
        guard !cv.isDragging && !cv.isTracking else { return }

        let contentSize = cv.contentSize.height
        let minY = cv.contentOffset.y

        let oldDistanceFromBottom =
            distanceFromBottom(minY: minY, viewSize: previousViewSize, contentSize: contentSize)

        let newDistanceFromBottom =
            distanceFromBottom(minY: minY, viewSize: newViewSize, contentSize: contentSize)

        // When keyboard is on the bottom will shift up
        let changeInDistanceFromBottom = oldDistanceFromBottom - newDistanceFromBottom

        // Skip no change or positive change (when keyboard goes down)
        if changeInDistanceFromBottom == 0 || newDistanceFromBottom < 1 {
            return
        }

        // push minY up so bottom is still visible at same place
        let newMinY = minY - changeInDistanceFromBottom

        cv.setContentOffset(
            CGPoint(x: cv.contentOffset.x, y: newMinY), animated: false)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        preserveBottomOffset()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func scrollViewDidChangeAdjustedContentInset(_ scrollView: UIScrollView) {
        print("scrollViewDidChangeAdjustedContentInset: \(scrollView.adjustedContentInset)")
    }

    func scrollToMessage(_ msg: ChatMessageModel?) {
        guard let msg else { return }

        // Check if the message is already loaded
        if let index = dataSource.snapshot().itemIdentifiers.firstIndex(where: {
            if case .text(let m) = $0 {
                return m.message.internalId == msg.internalId
            }
            return false
        }) {
            let indexPath = IndexPath(item: index, section: 0)
            cv.scrollToItem(at: indexPath, at: .centeredVertically, animated: true)

            self.highlightMessageId = msg.internalId
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if let cell = self.cv.cellForItem(at: indexPath) as? TextCell {
                    if self.highlightMessageId == msg.internalId {
                        cell.highlight()
                        self.highlightMessageId = nil
                    }
                }
            }
            return
        }

        // If not loaded, we need to find its position in the database to load enough pages
        Task {
            do {
                let position = try await database.read { db in
                    try ChatMessageModel
                        .where { $0.chatId.eq(self.chatId) && $0.timestamp.gte(msg.timestamp) }
                        .fetchCount(db)
                }

                let requiredPage = Int(ceil(Double(position) / Double(Self.limit)))
                if requiredPage > self.page {
                    self.page = requiredPage
                    self.targetScrollMessageId = msg.internalId
                    self.startObservation()
                }
            } catch {
                print("Failed to find message position: \(error)")
            }
        }
    }
}

struct ChatMessages: UIViewControllerRepresentable {
    let chatId: String
    var onReply: ((ChatMessageModel) -> Void)
    func updateUIViewController(_ uiViewController: ChatMessagesVC, context: Context) {
        uiViewController.onReply = onReply
    }

    func makeUIViewController(context: Context) -> ChatMessagesVC {
        let vc = ChatMessagesVC(chatId: chatId, onReply: onReply)
        return vc
    }
}
