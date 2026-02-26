import SwiftUI
import UIKit

enum NewMessageRenderableText {
    case plain(String)
    case rich(AttributedString)
}

final class NewMessageRenderCache {
    static let shared = NewMessageRenderCache()

    private let cache = NSCache<NSString, NewMessageRenderCacheEntry>()
    private let decoder = JSONDecoder()

    private init() {
        cache.countLimit = 2000
    }

    func renderedText(for message: ChatMessageModel) -> NewMessageRenderableText {
        let key = cacheKey(for: message)
        if let cached = cache.object(forKey: key) {
            return cached.value
        }

        let rendered = buildRenderedText(
            kind: NewMessageRenderKind(rawValue: message.newRenderKindRaw) ?? .unknown,
            plainText: message.newRenderPlainText,
            payloadData: message.newRenderPayload,
            rawHTML: message.message,
            isIncoming: message.isIncoming,
            baseFontSize: 16,
            baseColorOverride: nil
        )
        cache.setObject(NewMessageRenderCacheEntry(value: rendered), forKey: key)
        return rendered
    }

    func renderedText(
        for message: ChatMessageModel,
        baseFontSize: CGFloat,
        baseColor: UIColor
    ) -> NewMessageRenderableText {
        buildRenderedText(
            kind: NewMessageRenderKind(rawValue: message.newRenderKindRaw) ?? .unknown,
            plainText: message.newRenderPlainText,
            payloadData: message.newRenderPayload,
            rawHTML: message.message,
            isIncoming: message.isIncoming,
            baseFontSize: baseFontSize,
            baseColorOverride: baseColor
        )
    }

    func renderedText(
        fromRawHTML rawHTML: String,
        isIncoming: Bool,
        baseFontSize: CGFloat,
        baseColor: UIColor
    ) -> NewMessageRenderableText {
        let precomputed = NewMessageHTMLPrecomputer.precompute(rawHTML: rawHTML)
        return buildRenderedText(
            kind: precomputed.kind,
            plainText: precomputed.plainText,
            payloadData: precomputed.payloadData,
            rawHTML: rawHTML,
            isIncoming: isIncoming,
            baseFontSize: baseFontSize,
            baseColorOverride: baseColor
        )
    }

    func invalidate(messageId: String) {
        // NSCache does not support prefix deletes; rely on natural eviction.
        // This method exists for future explicit invalidation hooks.
        _ = messageId
    }

    private func buildRenderedText(
        kind: NewMessageRenderKind,
        plainText: String?,
        payloadData: Data?,
        rawHTML: String,
        isIncoming: Bool,
        baseFontSize: CGFloat,
        baseColorOverride: UIColor?
    ) -> NewMessageRenderableText {
        let baseFont = UIFont.systemFont(ofSize: baseFontSize)
        let baseColor = baseColorOverride ?? (isIncoming ? UIColor(Color.messageText) : UIColor.white)

        switch kind {
        case .plain:
            return .plain(plainText ?? rawHTML)

        case .rich:
            if let payloadData,
               let payload = try? decoder.decode(NewMessageParsedPayload.self, from: payloadData)
            {
                return .rich(buildAttributedString(from: payload, baseFont: baseFont, baseColor: baseColor))
            }
            return .plain(plainText ?? rawHTML)

        case .unknown, .failed:
            let precomputed = NewMessageHTMLPrecomputer.precompute(rawHTML: rawHTML)
            if precomputed.kind == .rich,
               let payloadData = precomputed.payloadData,
               let payload = try? decoder.decode(NewMessageParsedPayload.self, from: payloadData)
            {
                return .rich(buildAttributedString(from: payload, baseFont: baseFont, baseColor: baseColor))
            }
            return .plain(precomputed.plainText)
        }
    }

    private func buildAttributedString(from payload: NewMessageParsedPayload, baseFont: UIFont, baseColor: UIColor) -> AttributedString {
        let mutable = NSMutableAttributedString(
            string: payload.text,
            attributes: [
                .font: baseFont,
                .foregroundColor: baseColor,
            ]
        )

        let fullLength = (payload.text as NSString).length

        for span in payload.spans {
            guard span.startUTF16 >= 0,
                  span.endUTF16 <= fullLength,
                  span.endUTF16 > span.startUTF16
            else {
                continue
            }

            let range = NSRange(location: span.startUTF16, length: span.endUTF16 - span.startUTF16)
            let bits = NewMessageStyleBits(rawValue: span.styleBits)

            var attrs: [NSAttributedString.Key: Any] = [:]

            if bits.contains(.code) || bits.contains(.pre) {
                attrs[.font] = UIFont.monospacedSystemFont(ofSize: baseFont.pointSize, weight: .regular)
            } else {
                var symbolicTraits = UIFontDescriptor.SymbolicTraits()
                if bits.contains(.bold) {
                    symbolicTraits.insert(.traitBold)
                }
                if bits.contains(.italic) {
                    symbolicTraits.insert(.traitItalic)
                }

                if !symbolicTraits.isEmpty,
                   let descriptor = baseFont.fontDescriptor.withSymbolicTraits(symbolicTraits)
                {
                    attrs[.font] = UIFont(descriptor: descriptor, size: baseFont.pointSize)
                }
            }

            if bits.contains(.strike) {
                attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            }

            if bits.contains(.blockquote) {
                attrs[.foregroundColor] = baseColor.withAlphaComponent(0.88)
            }

            if bits.contains(.link),
               let href = span.href,
               let url = URL(string: href)
            {
                attrs[.link] = url
                attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
            }

            if !attrs.isEmpty {
                mutable.addAttributes(attrs, range: range)
            }
        }

        return AttributedString(mutable)
    }

    private func cacheKey(for message: ChatMessageModel) -> NSString {
        let payloadHash = message.newRenderPayload?.hashValue ?? 0
        let plainHash = message.newRenderPlainText?.hashValue ?? 0
        return "\(message.id)|\(message.newRenderVersion)|\(message.newRenderKindRaw)|\(payloadHash)|\(plainHash)|\(message.isIncoming ? 1 : 0)" as NSString
    }
}

private final class NewMessageRenderCacheEntry: NSObject {
    let value: NewMessageRenderableText

    init(value: NewMessageRenderableText) {
        self.value = value
    }
}
