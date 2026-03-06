//
//  SwipeReplyInteractionCoordinator.swift
//  iOSExample
//
//  Created by Cursor on 06/03/26.
//

import SwiftUI
import UIKit

final class SwipeReplyInteractionCoordinator: NSObject {
  private static let triggerThreshold: CGFloat = 60
  private static let indicatorSize: CGFloat = 36
  private static let indicatorIconSize: CGFloat = 16

  private weak var collectionView: UICollectionView?
  private weak var gestureDelegate: UIGestureRecognizerDelegate?
  private let messageAtIndexPath: (IndexPath) -> ChatMessageModel?
  private let onReplyMessage: (ChatMessageModel) -> Void

  private let swipeReplyIndicatorView = UIView()
  private let swipeReplyIndicatorImageView = UIImageView()
  private let swipeReplyHaptic = UIImpactFeedbackGenerator(style: .medium)
  private weak var activeSwipeCell: UICollectionViewCell?
  private var activeSwipeMessage: ChatMessageModel?
  private var hasTriggeredSwipeReplyHaptic = false
  private var swipeReplyIndicatorIsArmed = false
  private weak var panGesture: UIPanGestureRecognizer?

  init(
    collectionView: UICollectionView,
    gestureDelegate: UIGestureRecognizerDelegate,
    messageAtIndexPath: @escaping (IndexPath) -> ChatMessageModel?,
    onReplyMessage: @escaping (ChatMessageModel) -> Void
  ) {
    self.collectionView = collectionView
    self.gestureDelegate = gestureDelegate
    self.messageAtIndexPath = messageAtIndexPath
    self.onReplyMessage = onReplyMessage
    super.init()
  }

  func setup() {
    guard let collectionView else { return }
    guard panGesture == nil else { return }

    let havenColor = UIColor(named: "Haven") ?? UIColor(Color.haven)
    swipeReplyIndicatorView.translatesAutoresizingMaskIntoConstraints = true
    swipeReplyIndicatorView.isUserInteractionEnabled = false
    swipeReplyIndicatorView.alpha = 0
    swipeReplyIndicatorView.backgroundColor = havenColor.withAlphaComponent(0.12)
    swipeReplyIndicatorView.layer.cornerRadius = Self.indicatorSize / 2
    swipeReplyIndicatorView.layer.masksToBounds = true
    swipeReplyIndicatorView.layer.borderWidth = 1
    swipeReplyIndicatorView.layer.borderColor = havenColor.withAlphaComponent(0.25).cgColor

    swipeReplyIndicatorImageView.translatesAutoresizingMaskIntoConstraints = false
    swipeReplyIndicatorImageView.contentMode = .scaleAspectFit
    swipeReplyIndicatorImageView.tintColor = havenColor
    swipeReplyIndicatorImageView.image = UIImage(systemName: "arrowshape.turn.up.left.fill")

    swipeReplyIndicatorView.addSubview(swipeReplyIndicatorImageView)
    NSLayoutConstraint.activate([
      swipeReplyIndicatorImageView.centerXAnchor.constraint(
        equalTo: swipeReplyIndicatorView.centerXAnchor),
      swipeReplyIndicatorImageView.centerYAnchor.constraint(
        equalTo: swipeReplyIndicatorView.centerYAnchor),
      swipeReplyIndicatorImageView.widthAnchor.constraint(
        equalToConstant: Self.indicatorIconSize),
      swipeReplyIndicatorImageView.heightAnchor.constraint(
        equalToConstant: Self.indicatorIconSize),
    ])

    collectionView.addSubview(swipeReplyIndicatorView)
    collectionView.sendSubviewToBack(swipeReplyIndicatorView)

    let recognizer = UIPanGestureRecognizer(target: self, action: #selector(handleSwipeToReplyPan(_:)))
    recognizer.delegate = gestureDelegate
    recognizer.cancelsTouchesInView = false
    collectionView.addGestureRecognizer(recognizer)
    panGesture = recognizer
  }

  func endInteraction(triggerReply: Bool, animated: Bool) {
    guard collectionView != nil else { return }
    let message = activeSwipeMessage
    let cell = activeSwipeCell

    let cleanup = { [weak self] in
      guard let self else { return }
      self.activeSwipeCell = nil
      self.activeSwipeMessage = nil
      self.hasTriggeredSwipeReplyHaptic = false
      self.setSwipeReplyIndicatorArmed(false)
      self.swipeReplyIndicatorImageView.transform = .identity
      if triggerReply, let message {
        self.onReplyMessage(message)
      }
    }

    if animated {
      UIView.animate(
        withDuration: 0.25,
        delay: 0,
        usingSpringWithDamping: 0.75,
        initialSpringVelocity: 0,
        options: [.allowUserInteraction, .beginFromCurrentState],
        animations: {
          cell?.contentView.frame.origin.x = 0
          self.swipeReplyIndicatorView.alpha = 0
          if let cell {
            let indicatorX = cell.frame.minX - Self.indicatorSize - 8
            self.swipeReplyIndicatorView.frame.origin.x = indicatorX
          }
        }
      ) { _ in
        self.collectionView?.sendSubviewToBack(self.swipeReplyIndicatorView)
        cleanup()
      }
    } else {
      cell?.contentView.frame.origin.x = 0
      swipeReplyIndicatorView.alpha = 0
      collectionView?.sendSubviewToBack(swipeReplyIndicatorView)
      cleanup()
    }
  }

  func isSwipeGesture(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    gestureRecognizer === panGesture
  }

  func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    guard isSwipeGesture(gestureRecognizer),
      let pan = gestureRecognizer as? UIPanGestureRecognizer,
      let collectionView
    else {
      return true
    }

    let velocity = pan.velocity(in: collectionView)
    let shouldBeginHorizontalSwipe: Bool
    if velocity == .zero {
      let translation = pan.translation(in: collectionView)
      shouldBeginHorizontalSwipe =
        translation.x > 0 && abs(translation.x) > abs(translation.y) * 1.1
    } else {
      shouldBeginHorizontalSwipe = velocity.x > 0 && abs(velocity.x) > abs(velocity.y) * 1.1
    }
    guard shouldBeginHorizontalSwipe else { return false }

    let location = pan.location(in: collectionView)
    guard let indexPath = collectionView.indexPathForItem(at: location),
      messageAtIndexPath(indexPath) != nil
    else {
      return false
    }
    return true
  }

  func shouldRecognizeSimultaneously(
    _ gestureRecognizer: UIGestureRecognizer,
    with otherGestureRecognizer: UIGestureRecognizer
  ) -> Bool {
    guard isSwipeGesture(gestureRecognizer) else { return true }
    _ = otherGestureRecognizer
    return false
  }

  private func beginSwipeToReply(at location: CGPoint) -> Bool {
    guard let collectionView,
      let indexPath = collectionView.indexPathForItem(at: location),
      let message = messageAtIndexPath(indexPath),
      let cell = collectionView.cellForItem(at: indexPath)
    else {
      return false
    }

    activeSwipeCell = cell
    activeSwipeMessage = message
    hasTriggeredSwipeReplyHaptic = false
    setSwipeReplyIndicatorArmed(false)
    swipeReplyHaptic.prepare()
    updateSwipeToReply(translationX: 0)
    return true
  }

  private func setSwipeReplyIndicatorArmed(_ isArmed: Bool) {
    guard swipeReplyIndicatorIsArmed != isArmed else { return }
    swipeReplyIndicatorIsArmed = isArmed

    let havenColor = UIColor(named: "Haven") ?? UIColor(Color.haven)
    swipeReplyIndicatorView.backgroundColor = havenColor.withAlphaComponent(isArmed ? 0.22 : 0.12)
    swipeReplyIndicatorView.layer.borderColor =
      havenColor.withAlphaComponent(isArmed ? 0.55 : 0.25).cgColor
  }

  private func updateSwipeToReply(translationX: CGFloat) {
    guard let collectionView, let cell = activeSwipeCell else { return }

    var alpha = max(translationX, 0)
    let threshold = Self.triggerThreshold

    if alpha > threshold {
      let overflow = alpha - threshold
      alpha = threshold + overflow / 4
    }

    let fastOffset = alpha
    let slowOffset = alpha / 8

    cell.contentView.frame.origin.x = fastOffset

    let cellCurrentX = cell.frame.minX + fastOffset
    let indicatorX = cellCurrentX - Self.indicatorSize - 8 + slowOffset

    swipeReplyIndicatorView.frame = CGRect(
      x: indicatorX,
      y: cell.frame.minY + (cell.frame.height - Self.indicatorSize) / 2,
      width: Self.indicatorSize,
      height: Self.indicatorSize
    )
    swipeReplyIndicatorView.alpha = min(alpha / (threshold * 0.5), 1.0)

    collectionView.bringSubviewToFront(swipeReplyIndicatorView)

    let isPastThreshold = translationX >= threshold
    setSwipeReplyIndicatorArmed(isPastThreshold)
    if isPastThreshold, !hasTriggeredSwipeReplyHaptic {
      hasTriggeredSwipeReplyHaptic = true
      swipeReplyHaptic.impactOccurred()

      UIView.animate(
        withDuration: 0.2, delay: 0,
        usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8,
        options: [.allowUserInteraction, .beginFromCurrentState]
      ) {
        self.swipeReplyIndicatorImageView.transform = CGAffineTransform(scaleX: 1.16, y: 1.16)
      }
    } else if !isPastThreshold, hasTriggeredSwipeReplyHaptic {
      hasTriggeredSwipeReplyHaptic = false
      UIView.animate(
        withDuration: 0.2, delay: 0,
        usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8,
        options: [.allowUserInteraction, .beginFromCurrentState]
      ) {
        self.swipeReplyIndicatorImageView.transform = .identity
      }
    }
  }

  @objc
  private func handleSwipeToReplyPan(_ gesture: UIPanGestureRecognizer) {
    guard collectionView != nil else { return }
    let translationX = max(gesture.translation(in: collectionView).x, 0)

    switch gesture.state {
    case .began:
      _ = beginSwipeToReply(at: gesture.location(in: collectionView))
    case .changed:
      updateSwipeToReply(translationX: translationX)
    case .ended:
      let shouldReply = translationX >= Self.triggerThreshold
      endInteraction(triggerReply: shouldReply, animated: true)
    case .cancelled, .failed:
      endInteraction(triggerReply: false, animated: true)
    default:
      break
    }
  }
}
