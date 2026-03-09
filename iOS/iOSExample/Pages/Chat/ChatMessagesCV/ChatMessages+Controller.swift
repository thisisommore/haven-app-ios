//
//  ChatMessagesCV.swift
//  iOSExample
//
//  Created by Om More on 07/03/26.
//

import GRDB
import SQLiteData
import SwiftUI
import UIKit

class ChatMessagesVC: UIViewController {

    // Data
    // DataSource
    typealias Section = Int
    // store this since cv.dataSource is weak
    lazy var dataSource: DataSource = makeDataSource()

    // Database
    @Dependency(\.defaultDatabase) var database
    nonisolated static let limit = 40
    var initDataDone = false
    var messages: [ChatMessageModel] = []
    var cancellable: AnyDatabaseCancellable?
    //

    var cv: UICollectionView

    init(chatId: String) {
        print("CV:Controller:init")

        self.cv = UICollectionView(
            frame: .zero, collectionViewLayout: ChatMessagesCollectionViewLayout())

        super.init(nibName: nil, bundle: nil)

        // Data obervation and initialization
        let observation = ValueObservation.tracking { db in
            try ChatMessageModel.where { $0.chatId.eq(chatId) }.order {
                $0.timestamp.desc()
            }
            .limit(Self.limit).fetchAll(db)
        }

        cancellable = observation.start(in: self.database, scheduling: .immediate) { error in
            // Handle error
        } onChange: { (_messages: [ChatMessageModel]) in
            self.messages = _messages
            var snapshot = NSDiffableDataSourceSnapshot<Section, ChatMessageModel>()
            snapshot.appendSections([0])
            snapshot.appendItems(_messages)
            if self.initDataDone {
                // Calculates differences and applies them
                self.dataSource.apply(snapshot, animatingDifferences: false)
            } else {
                // Faster for init data
                self.dataSource.applySnapshotUsingReloadData(snapshot)
            }
        }
        //
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
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.alwaysBounceVertical = true
        view.addSubview(cv)
        NSLayoutConstraint.activate([
            cv.topAnchor.constraint(equalTo: view.topAnchor),
            cv.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cv.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cv.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
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
