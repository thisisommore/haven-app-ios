//
//  FlexView.swift
//  iOSExample
//
//  Created by Om More on 19/10/25.
//
// https://medium.com/@hnsarthh/swiftui-a-view-that-creates-another-row-if-theres-not-enough-width-816728e9ab89
import SwiftUI

// A simple wrapping flow layout that places subviews in rows based on available width.
struct FlowLayout: Layout {
    var interItemSpacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache _: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity

        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let itemWidth = size.width
            let itemHeight = size.height

            // Wrap to next line if needed
            if currentRowWidth > 0
                && currentRowWidth + interItemSpacing + itemWidth > maxWidth
            {
                maxRowWidth = max(maxRowWidth, currentRowWidth)
                totalHeight += currentRowHeight + lineSpacing
                currentRowWidth = 0
                currentRowHeight = 0
            }

            // Place in current row
            if currentRowWidth == 0 {
                currentRowWidth = itemWidth
            } else {
                currentRowWidth += interItemSpacing + itemWidth
            }
            currentRowHeight = max(currentRowHeight, itemHeight)
        }

        // Add last row
        if currentRowWidth > 0 {
            maxRowWidth = max(maxRowWidth, currentRowWidth)
            totalHeight += currentRowHeight
        }

        // 🔥 THE FIX: Use min() to respect actual content width
        let finalWidth = maxWidth.isFinite ? min(maxWidth, maxRowWidth) : maxRowWidth
        return CGSize(width: finalWidth, height: totalHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal _: ProposedViewSize,
        subviews: Subviews,
        cache _: inout ()
    ) {
        let maxX = bounds.maxX
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x != bounds.minX, x + size.width > maxX {
                x = bounds.minX
                y += rowHeight + lineSpacing
                rowHeight = 0
            }

            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(size)
            )
            x += size.width + interItemSpacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct FlexibleView<Content: View>: View {
    let availableWidth: CGFloat
    let content: Content
    var interItemSpacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    init(
        availableWidth: CGFloat,
        interItemSpacing: CGFloat = 8,
        lineSpacing: CGFloat = 8,
        @ViewBuilder content: () -> Content
    ) {
        self.availableWidth = availableWidth
        self.interItemSpacing = interItemSpacing
        self.lineSpacing = lineSpacing
        self.content = content()
    }

    var body: some View {
        FlowLayout(interItemSpacing: interItemSpacing, lineSpacing: lineSpacing) {
            content
        }
        .frame(maxWidth: availableWidth, alignment: .leading)
    }
}
