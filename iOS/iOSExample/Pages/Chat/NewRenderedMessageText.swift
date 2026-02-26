import SwiftUI
import UIKit

struct NewRenderedMessageText: View {
    private let renderedText: NewMessageRenderableText
    private let fontSize: CGFloat
    private let textColor: Color
    private let linkColor: Color
    private let lineLimit: Int?

    init(
        message: ChatMessageModel,
        textColor: Color,
        linkColor: Color,
        fontSize: CGFloat = 16,
        lineLimit: Int? = nil
    ) {
        renderedText = NewMessageRenderCache.shared.renderedText(
            for: message,
            baseFontSize: fontSize,
            baseColor: UIColor(textColor)
        )
        self.fontSize = fontSize
        self.textColor = textColor
        self.linkColor = linkColor
        self.lineLimit = lineLimit
    }

    init(
        rawHTML: String,
        isIncoming: Bool,
        textColor: Color,
        linkColor: Color,
        fontSize: CGFloat = 16,
        lineLimit: Int? = nil
    ) {
        renderedText = NewMessageRenderCache.shared.renderedText(
            fromRawHTML: rawHTML,
            isIncoming: isIncoming,
            baseFontSize: fontSize,
            baseColor: UIColor(textColor)
        )
        self.fontSize = fontSize
        self.textColor = textColor
        self.linkColor = linkColor
        self.lineLimit = lineLimit
    }

    @ViewBuilder
    var body: some View {
        switch renderedText {
        case let .plain(text):
            Text(verbatim: text)
                .font(.system(size: fontSize))
                .foregroundStyle(textColor)
                .tint(linkColor)
                .lineLimit(lineLimit)
        case let .rich(attributed):
            Text(attributed)
                .font(.system(size: fontSize))
                .foregroundStyle(textColor)
                .tint(linkColor)
                .lineLimit(lineLimit)
        }
    }
}
