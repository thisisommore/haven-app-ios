
import UIKit

protocol MessageBubbleSwipeDelegate: AnyObject {
  func onSwip()
}

final class MessageBubbleSwipe: NSObject, UIGestureRecognizerDelegate {
  lazy var panGesture = UIPanGestureRecognizer(
    target: self, action: #selector(handlePan(_:))
  )
  var hasCrossedReplyThreshold = false
  let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)

  let uiView: UIView
  let delegate: MessageBubbleSwipeDelegate
  init(uiView: UIView, delegate: MessageBubbleSwipeDelegate) {
    self.uiView = uiView
    self.delegate = delegate
  }

  func setupGesture(view: UIView) {
    self.panGesture.delegate = self
    view.addGestureRecognizer(self.panGesture)
  }

  @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
    let translation = gesture.translation(in: self.uiView)
    let maxSwipeDistance: CGFloat = 70.0

    // Calculate the dragged offset (with friction)
    let dragOffset = translation.x / 1.5

    switch gesture.state {
    case .began:
      self.hasCrossedReplyThreshold = false
      self.feedbackGenerator.prepare() // Wakes up the haptic engine so there's zero lag

    case .changed:
      // Only allow swiping to the right
      if translation.x > 0 {
        let cappedOffset = min(dragOffset, maxSwipeDistance)
        // Move the container using transform
        self.uiView.transform = CGAffineTransform(translationX: cappedOffset, y: 0)

        // Check if we just crossed the threshold
        if dragOffset >= 60.0, !self.hasCrossedReplyThreshold {
          self.hasCrossedReplyThreshold = true
          // The Haptic Pop!
          self.feedbackGenerator.impactOccurred()
        } else if dragOffset < 60.0, self.hasCrossedReplyThreshold {
          // If the user drags back below the threshold before letting go, cancel the state
          self.hasCrossedReplyThreshold = false
        }
      }

    case .ended, .cancelled:
      // If they let go while the threshold was crossed, trigger the reply!
      if self.hasCrossedReplyThreshold {
        self.delegate.onSwip()
      }

      // Spring EVERYTHING back to the original position
      UIView.animate(
        withDuration: 0.4,
        delay: 0,
        usingSpringWithDamping: 0.6,
        initialSpringVelocity: 0.5,
        options: .curveEaseOut,
        animations: {
          self.uiView.transform = .identity // Reset bubble position
        },
        completion: { _ in
          self.hasCrossedReplyThreshold = false
        }
      )

    default:
      break
    }
  }

  /// Allow the collection view to scroll vertically simultaneously
  func gestureRecognizer(
    _: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer
  ) -> Bool {
    return true
  }
}
