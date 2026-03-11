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

typealias MessageWithSender = (ChatMessageModel, String?, ChatMessageModel?)
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
                .text((let lhsMessage, let lhsSender, let lhsReplyTo)),
                .text((let rhsMessage, let rhsSender, let rhsReplyTo))
            ):
                return lhsMessage == rhsMessage && lhsSender == rhsSender
                    && lhsReplyTo == rhsReplyTo
            case (.date(let lhsDate), .date(let rhsDate)):
                return lhsDate == rhsDate
            default:
                return false
            }
        }

        func hash(into hasher: inout Hasher) {
            switch self {
            case .text((let message, let sender, let replyTo)):
                hasher.combine(0)
                hasher.combine(message)
                hasher.combine(sender)
                hasher.combine(replyTo)
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
    static let loadNewMessagesThreshold: CGFloat = 60
    static let padding: CGFloat = 8
    var page = 1
    var initDataDone = false
    var messages: [MessageWithSender] = []
    var cancellable: AnyDatabaseCancellable?
    var isNearBottom: Bool = true
    //

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
        isNearBottom =
            distanceFromBottom(
                minY: scrollView.contentOffset.y,
                viewSize: scrollView.bounds.height,
                contentSize: scrollView.contentSize.height
            ) < 1

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
        view.addSubview(cv)

        cv.snp.makeConstraints {
            $0.top.leading.trailing.equalTo(view)
            $0.bottom.equalTo(view.keyboardLayoutGuide.snp.top)
        }
        //
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
