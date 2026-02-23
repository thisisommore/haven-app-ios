//
//  SwipeToReply.swift
//  iOSExample
//

import SwiftUI
import UIKit

/// A ViewModifier that adds a horizontal swipe-to-reply gesture to any view.
/// Mimics the iMessage / WhatsApp pattern: drag right to reveal a reply arrow,
/// haptic fires at threshold, releasing past threshold triggers the action.
struct SwipeToReplyModifier: ViewModifier {
    let onReply: () -> Void

    // How far (pt) the user must drag before the action triggers
    private let triggerThreshold: CGFloat = 60
    // Maximum allowed drag distance (prevents over-swiping)
    private let maxDrag: CGFloat = 100

    @State private var dragOffset: CGFloat = 0
    @State private var hasTriggeredHaptic = false

    /// 0...1 progress toward trigger
    private var progress: CGFloat {
        min(dragOffset / triggerThreshold, 1)
    }

    func body(content: Content) -> some View {
        ZStack(alignment: .leading) {
            // Reply indicator (sits behind the message)
            replyIndicator
                .frame(width: 36, height: 36)
                .offset(x: max(dragOffset - 44, -44))
                .opacity(Double(progress))

            content
                .offset(x: dragOffset)
        }
        .overlay(alignment: .center) {
            SwipeToReplyPanOverlay(
                onChanged: { translationX in
                    let horizontal = max(translationX, 0)
                    guard horizontal > 0 else { return }

                    if horizontal > maxDrag {
                        dragOffset = maxDrag + (horizontal - maxDrag) * 0.2
                    } else {
                        dragOffset = horizontal
                    }

                    if dragOffset >= triggerThreshold, !hasTriggeredHaptic {
                        hasTriggeredHaptic = true
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    }
                },
                onEnded: { translationX, cancelled in
                    if !cancelled, translationX >= triggerThreshold {
                        onReply()
                    }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        dragOffset = 0
                    }
                    hasTriggeredHaptic = false
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .allowsHitTesting(true)
        }
    }

    private var replyIndicator: some View {
        ZStack {
            Circle()
                .fill(Color.haven.opacity(0.15))
                .scaleEffect(progress)
            Image(systemName: "arrowshape.turn.up.left.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.haven)
                .scaleEffect(progress)
        }
    }
}

private struct SwipeToReplyPanOverlay: UIViewRepresentable {
    let onChanged: (CGFloat) -> Void
    let onEnded: (_ translationX: CGFloat, _ cancelled: Bool) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true
        context.coordinator.attach(to: view)
        return view
    }

    func updateUIView(_: UIView, context: Context) {
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
    }

    static func dismantleUIView(_: UIView, coordinator: Coordinator) {
        coordinator.detach()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onChanged: onChanged, onEnded: onEnded)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onChanged: (CGFloat) -> Void
        var onEnded: (_ translationX: CGFloat, _ cancelled: Bool) -> Void

        private weak var attachedView: UIView?
        private lazy var panGesture: UIPanGestureRecognizer = {
            let recognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            recognizer.delegate = self
            recognizer.cancelsTouchesInView = false
            recognizer.delaysTouchesBegan = false
            recognizer.delaysTouchesEnded = false
            return recognizer
        }()

        init(
            onChanged: @escaping (CGFloat) -> Void,
            onEnded: @escaping (_ translationX: CGFloat, _ cancelled: Bool) -> Void
        ) {
            self.onChanged = onChanged
            self.onEnded = onEnded
        }

        func attach(to view: UIView) {
            guard attachedView !== view else { return }
            attachedView?.removeGestureRecognizer(panGesture)
            view.addGestureRecognizer(panGesture)
            attachedView = view
        }

        func detach() {
            attachedView?.removeGestureRecognizer(panGesture)
            attachedView = nil
        }

        @objc
        private func handlePan(_ gesture: UIPanGestureRecognizer) {
            let translationX = max(gesture.translation(in: gesture.view).x, 0)

            switch gesture.state {
            case .began, .changed:
                onChanged(translationX)
            case .ended:
                onEnded(translationX, false)
            case .cancelled, .failed:
                onEnded(0, true)
            default:
                break
            }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer,
                  let view = pan.view
            else { return false }

            let velocity = pan.velocity(in: view)
            if velocity == .zero {
                let translation = pan.translation(in: view)
                return translation.x > 0 && abs(translation.x) > abs(translation.y) * 1.1
            }
            return velocity.x > 0 && abs(velocity.x) > abs(velocity.y) * 1.1
        }

        func gestureRecognizer(
            _: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer
        ) -> Bool {
            false
        }
    }
}

extension View {
    /// Attach a swipe-to-reply gesture.
    func swipeToReply(onReply: @escaping () -> Void) -> some View {
        modifier(SwipeToReplyModifier(onReply: onReply))
    }
}
