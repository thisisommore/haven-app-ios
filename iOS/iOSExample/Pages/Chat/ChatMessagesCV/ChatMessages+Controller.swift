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

class ChatMessagesVC: UIViewController {

    // Data
    let chatId: String
    var isFetchingNextPage = true

    // DataSource
    enum Message: Hashable {
        case text(ChatMessageModel)
        case date(String)
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
    var messages: [ChatMessageModel] = []
    var cancellable: AnyDatabaseCancellable?
    //

    var cv: UICollectionView

    init(chatId: String) {
        print("CV:Controller:init")
        self.chatId = chatId
        self.cv = UICollectionView(
            frame: .zero, collectionViewLayout: ChatMessagesCollectionViewLayout())
        self.cv.contentInset = UIEdgeInsets(
            top: Self.padding, left: Self.padding, bottom: Self.padding, right: Self.padding)
        super.init(nibName: nil, bundle: nil)
        startObservation()
        //
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
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
            $0.edges.equalTo(view)
        }
        //
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}

struct ChatMessages: UIViewControllerRepresentable {
    let chatId: String
    func updateUIViewController(_ uiViewController: ChatMessagesVC, context: Context) {}

    func makeUIViewController(context: Context) -> ChatMessagesVC {
        ChatMessagesVC(chatId: chatId)
    }
}
