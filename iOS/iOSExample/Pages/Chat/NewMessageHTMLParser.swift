import Foundation

enum NewMessageHTMLClassifier {
    private static let tagPattern = #"<\s*/?\s*[a-zA-Z]"#
    private static let entityPattern = #"&(#\d+|#x[0-9A-Fa-f]+|[A-Za-z]{2,31});"#

    static func hasMarkup(_ text: String) -> Bool {
        text.range(of: tagPattern, options: .regularExpression) != nil
    }

    static func hasEntity(_ text: String) -> Bool {
        text.range(of: entityPattern, options: .regularExpression) != nil
    }

    static func singleParagraphPlainText(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let lower = trimmed.lowercased()
        guard lower.hasPrefix("<p"), lower.hasSuffix("</p>") else {
            return nil
        }

        guard let openEnd = trimmed.firstIndex(of: ">") else { return nil }
        let openTag = String(trimmed[..<trimmed.index(after: openEnd)]).lowercased()
        guard openTag.hasPrefix("<p") else { return nil }

        let closeStart = trimmed.index(trimmed.endIndex, offsetBy: -4)
        guard closeStart > openEnd else { return nil }

        let innerRange = trimmed.index(after: openEnd) ..< closeStart
        let inner = String(trimmed[innerRange])

        guard !inner.contains("<"), !inner.contains(">") else {
            return nil
        }

        return NewMessageHTMLEntityDecoder.decode(inner)
    }

    static func stripTagsKeepingText(_ raw: String) -> String {
        var output = ""
        var insideTag = false

        for ch in raw {
            if ch == "<" {
                insideTag = true
                continue
            }
            if ch == ">" {
                insideTag = false
                continue
            }
            if !insideTag {
                output.append(ch)
            }
        }

        return NewMessageHTMLEntityDecoder.decode(output)
    }
}

enum NewMessageHTMLPrecomputer {
    static func precompute(rawHTML: String) -> NewMessagePrecomputedRender {
        if rawHTML.isEmpty {
            return NewMessagePrecomputedRender(
                containsMarkup: false,
                kind: .plain,
                version: NewMessageRenderVersion.current,
                plainText: "",
                payloadData: nil
            )
        }

        let hasMarkup = NewMessageHTMLClassifier.hasMarkup(rawHTML)
        let hasEntity = NewMessageHTMLClassifier.hasEntity(rawHTML)

        if !hasMarkup, !hasEntity {
            return NewMessagePrecomputedRender(
                containsMarkup: false,
                kind: .plain,
                version: NewMessageRenderVersion.current,
                plainText: rawHTML,
                payloadData: nil
            )
        }

        if let paragraphText = NewMessageHTMLClassifier.singleParagraphPlainText(rawHTML) {
            return NewMessagePrecomputedRender(
                containsMarkup: true,
                kind: .plain,
                version: NewMessageRenderVersion.current,
                plainText: paragraphText,
                payloadData: nil
            )
        }

        if !hasMarkup, hasEntity {
            return NewMessagePrecomputedRender(
                containsMarkup: true,
                kind: .plain,
                version: NewMessageRenderVersion.current,
                plainText: NewMessageHTMLEntityDecoder.decode(rawHTML),
                payloadData: nil
            )
        }

        let payload = NewMessageHTMLParser.parse(rawHTML)

        if payload.spans.isEmpty {
            return NewMessagePrecomputedRender(
                containsMarkup: true,
                kind: .plain,
                version: payload.version,
                plainText: payload.text,
                payloadData: nil
            )
        }

        if let encodedPayload = try? JSONEncoder().encode(payload) {
            return NewMessagePrecomputedRender(
                containsMarkup: true,
                kind: .rich,
                version: payload.version,
                plainText: payload.text,
                payloadData: encodedPayload
            )
        }

        return NewMessagePrecomputedRender(
            containsMarkup: true,
            kind: .failed,
            version: NewMessageRenderVersion.current,
            plainText: NewMessageHTMLClassifier.stripTagsKeepingText(rawHTML),
            payloadData: nil
        )
    }
}

enum NewMessageHTMLParser {
    static func parse(_ rawHTML: String) -> NewMessageParsedPayload {
        var state = NewMessageHTMLParserState(raw: rawHTML)
        return state.parse()
    }
}

private struct NewMessageHTMLTagToken {
    var name: String
    var isClosing: Bool
    var isSelfClosing: Bool
    var attributes: [String: String]
}

private struct NewMessageActiveTag {
    var name: String
    var style: NewMessageStyleBits
    var href: String?
}

private struct NewMessageListContext {
    var name: String
    var nextIndex: Int
}

private struct NewMessageHTMLParserState {
    let raw: String

    private var output = ""
    private var spans: [NewMessageSpan] = []
    private var activeTags: [NewMessageActiveTag] = []
    private var listStack: [NewMessageListContext] = []
    private var suppressTextDepth = 0

    init(raw: String) {
        self.raw = raw
    }

    mutating func parse() -> NewMessageParsedPayload {
        var index = raw.startIndex

        while index < raw.endIndex {
            if raw[index] == "<" {
                if raw[index...].hasPrefix("<!--") {
                    if let commentEnd = raw[index...].range(of: "-->") {
                        index = commentEnd.upperBound
                        continue
                    }
                    break
                }

                if let (token, nextIndex) = parseTag(at: index) {
                    handle(token)
                    index = nextIndex
                    continue
                }

                // Treat malformed tags as plain text and advance one character.
                appendTextChunk(String(raw[index]))
                index = raw.index(after: index)
                continue
            }

            let nextTag = raw[index...].firstIndex(of: "<") ?? raw.endIndex
            let textChunk = String(raw[index ..< nextTag])
            appendTextChunk(textChunk)
            index = nextTag
        }

        trimTrailingWhitespaceAndBreaks()

        return NewMessageParsedPayload(
            version: NewMessageRenderVersion.current,
            text: output,
            spans: spans
        )
    }

    private mutating func handle(_ token: NewMessageHTMLTagToken) {
        if token.name == "script" || token.name == "style" {
            if token.isClosing {
                suppressTextDepth = max(0, suppressTextDepth - 1)
            } else {
                suppressTextDepth += 1
            }
            return
        }

        if token.isClosing {
            handleClosing(token)
            return
        }

        switch token.name {
        case "br":
            appendNewlineIfNeeded(force: true)

        case "p":
            appendNewlineIfNeeded(force: false)
            if token.isSelfClosing {
                appendNewlineIfNeeded(force: true)
            }

        case "blockquote":
            appendNewlineIfNeeded(force: false)
            if !token.isSelfClosing {
                activeTags.append(NewMessageActiveTag(name: token.name, style: .blockquote, href: nil))
            }

        case "strong", "b":
            if !token.isSelfClosing {
                activeTags.append(NewMessageActiveTag(name: token.name, style: .bold, href: nil))
            }

        case "em", "i":
            if !token.isSelfClosing {
                activeTags.append(NewMessageActiveTag(name: token.name, style: .italic, href: nil))
            }

        case "s":
            if !token.isSelfClosing {
                activeTags.append(NewMessageActiveTag(name: token.name, style: .strike, href: nil))
            }

        case "code":
            if !token.isSelfClosing {
                activeTags.append(NewMessageActiveTag(name: token.name, style: .code, href: nil))
            }

        case "pre":
            appendNewlineIfNeeded(force: false)
            if !token.isSelfClosing {
                activeTags.append(NewMessageActiveTag(name: token.name, style: [.pre, .code], href: nil))
            }

        case "a":
            if !token.isSelfClosing {
                let href = sanitizeHref(token.attributes["href"])
                let style: NewMessageStyleBits = href == nil ? [] : .link
                activeTags.append(NewMessageActiveTag(name: token.name, style: style, href: href))
            }

        case "ul", "ol":
            appendNewlineIfNeeded(force: false)
            if !token.isSelfClosing {
                let nextIndex = token.name == "ol" ? 1 : 0
                listStack.append(NewMessageListContext(name: token.name, nextIndex: nextIndex))
            }

        case "li":
            appendNewlineIfNeeded(force: false)
            appendListPrefix()
            if token.isSelfClosing {
                appendNewlineIfNeeded(force: true)
            }

        case "span":
            break

        default:
            break
        }
    }

    private mutating func handleClosing(_ token: NewMessageHTMLTagToken) {
        switch token.name {
        case "p", "li", "pre", "blockquote", "ul", "ol":
            appendNewlineIfNeeded(force: true)

        case "strong", "b", "em", "i", "s", "code", "a":
            popLastActiveTag(named: token.name)

        default:
            break
        }

        if token.name == "blockquote" || token.name == "pre" {
            popLastActiveTag(named: token.name)
        }

        if token.name == "ul" || token.name == "ol" {
            popLastList(named: token.name)
        }
    }

    private mutating func appendListPrefix() {
        if listStack.isEmpty {
            appendStyledText("• ")
            return
        }

        let lastIndex = listStack.count - 1
        if listStack[lastIndex].name == "ol" {
            let marker = "\(listStack[lastIndex].nextIndex). "
            listStack[lastIndex].nextIndex += 1
            appendStyledText(marker)
        } else {
            appendStyledText("• ")
        }
    }

    private mutating func appendTextChunk(_ chunk: String) {
        guard suppressTextDepth == 0 else { return }
        guard !chunk.isEmpty else { return }

        let decoded = NewMessageHTMLEntityDecoder.decode(chunk)
        if decoded.isEmpty { return }

        if isInsideTag(named: "pre") {
            appendStyledText(decoded)
            return
        }

        var normalized = ""
        var pendingWhitespace = false

        for ch in decoded {
            if ch.isWhitespace {
                pendingWhitespace = true
                continue
            }

            if pendingWhitespace {
                let previous = normalized.last ?? output.last
                if let previous, previous != " ", previous != "\n" {
                    normalized.append(" ")
                }
                pendingWhitespace = false
            }

            normalized.append(ch)
        }

        appendStyledText(normalized)
    }

    private mutating func appendStyledText(_ text: String) {
        guard !text.isEmpty else { return }

        let startUTF16 = output.utf16.count
        output.append(text)
        let endUTF16 = output.utf16.count

        let activeBits = currentStyleBits()
        let activeHref = currentHref()

        var styleBits = activeBits.rawValue
        if activeHref != nil {
            styleBits |= NewMessageStyleBits.link.rawValue
        }

        guard styleBits != 0 || activeHref != nil else { return }

        if let lastIndex = spans.indices.last {
            var last = spans[lastIndex]
            if last.endUTF16 == startUTF16, last.styleBits == styleBits, last.href == activeHref {
                last.endUTF16 = endUTF16
                spans[lastIndex] = last
                return
            }
        }

        spans.append(
            NewMessageSpan(
                startUTF16: startUTF16,
                endUTF16: endUTF16,
                styleBits: styleBits,
                href: activeHref
            )
        )
    }

    private mutating func appendNewlineIfNeeded(force: Bool) {
        if output.isEmpty {
            return
        }
        if force || output.last != "\n" {
            output.append("\n")
        }
    }

    private mutating func popLastActiveTag(named name: String) {
        guard let idx = activeTags.lastIndex(where: { $0.name == name }) else { return }
        activeTags.remove(at: idx)
    }

    private mutating func popLastList(named name: String) {
        guard let idx = listStack.lastIndex(where: { $0.name == name }) else { return }
        listStack.remove(at: idx)
    }

    private func isInsideTag(named name: String) -> Bool {
        activeTags.contains(where: { $0.name == name })
    }

    private func currentStyleBits() -> NewMessageStyleBits {
        activeTags.reduce(into: NewMessageStyleBits()) { partial, tag in
            partial.formUnion(tag.style)
        }
    }

    private func currentHref() -> String? {
        activeTags.reversed().first(where: { $0.href != nil })?.href
    }

    private mutating func trimTrailingWhitespaceAndBreaks() {
        while let last = output.last, last == "\n" || last == " " || last == "\t" {
            let removedAt = output.utf16.count - 1
            output.removeLast()

            var nextSpans: [NewMessageSpan] = []
            nextSpans.reserveCapacity(spans.count)
            for span in spans {
                if span.startUTF16 >= removedAt {
                    continue
                }
                var adjusted = span
                if adjusted.endUTF16 > removedAt {
                    adjusted.endUTF16 = removedAt
                }
                if adjusted.endUTF16 > adjusted.startUTF16 {
                    nextSpans.append(adjusted)
                }
            }
            spans = nextSpans
        }
    }

    private func parseTag(at start: String.Index) -> (NewMessageHTMLTagToken, String.Index)? {
        guard let end = raw[start...].firstIndex(of: ">") else { return nil }

        var content = String(raw[raw.index(after: start) ..< end]).trimmingCharacters(in: .whitespacesAndNewlines)
        if content.isEmpty {
            return nil
        }

        if content.hasPrefix("!") || content.hasPrefix("?") {
            return nil
        }

        var isClosing = false
        if content.hasPrefix("/") {
            isClosing = true
            content.removeFirst()
            content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var isSelfClosing = false
        if content.hasSuffix("/") {
            isSelfClosing = true
            content.removeLast()
            content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard !content.isEmpty else { return nil }

        let nameEnd = content.firstIndex(where: { $0.isWhitespace }) ?? content.endIndex
        let tagName = String(content[..<nameEnd]).lowercased()
        guard !tagName.isEmpty else { return nil }

        let attributesRaw = String(content[nameEnd...])
        let attributes = parseAttributes(attributesRaw)

        let token = NewMessageHTMLTagToken(
            name: tagName,
            isClosing: isClosing,
            isSelfClosing: isSelfClosing,
            attributes: attributes
        )

        return (token, raw.index(after: end))
    }

    private func parseAttributes(_ rawAttributes: String) -> [String: String] {
        var attributes: [String: String] = [:]
        var index = rawAttributes.startIndex

        while index < rawAttributes.endIndex {
            skipSpaces(in: rawAttributes, index: &index)
            guard index < rawAttributes.endIndex else { break }

            let keyStart = index
            while index < rawAttributes.endIndex {
                let ch = rawAttributes[index]
                if ch.isWhitespace || ch == "=" {
                    break
                }
                index = rawAttributes.index(after: index)
            }

            let key = String(rawAttributes[keyStart ..< index]).lowercased()
            guard !key.isEmpty else { break }

            skipSpaces(in: rawAttributes, index: &index)

            var value = ""
            if index < rawAttributes.endIndex, rawAttributes[index] == "=" {
                index = rawAttributes.index(after: index)
                skipSpaces(in: rawAttributes, index: &index)

                if index < rawAttributes.endIndex, rawAttributes[index] == "\"" || rawAttributes[index] == "'" {
                    let quote = rawAttributes[index]
                    index = rawAttributes.index(after: index)
                    let valueStart = index
                    while index < rawAttributes.endIndex, rawAttributes[index] != quote {
                        index = rawAttributes.index(after: index)
                    }
                    value = String(rawAttributes[valueStart ..< index])
                    if index < rawAttributes.endIndex {
                        index = rawAttributes.index(after: index)
                    }
                } else {
                    let valueStart = index
                    while index < rawAttributes.endIndex, !rawAttributes[index].isWhitespace {
                        index = rawAttributes.index(after: index)
                    }
                    value = String(rawAttributes[valueStart ..< index])
                }
            }

            if key == "href" || key == "target" || key == "rel" {
                attributes[key] = value
            }
        }

        return attributes
    }

    private func skipSpaces(in text: String, index: inout String.Index) {
        while index < text.endIndex, text[index].isWhitespace {
            index = text.index(after: index)
        }
    }

    private func sanitizeHref(_ href: String?) -> String? {
        guard let href else { return nil }
        let decoded = NewMessageHTMLEntityDecoder.decode(href).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !decoded.isEmpty else { return nil }

        guard let url = URL(string: decoded),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else {
            return nil
        }

        return url.absoluteString
    }
}

enum NewMessageHTMLEntityDecoder {
    private static let namedEntities: [String: String] = [
        "amp": "&",
        "lt": "<",
        "gt": ">",
        "quot": "\"",
        "apos": "'",
        "nbsp": " ",
    ]

    static func decode(_ raw: String) -> String {
        guard raw.contains("&") else { return raw }

        var output = ""
        var index = raw.startIndex

        while index < raw.endIndex {
            if raw[index] == "&",
               let semicolon = raw[index...].firstIndex(of: ";"),
               raw.distance(from: index, to: semicolon) <= 16
            {
                let entityStart = raw.index(after: index)
                let entity = String(raw[entityStart ..< semicolon])

                if let decoded = decodeEntity(entity) {
                    output.append(decoded)
                    index = raw.index(after: semicolon)
                    continue
                }
            }

            output.append(raw[index])
            index = raw.index(after: index)
        }

        return output
    }

    private static func decodeEntity(_ entity: String) -> String? {
        if let decoded = namedEntities[entity.lowercased()] {
            return decoded
        }

        if entity.hasPrefix("#x") || entity.hasPrefix("#X") {
            let hex = String(entity.dropFirst(2))
            guard let value = UInt32(hex, radix: 16),
                  let scalar = UnicodeScalar(value)
            else {
                return nil
            }
            return String(Character(scalar))
        }

        if entity.hasPrefix("#") {
            let number = String(entity.dropFirst())
            guard let value = UInt32(number),
                  let scalar = UnicodeScalar(value)
            else {
                return nil
            }
            return String(Character(scalar))
        }

        return nil
    }
}
