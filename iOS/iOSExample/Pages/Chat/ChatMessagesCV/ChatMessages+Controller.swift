//
//  ChatMessagesCV.swift
//  iOSExample
//
//  Created by Om More on 07/03/26.
//

import SQLiteData
import SwiftUI
import UIKit

class ChatMessagesVC: UIViewController {
    @Dependency(\.defaultDatabase) var database
    nonisolated static let limit = 40
    var cv: UICollectionView
    var messages: [ChatMessageModel] = []
    init(chatId: String) {
        print("CV:Controller:init")

        self.cv = UICollectionView(
            frame: .zero, collectionViewLayout: ChatMessagesCollectionViewLayout())
        super.init(nibName: nil, bundle: nil)
        print("task schduled")

        Task.detached {
            print("inside task")
            let _messages = try! await self.database.read { db in
                try ChatMessageModel.where { $0.chatId.eq(chatId) }.order { $0.timestamp.desc() }
                    .limit(Self.limit).fetchAll(db)
            }
            await MainActor.run {
                self.messages = _messages
                self.cv.reloadData()
            }
        }

        print("after task")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        print("CV:Controller:viewDidLoad")
        super.viewDidLoad()
        var config = UICollectionLayoutListConfiguration(appearance: .plain)
        config.showsSeparators = false
        cv.dataSource = self
        cv.delegate = self
        cv.register(TextCell.self, forCellWithReuseIdentifier: TextCell.identifier)
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.alwaysBounceVertical = true
        view.addSubview(cv)
        NSLayoutConstraint.activate([
            cv.topAnchor.constraint(equalTo: view.topAnchor),
            cv.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cv.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cv.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    override func viewDidLayoutSubviews() {
        print("CV:Controller:viewDidLayoutSubviews")
        // let last = IndexPath(item: self.messages.count - 1, section: 0)
        // cv.scrollToItem(at: last, at: .bottom, animated: false)
    }

    override func viewSafeAreaInsetsDidChange() {
        print("CV:Controller:viewSafeAreaInsetsDidChange")
        super.viewSafeAreaInsetsDidChange()
    }

}

struct ChatMessages: UIViewControllerRepresentable {
    let chatId: String
    func updateUIViewController(_ uiViewController: ChatMessagesVC, context: Context) {

    }

    func makeUIViewController(context: Context) -> ChatMessagesVC {
        ChatMessagesVC(chatId: chatId)
    }

}
