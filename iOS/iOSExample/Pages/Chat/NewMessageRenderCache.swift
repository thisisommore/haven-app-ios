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

        let rendered = buildRenderedText(for: message)
        cache.setObject(NewMessageRenderCacheEntry(value: rendered), forKey: key)
        return rendered
    }

    func invalidate(messageId: String) {
        // NSCache does not support prefix deletes; rely on natural eviction.
        // This method exists for future explicit invalidation hooks.
        _ = messageId
    }

    private func buildRenderedText(for message: ChatMessageModel) -> NewMessageRenderableText {
        let kind = NewMessageRenderKind(rawValue: message.newRenderKindRaw) ?? .unknown

        switch kind {
        case .plain:
            return .plain(message.newRenderPlainText ?? message.message)

        case .rich:
            if let payloadData = message.newRenderPayload,
               let payload = try? decoder.decode(NewMessageParsedPayload.self, from: payloadData)
            {
                return .rich(buildAttributedString(from: payload, isIncoming: message.isIncoming))
            }
            return .plain(message.newRenderPlainText ?? message.message)

        case .unknown, .failed:
            let precomputed = NewMessageHTMLPrecomputer.precompute(rawHTML: message.message)
            if precomputed.kind == .rich,
               let payloadData = precomputed.payloadData,
               let payload = try? decoder.decode(NewMessageParsedPayload.self, from: payloadData)
            {
                return .rich(buildAttributedString(from: payload, isIncoming: message.isIncoming))
            }
            return .plain(precomputed.plainText)
        }
    }

    private func buildAttributedString(from payload: NewMessageParsedPayload, isIncoming: Bool) -> AttributedString {
        let baseFont = UIFont.systemFont(ofSize: 16)
        let baseColor = isIncoming ? UIColor(Color.messageText) : UIColor.white

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
