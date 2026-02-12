import Foundation

enum NewMessageRenderKind: Int16, Codable {
    case unknown = 0
    case plain = 1
    case rich = 2
    case failed = 3
}

enum NewMessageRenderVersion {
    static let current: Int16 = 1
}

struct NewMessageStyleBits: OptionSet, Hashable {
    let rawValue: Int

    static let bold = NewMessageStyleBits(rawValue: 1 << 0)
    static let italic = NewMessageStyleBits(rawValue: 1 << 1)
    static let strike = NewMessageStyleBits(rawValue: 1 << 2)
    static let code = NewMessageStyleBits(rawValue: 1 << 3)
    static let pre = NewMessageStyleBits(rawValue: 1 << 4)
    static let blockquote = NewMessageStyleBits(rawValue: 1 << 5)
    static let link = NewMessageStyleBits(rawValue: 1 << 6)
}

struct NewMessageSpan: Codable, Hashable {
    var startUTF16: Int
    var endUTF16: Int
    var styleBits: Int
    var href: String?
}

struct NewMessageParsedPayload: Codable, Hashable {
    var version: Int16
    var text: String
    var spans: [NewMessageSpan]
}

struct NewMessagePrecomputedRender {
    var containsMarkup: Bool
    var kind: NewMessageRenderKind
    var version: Int16
    var plainText: String
    var payloadData: Data?
}

enum NewMessageRenderPersistence {
    static func apply(_ precomputed: NewMessagePrecomputedRender, to message: ChatMessageModel) {
        message.newContainsMarkup = precomputed.containsMarkup
        message.newRenderKindRaw = precomputed.kind.rawValue
        message.newRenderVersion = precomputed.version
        message.newRenderPlainText = precomputed.plainText
        message.newRenderPayload = precomputed.payloadData
    }
}
