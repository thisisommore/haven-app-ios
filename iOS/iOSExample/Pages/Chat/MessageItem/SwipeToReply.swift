//
//  SwipeToReply.swift
//  iOSExample
//

import SwiftUI

/// A ViewModifier that adds a horizontal swipe-to-reply gesture to any view.
/// Mimics the iMessage / WhatsApp pattern: drag right to reveal a reply arrow,
/// haptic fires at threshold, releasing past threshold triggers the action.
struct SwipeToReplyModifier: ViewModifier {
    let onReply: () -> Void

    private enum DragAxis {
        case undecided
        case horizontal
        case vertical
    }

    // How far (pt) the user must drag before the action triggers
    private let triggerThreshold: CGFloat = 60
    // Maximum allowed drag distance (prevents over-swiping)
    private let maxDrag: CGFloat = 100

    @State private var dragOffset: CGFloat = 0
    @State private var hasTriggeredHaptic = false
    @State private var dragAxis: DragAxis = .undecided

    /// 0…1 progress toward trigger
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
        .simultaneousGesture(
            DragGesture(minimumDistance: 12, coordinateSpace: .local)
                .onChanged { value in
                    if dragAxis == .undecided {
                        let absX = abs(value.translation.width)
                        let absY = abs(value.translation.height)
                        if absX > 4 || absY > 4 {
                            dragAxis = absX > absY ? .horizontal : .vertical
                        }
                    }

                    guard dragAxis == .horizontal else { return }
                    let horizontal = value.translation.width
                    // Only allow rightward swipe
                    guard horizontal > 0 else { return }
                    // Apply rubber-band beyond max
                    if horizontal > maxDrag {
                        dragOffset = maxDrag + (horizontal - maxDrag) * 0.2
                    } else {
                        dragOffset = horizontal
                    }
                    // Haptic when crossing threshold
                    if dragOffset >= triggerThreshold && !hasTriggeredHaptic {
                        hasTriggeredHaptic = true
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    }
                }
                .onEnded { _ in
                    if dragAxis == .horizontal, dragOffset >= triggerThreshold {
                        onReply()
                    }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        dragOffset = 0
                    }
                    hasTriggeredHaptic = false
                    dragAxis = .undecided
                }
        )
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

extension View {
    /// Attach a swipe-to-reply gesture.
    func swipeToReply(onReply: @escaping () -> Void) -> some View {
        modifier(SwipeToReplyModifier(onReply: onReply))
    }
}
