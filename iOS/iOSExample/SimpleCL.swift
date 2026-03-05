import GRDB
import SwiftData
import SwiftUI
import UIKit

struct MaxChatS: UIViewControllerRepresentable {
  @EnvironmentObject private var chatStore: ChatStore
  let chatId: String
  private let limit: Int = 20

  init(chatId: String) {
    self.chatId = chatId
  }

  func makeUIViewController(context _: Context) -> Controller {
    Controller(chatId: chatId, limit: limit, chatStore: chatStore)
  }

  func updateUIViewController(_: Controller, context _: Context) {
  }

  final class Controller: UIViewController, UICollectionViewDataSource, DeletageS {
    private let chatId: String
    private let limit: Int
    private let chatStore: ChatStore
    private var messages: [ChatMessageModel] = []

    private lazy var collectionView: UICollectionView = {
      let layout = CVLayoutS(delegate: self)
      let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
      view.translatesAutoresizingMaskIntoConstraints = false
      view.dataSource = self
      view.bounces = true
      view.alwaysBounceVertical = true
      view.backgroundColor = .clear
      view.contentInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
      view.register(TextCell.self, forCellWithReuseIdentifier: TextCell.identifier)
      return view
    }()

    init(chatId: String, limit: Int, chatStore: ChatStore) {
      self.chatId = chatId
      self.limit = limit
      self.chatStore = chatStore
      super.init(nibName: nil, bundle: nil)
      messages = fetchLatestMessages()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
      super.viewDidLoad()
      view.backgroundColor = .clear
      view.addSubview(collectionView)
      NSLayoutConstraint.activate([
        collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        collectionView.topAnchor.constraint(equalTo: view.topAnchor),
        collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      ])
    }

    private func fetchLatestMessages() -> [ChatMessageModel] {
      do {
        return try chatStore.dbQueue.read { db in
          let rows =
            try ChatMessageModel
            .filter(Column("chatId") == self.chatId)
            .order(Column("timestamp").desc, Column("internalId").asc)
            .limit(self.limit)
            .fetchAll(db)
          return Array(rows.reversed())
        }
      } catch {
        AppLogger.chat.error(
          "CV3: fetch failed for chat \(self.chatId, privacy: .public): \(error.localizedDescription, privacy: .public)"
        )
        return []
      }
    }

    func getSize(at indexPath: IndexPath, width: CGFloat) -> CGRect {
      TextCell.size(width: width, message: messages[indexPath.item])
    }

    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
      messages.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath)
      -> UICollectionViewCell
    {
      let cell =
        collectionView.dequeueReusableCell(
          withReuseIdentifier: TextCell.identifier, for: indexPath)
        as! TextCell
      cell.render(message: messages[indexPath.item])
      return cell
    }
  }
}

protocol DeletageS {
  func getSize(at indexPath: IndexPath, width: CGFloat) -> CGRect
}

class CVLayoutS: UICollectionViewLayout {
  private let delegate: DeletageS
  private var cache: [UICollectionViewLayoutAttributes] = []
  private var contentHeight: CGFloat = 0

  init(delegate: DeletageS) {
    self.delegate = delegate
    super.init()
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var collectionViewContentSize: CGSize {
    guard let collectionView else { return .zero }
    let width =
      collectionView.bounds.width - collectionView.adjustedContentInset.left
      - collectionView.adjustedContentInset.right
    return CGSize(width: width, height: contentHeight)
  }

  override func prepare() {
    guard let collectionView else { return }

    cache.removeAll(keepingCapacity: true)

    let width =
      collectionView.bounds.width - collectionView.adjustedContentInset.left
      - collectionView.adjustedContentInset.right
    let spacing: CGFloat = 8
    let numberOfItems = collectionView.numberOfItems(inSection: 0)
    var y: CGFloat = 0

    for item in 0..<numberOfItems {
      let indexPath = IndexPath(item: item, section: 0)
      let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
      let size = delegate.getSize(at: indexPath, width: width)
      attributes.frame = CGRect(x: 0, y: y, width: size.width, height: size.height)
      cache.append(attributes)
      y += size.height + spacing
    }

    contentHeight = y
  }

  override func layoutAttributesForItem(at indexPath: IndexPath)
    -> UICollectionViewLayoutAttributes?
  {
    guard cache.count > indexPath.item else { return nil }
    return cache[indexPath.item]
  }

  override func layoutAttributesForElements(in _: CGRect) -> [UICollectionViewLayoutAttributes]? {
    cache
  }
}
