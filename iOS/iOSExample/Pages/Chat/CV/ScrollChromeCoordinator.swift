//
//  ScrollChromeCoordinator.swift
//  iOSExample
//
//  Created by Cursor on 06/03/26.
//

import SwiftUI
import UIKit

final class ScrollChromeCoordinator: NSObject {
  private static let jumpButtonBottomSpacing: CGFloat = 16
  private static let jumpButtonTrailingSpacing: CGFloat = 16
  private static let floatingDateCurrentYearFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEE d MMM"
    return formatter
  }()
  private static let floatingDateWithYearFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEE d MMM yyyy"
    return formatter
  }()

  private weak var collectionView: UICollectionView?
  private weak var containerView: UIView?
  private var onJumpToBottom: (() -> Void)?
  private var isNearBottomProvider: (() -> Bool)?

  private let jumpToBottomButton = UIButton(type: .system)
  private var isJumpToBottomButtonVisible = false
  private let floatingDateBadge = UIView()
  private let floatingDateLabel = UILabel()
  private var floatingDateHideWorkItem: DispatchWorkItem?
  private var floatingDateValue: String?
  private var didSetup = false

  init(collectionView: UICollectionView) {
    self.collectionView = collectionView
    super.init()
  }

  func setup(
    in view: UIView,
    onJumpToBottom: @escaping () -> Void,
    isNearBottom: @escaping () -> Bool
  ) {
    guard !didSetup else { return }
    didSetup = true
    containerView = view
    self.onJumpToBottom = onJumpToBottom
    isNearBottomProvider = isNearBottom
    setupJumpToBottomButton()
    setupFloatingDateBadge()
  }

  func cleanup() {
    floatingDateHideWorkItem?.cancel()
    floatingDateHideWorkItem = nil
  }

  func updateJumpToBottomButtonVisibility(isNearBottom: Bool, animated: Bool) {
    guard let collectionView else { return }
    let visibleHeight =
      collectionView.bounds.height - collectionView.adjustedContentInset.top
      - collectionView.adjustedContentInset.bottom
    let isScrollable = collectionView.contentSize.height > max(visibleHeight, 0) + 1
    let shouldShow = isScrollable && !isNearBottom

    guard shouldShow != isJumpToBottomButtonVisible else { return }
    isJumpToBottomButtonVisible = shouldShow

    if shouldShow {
      jumpToBottomButton.isHidden = false
    }

    let animations = {
      self.jumpToBottomButton.alpha = shouldShow ? 1 : 0
      self.jumpToBottomButton.transform =
        shouldShow ? .identity : CGAffineTransform(scaleX: 0.92, y: 0.92)
    }

    let completion: (Bool) -> Void = { _ in
      if !shouldShow {
        self.jumpToBottomButton.isHidden = true
      }
    }

    if animated {
      UIView.animate(withDuration: 0.2, animations: animations, completion: completion)
    } else {
      animations()
      completion(true)
    }
  }

  func updateFloatingDateBadge(date: Date?) {
    guard let date else { return }
    let dateKey = dateSeparatorKey(for: date)
    if floatingDateValue != dateKey {
      floatingDateLabel.text = floatingDateText(for: date)
      floatingDateValue = dateKey
    }

    if floatingDateBadge.alpha < 1 {
      UIView.animate(withDuration: 0.15) {
        self.floatingDateBadge.alpha = 1
      }
    }

    floatingDateHideWorkItem?.cancel()
    let hideWorkItem = DispatchWorkItem { [weak self] in
      self?.hideFloatingDateBadge()
    }
    floatingDateHideWorkItem = hideWorkItem
    DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: hideWorkItem)
  }

  private func setupJumpToBottomButton() {
    guard let containerView else { return }
    var config = UIButton.Configuration.plain()
    config.image = UIImage(systemName: "arrow.down")
    config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
    config.baseForegroundColor = .white
    jumpToBottomButton.configuration = config
    jumpToBottomButton.translatesAutoresizingMaskIntoConstraints = false
    jumpToBottomButton.isHidden = true
    jumpToBottomButton.alpha = 0
    jumpToBottomButton.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
    jumpToBottomButton.backgroundColor = UIColor(named: "Haven") ?? UIColor(Color.haven)
    jumpToBottomButton.layer.cornerRadius = 20
    jumpToBottomButton.layer.masksToBounds = true
    jumpToBottomButton.addTarget(self, action: #selector(didTapJumpToBottom), for: .touchUpInside)

    containerView.addSubview(jumpToBottomButton)
    NSLayoutConstraint.activate([
      jumpToBottomButton.trailingAnchor.constraint(
        equalTo: containerView.safeAreaLayoutGuide.trailingAnchor,
        constant: -Self.jumpButtonTrailingSpacing
      ),
      jumpToBottomButton.bottomAnchor.constraint(
        equalTo: containerView.safeAreaLayoutGuide.bottomAnchor,
        constant: -Self.jumpButtonBottomSpacing
      ),
    ])
  }

  private func setupFloatingDateBadge() {
    guard let containerView else { return }
    floatingDateBadge.translatesAutoresizingMaskIntoConstraints = false
    floatingDateBadge.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.9)
    floatingDateBadge.layer.cornerRadius = 14
    floatingDateBadge.layer.masksToBounds = true
    floatingDateBadge.alpha = 0

    floatingDateLabel.translatesAutoresizingMaskIntoConstraints = false
    floatingDateLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
    floatingDateLabel.textColor = UIColor.secondaryLabel
    floatingDateLabel.numberOfLines = 1

    floatingDateBadge.addSubview(floatingDateLabel)
    containerView.addSubview(floatingDateBadge)

    NSLayoutConstraint.activate([
      floatingDateBadge.topAnchor.constraint(
        equalTo: containerView.safeAreaLayoutGuide.topAnchor, constant: 8),
      floatingDateBadge.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
      floatingDateLabel.topAnchor.constraint(equalTo: floatingDateBadge.topAnchor, constant: 6),
      floatingDateLabel.bottomAnchor.constraint(
        equalTo: floatingDateBadge.bottomAnchor, constant: -6),
      floatingDateLabel.leadingAnchor.constraint(
        equalTo: floatingDateBadge.leadingAnchor, constant: 12),
      floatingDateLabel.trailingAnchor.constraint(
        equalTo: floatingDateBadge.trailingAnchor, constant: -12),
    ])
  }

  private func dateSeparatorKey(for date: Date) -> String {
    String(Int(Calendar.current.startOfDay(for: date).timeIntervalSince1970))
  }

  private func floatingDateText(for date: Date) -> String {
    let calendar = Calendar.current
    if calendar.isDateInToday(date) {
      return "Today"
    }
    if calendar.isDateInYesterday(date) {
      return "Yesterday"
    }
    if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
      return Self.floatingDateCurrentYearFormatter.string(from: date)
    }
    return Self.floatingDateWithYearFormatter.string(from: date)
  }

  private func hideFloatingDateBadge() {
    UIView.animate(withDuration: 0.2) {
      self.floatingDateBadge.alpha = 0
    }
  }

  @objc
  private func didTapJumpToBottom() {
    onJumpToBottom?()
    updateJumpToBottomButtonVisibility(
      isNearBottom: isNearBottomProvider?() ?? true,
      animated: true
    )
  }
}
