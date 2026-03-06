import GRDB
import SwiftData
import SwiftUI
import UIKit

struct MaxChat2: UIViewControllerRepresentable {
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

  final class Controller: UIViewController, UICollectionViewDataSource, Deletage2 {
    private let chatId: String
    private let limit: Int
    private let chatStore: ChatStore
    private var messages: [ChatMessageModel] = []
    private var messageSizes: [CGSize] = []
    private let observationQueue = DispatchQueue(
      label: "cv2.messages.observation", qos: .userInitiated)
    private var observationCancellable: DatabaseCancellable?
    private var didStartObservation = false
    private var measuredWidth: CGFloat = 0

    private lazy var collectionView: UICollectionView = {
      let layout = CVLayout2(delegate: self)
      let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
      view.translatesAutoresizingMaskIntoConstraints = false
      view.dataSource = self
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

    override func viewDidLayoutSubviews() {
      super.viewDidLayoutSubviews()
      let width =
        collectionView.bounds.width - collectionView.adjustedContentInset.left
        - collectionView.adjustedContentInset.right
      guard width > 0 else { return }

      if !didStartObservation {
        didStartObservation = true
        measuredWidth = width
        startMessagesObservation()
        return
      }

      guard abs(width - measuredWidth) > 0.5 else { return }
      measuredWidth = width
      scheduleReloadFromDatabase(width: width)
    }

    private func startMessagesObservation() {
      stopMessagesObservation()

      let observation = DatabaseRegionObservation(
        tracking: ChatMessageModel.filter(Column("chatId") == self.chatId)
      )
      
      observationCancellable = observation.start(
        in: chatStore.dbQueue,
        onError: { error in
          AppLogger.chat.error(
            "CV2: failed observation: \(error.localizedDescription, privacy: .public)"
          )
        },
        onChange: { [weak self] _ in
          self?.scheduleReloadFromDatabase()
        }
      )

      // Initial load uses the same pipeline as updates.
      scheduleReloadFromDatabase()
    }

    private func scheduleReloadFromDatabase(width: CGFloat? = nil) {
      let widthToUse = width ?? measuredWidth
      guard widthToUse > 0 else { return }

      observationQueue.async { [weak self] in
        guard let self else { return }
        let latest = self.fetchLatestMessages()
        let sizes = self.precomputeSizes(for: latest, width: widthToUse)
        DispatchQueue.main.async { [weak self] in
          guard let self else { return }
          let shouldResetInitialScrollToBottom = self.messages.isEmpty && !latest.isEmpty
          self.messages = latest
          self.messageSizes = sizes
          if shouldResetInitialScrollToBottom,
            let layout = self.collectionView.collectionViewLayout as? CVLayout2
          {
            layout.didInitialScrollToBottom = false
          }
          self.collectionView.reloadData()
        }
      }
    }

    private func precomputeSizes(for messages: [ChatMessageModel], width: CGFloat) -> [CGSize] {
      messages.map { message in
        TextCell.size(width: width, message: message).size
      }
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
          "CV2: fetch failed for chat \(self.chatId, privacy: .public): \(error.localizedDescription, privacy: .public)"
        )
        return []
      }
    }

    private func stopMessagesObservation() {
      observationCancellable?.cancel()
      observationCancellable = nil
    }

    deinit {
      stopMessagesObservation()
    }

    func getSize(at: IndexPath) -> CGSize {
      guard messageSizes.indices.contains(at.item) else { return .zero }
      return messageSizes[at.item]
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

protocol Deletage2 {
  func getSize(at: IndexPath) -> CGSize
}

class CVLayout2: UICollectionViewLayout {
  private let delegate: Deletage2
  private(set) var cache: [UICollectionViewLayoutAttributes] = []
  private(set) var contentHeight: CGFloat = 0
  var didInitialScrollToBottom = false

  init(delegate: Deletage2) {
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

    let numberOfItems = collectionView.numberOfItems(inSection: 0)
    let spacing: CGFloat = 8
    var totalContentHeight: CGFloat = 0
    var sizes: [CGSize] = []
    sizes.reserveCapacity(numberOfItems)

    for item in 0..<numberOfItems {
      let indexPath = IndexPath(item: item, section: 0)
      let size = delegate.getSize(at: indexPath)
      sizes.append(size)
      totalContentHeight += size.height + spacing
    }

    let visibleHeight =
      collectionView.bounds.height - collectionView.adjustedContentInset.top
      - collectionView.adjustedContentInset.bottom
    var y = max(0, visibleHeight - totalContentHeight)

    for item in 0..<numberOfItems {
      let indexPath = IndexPath(item: item, section: 0)
      let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
      let size = sizes[item]
      attributes.frame = CGRect(x: 0, y: y, width: size.width, height: size.height)
      cache.append(attributes)
      y += size.height + spacing
    }

    contentHeight = max(totalContentHeight, visibleHeight)

    guard collectionView.bounds.width > 0 else { return }
    if !didInitialScrollToBottom {
      scrollToBottom(in: collectionView)
      didInitialScrollToBottom = true
    }
  }

  private func scrollToBottom(in collectionView: UICollectionView) {
    let minOffsetY = -collectionView.adjustedContentInset.top
    let maxOffsetY = max(
      minOffsetY,
      contentHeight
        - collectionView.bounds.height
        + collectionView.adjustedContentInset.bottom
    )
    collectionView.setContentOffset(
      CGPoint(x: collectionView.contentOffset.x, y: maxOffsetY),
      animated: false
    )
  }

  override func layoutAttributesForItem(at indexPath: IndexPath)
    -> UICollectionViewLayoutAttributes?
  {
    guard cache.count > indexPath.item else { return nil }
    return cache[indexPath.item]
  }

  override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]?
  {
    guard !cache.isEmpty else { return [] }

    let startIndex = firstIndexWithMaxY(atLeast: rect.minY)
    guard startIndex < cache.count else { return [] }

    var visibleAttributes: [UICollectionViewLayoutAttributes] = []
    var index = startIndex
    while index < cache.count {
      let attributes = cache[index]
      if attributes.frame.minY > rect.maxY {
        break
      }
      visibleAttributes.append(attributes)
      index += 1
    }
    return visibleAttributes
  }

  private func firstIndexWithMaxY(atLeast minY: CGFloat) -> Int {
    var low = 0
    var high = cache.count

    while low < high {
      let mid = low + (high - low) / 2
      if cache[mid].frame.maxY < minY {
        low = mid + 1
      } else {
        high = mid
      }
    }
    return low
  }
}
