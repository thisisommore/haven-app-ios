//
//  TextCell+Swipe.swift
//  iOSExample
//
//  Created by Om More on 10/03/26.
//

import UIKit

extension TextCell: UIGestureRecognizerDelegate {
    func setupGesture() {
        panGesture.delegate = self
        self.addGestureRecognizer(panGesture)
    }

    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        let maxSwipeDistance: CGFloat = 70.0

        // Calculate the dragged offset (with friction)
        let dragOffset = translation.x / 1.5

        switch gesture.state {
        case .began:
            hasCrossedReplyThreshold = false
            feedbackGenerator.prepare()  // Wakes up the haptic engine so there's zero lag

        case .changed:
            // Only allow swiping to the right
            if translation.x > 0 {
                let cappedOffset = min(dragOffset, maxSwipeDistance)
                let cappedScale = max(0.6, cappedOffset / 40)
                // Move the container using transform
                container.transform = CGAffineTransform(translationX: cappedOffset, y: 0)
                replyImage.transform = CGAffineTransform(translationX: cappedOffset / 4, y: 0)
                    .scaledBy(x: cappedScale, y: cappedScale)

                // Check if we just crossed the threshold
                if dragOffset >= 60.0 && !hasCrossedReplyThreshold {
                    hasCrossedReplyThreshold = true
                    // The Haptic Pop!
                    feedbackGenerator.impactOccurred()
                } else if dragOffset < 60.0 && hasCrossedReplyThreshold {
                    // If the user drags back below the threshold before letting go, cancel the state
                    hasCrossedReplyThreshold = false
                }
            }

        case .ended, .cancelled:
            // If they let go while the threshold was crossed, trigger the reply!
            if hasCrossedReplyThreshold {
                onReply?()
            }

            // Spring EVERYTHING back to the original position
            UIView.animate(
                withDuration: 0.4,
                delay: 0,
                usingSpringWithDamping: 0.6,
                initialSpringVelocity: 0.5,
                options: .curveEaseOut,
                animations: {
                    self.container.transform = .identity  // Reset bubble position
                    self.replyImage.transform = .identity  // Reset icon scale
                },
                completion: { _ in
                    self.hasCrossedReplyThreshold = false
                })

        default:
            break
        }
    }

    // Allow the collection view to scroll vertically simultaneously
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return true
    }
}
