import SwiftUI

// MARK: - HTML Element Types

enum HTMLElement {
    case text(String)
    case bold(String)
    case italic(String)
    case strikethrough(String)
    case link(text: String, url: String)
    case code(String)
    case codeBlock(String)
    case blockquote(String)
    case orderedList([String])
    case unorderedList([String])
    case paragraph([HTMLElement])
    case lineBreak
}

struct ParagraphView: View {
    let elements: [HTMLElement]
    @Environment(\.font) var environmentFont

    var body: some View {
        let attributedString = createAttributedString()
        Text(attributedString)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func createAttributedString() -> AttributedString {
        var attributedString = AttributedString("")
        let baseFont = environmentFont ?? .body

        for element in elements {
            var content: AttributedString

            switch element {
            case let .text(text):
                content = AttributedString(text)
                content.font = baseFont
            case let .bold(text):
                content = AttributedString(text)
                content.font = baseFont.weight(.bold)
            case let .italic(text):
                content = AttributedString(text)
                content.font = baseFont.italic()
            case let .strikethrough(text):
                content = AttributedString(text)
                content.font = baseFont
                content.strikethroughStyle = .single
            case let .link(text, _):
                content = AttributedString(text)
                content.font = baseFont
                content.foregroundColor = .blue
            case let .code(text):
                content = AttributedString(text)
                content.font = .system(.body, design: .monospaced)
                content.backgroundColor = Color.gray.opacity(0.2)
            case .lineBreak:
                content = AttributedString("\n")
                content.font = baseFont
            default:
                // Handle any unexpected cases - block-level elements shouldn't appear in paragraphs
                content = AttributedString("")
                content.font = baseFont
            }

            attributedString.append(content)
        }

        return attributedString
    }
}

// MARK: - Fast Path for Simple Content

private extension String {
    var isSimpleParagraph: Bool {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("<p>") && trimmed.hasSuffix("</p>") &&
            !trimmed.contains("<p>") && !trimmed.contains("<b>") &&
            !trimmed.contains("<i>") && !trimmed.contains("<code>") &&
            !trimmed.contains("<a ") && !trimmed.contains("<br")
    }

    var simpleParagraphContent: String? {
        guard isSimpleParagraph else { return nil }
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        let start = trimmed.index(trimmed.startIndex, offsetBy: 3)
        let end = trimmed.index(trimmed.endIndex, offsetBy: -4)
        return String(trimmed[start ..< end])
    }
}

// MARK: - HTML Parser

class HTMLParser {
    static let shared = HTMLParser()
    private var cache: [String: [HTMLElement]] = [:]

    func parse(_ html: String) -> [HTMLElement] {
        // Fast path for simple paragraph content
        if html.isSimpleParagraph, let content = html.simpleParagraphContent {
            return [.paragraph([.text(content)])]
        }

        // Check cache first
        if let cached = cache[html] {
            return cached
        }

        var elements: [HTMLElement] = []
        var currentIndex = html.startIndex

        while currentIndex < html.endIndex {
            if html[currentIndex] == "<" {
                if let (element, newIndex) = parseTag(
                    from: html,
                    startIndex: currentIndex
                ) {
                    elements.append(element)
                    currentIndex = newIndex
                } else {
                    currentIndex = html.index(after: currentIndex)
                }
            } else {
                if let (text, newIndex) = parseText(
                    from: html,
                    startIndex: currentIndex
                ) {
                    elements.append(.text(text))
                    currentIndex = newIndex
                } else {
                    currentIndex = html.index(after: currentIndex)
                }
            }
        }

        // Cache result
        cache[html] = elements
        return elements
    }

    private func parseText(from html: String, startIndex: String.Index) -> (
        String, String.Index
    )? {
        // Fast path: if no '<' in remaining string, take everything
        if let range = html.range(of: "<", range: startIndex ..< html.endIndex) {
            let length = html.distance(from: startIndex, to: range.lowerBound)
            if length > 0 {
                return (String(html[startIndex ..< range.lowerBound]), range.lowerBound)
            } else {
                return nil
            }
        } else {
            // No more tags, take everything until end
            let text = String(html[startIndex...])
            return text.isEmpty ? nil : (text, html.endIndex)
        }
    }

    private func parseTag(from html: String, startIndex: String.Index) -> (
        HTMLElement, String.Index
    )? {
        guard html[startIndex] == "<" else { return nil }

        var tagEndIndex = startIndex
        while tagEndIndex < html.endIndex, html[tagEndIndex] != ">" {
            tagEndIndex = html.index(after: tagEndIndex)
        }

        guard tagEndIndex < html.endIndex else { return nil }
        tagEndIndex = html.index(after: tagEndIndex)

        let tagRange =
            html.index(after: startIndex) ..< html.index(before: tagEndIndex)
        let tagContent = String(html[tagRange]).trimmingCharacters(
            in: .whitespaces
        )

        let tagName =
            tagContent.split(separator: " ").first.map(String.init)
                ?? tagContent

        switch tagName.lowercased() {
        case "p":
            return parseParagraph(from: html, startIndex: startIndex)
        case "b", "strong":
            return parseSimpleTag(
                from: html,
                startIndex: startIndex,
                tag: "b",
                altTag: "strong",
                element: HTMLElement.bold
            )
        case "i", "em":
            return parseSimpleTag(
                from: html,
                startIndex: startIndex,
                tag: "i",
                altTag: "em",
                element: HTMLElement.italic
            )
        case "s", "strike", "del":
            return parseSimpleTag(
                from: html,
                startIndex: startIndex,
                tag: "s",
                altTag: "strike",
                element: HTMLElement.strikethrough
            )
        case "code":
            return parseSimpleTag(
                from: html,
                startIndex: startIndex,
                tag: "code",
                element: HTMLElement.code
            )
        case "pre":
            return parseCodeBlock(from: html, startIndex: startIndex)
        case "blockquote":
            return parseBlockquote(from: html, startIndex: startIndex)
        case "a":
            return parseLink(
                from: html,
                startIndex: startIndex,
                tagContent: tagContent
            )
        case "ol":
            return parseOrderedList(from: html, startIndex: startIndex)
        case "ul":
            return parseUnorderedList(from: html, startIndex: startIndex)
        case "br", "br/":
            return (.lineBreak, tagEndIndex)
        case let closing where closing.hasPrefix("/"):
            // Skip closing tags that we don't process
            return nil
        default:
            return nil
        }
    }

    private func parseParagraph(from html: String, startIndex: String.Index)
        -> (HTMLElement, String.Index)?
    {
        guard
            let openTagEnd = html.range(
                of: ">",
                range: startIndex ..< html.endIndex
            )?.upperBound
        else { return nil }
        guard
            let closingRange = html.range(
                of: "</p>",
                options: .caseInsensitive,
                range: openTagEnd ..< html.endIndex
            )
        else { return nil }

        let content = String(html[openTagEnd ..< closingRange.lowerBound])
        let innerElements = parseInline(content)

        return (.paragraph(innerElements), closingRange.upperBound)
    }

    private func parseInline(_ html: String) -> [HTMLElement] {
        var elements: [HTMLElement] = []
        var currentIndex = html.startIndex

        while currentIndex < html.endIndex {
            if html[currentIndex] == "<" {
                if let (element, newIndex) = parseInlineTag(
                    from: html,
                    startIndex: currentIndex
                ) {
                    elements.append(element)
                    currentIndex = newIndex
                } else {
                    currentIndex = html.index(after: currentIndex)
                }
            } else {
                if let (text, newIndex) = parseText(
                    from: html,
                    startIndex: currentIndex
                ) {
                    elements.append(.text(text))
                    currentIndex = newIndex
                } else {
                    currentIndex = html.index(after: currentIndex)
                }
            }
        }

        return elements
    }

    private func parseInlineTag(from html: String, startIndex: String.Index)
        -> (HTMLElement, String.Index)?
    {
        guard html[startIndex] == "<" else { return nil }

        var tagEndIndex = startIndex
        while tagEndIndex < html.endIndex, html[tagEndIndex] != ">" {
            tagEndIndex = html.index(after: tagEndIndex)
        }

        guard tagEndIndex < html.endIndex else { return nil }
        tagEndIndex = html.index(after: tagEndIndex)

        let tagRange =
            html.index(after: startIndex) ..< html.index(before: tagEndIndex)
        let tagContent = String(html[tagRange]).trimmingCharacters(
            in: .whitespaces
        )

        let tagName =
            tagContent.split(separator: " ").first.map(String.init)
                ?? tagContent

        switch tagName.lowercased() {
        case "b", "strong":
            return parseSimpleTag(
                from: html,
                startIndex: startIndex,
                tag: "b",
                altTag: "strong",
                element: HTMLElement.bold
            )
        case "i", "em":
            return parseSimpleTag(
                from: html,
                startIndex: startIndex,
                tag: "i",
                altTag: "em",
                element: HTMLElement.italic
            )
        case "s", "strike", "del":
            return parseSimpleTag(
                from: html,
                startIndex: startIndex,
                tag: "s",
                altTag: "strike",
                element: HTMLElement.strikethrough
            )
        case "code":
            return parseSimpleTag(
                from: html,
                startIndex: startIndex,
                tag: "code",
                element: HTMLElement.code
            )
        case "a":
            return parseLink(
                from: html,
                startIndex: startIndex,
                tagContent: tagContent
            )
        default:
            return nil
        }
    }

    private func parseSimpleTag(
        from html: String,
        startIndex: String.Index,
        tag: String,
        altTag: String? = nil,
        element: @escaping (String) -> HTMLElement
    ) -> (HTMLElement, String.Index)? {
        let closingTag = "</\(tag)>"
        let altClosingTag = altTag.map { "</\($0)>" }

        guard
            let openTagEnd = html.range(
                of: ">",
                range: startIndex ..< html.endIndex
            )?.upperBound
        else { return nil }

        var closingRange = html.range(
            of: closingTag,
            options: .caseInsensitive,
            range: openTagEnd ..< html.endIndex
        )
        if closingRange == nil, let alt = altClosingTag {
            closingRange = html.range(
                of: alt,
                options: .caseInsensitive,
                range: openTagEnd ..< html.endIndex
            )
        }

        guard let closing = closingRange else { return nil }

        let content = String(html[openTagEnd ..< closing.lowerBound])
        return (element(content), closing.upperBound)
    }

    private func parseCodeBlock(from html: String, startIndex: String.Index)
        -> (HTMLElement, String.Index)?
    {
        guard
            let openTagEnd = html.range(
                of: ">",
                range: startIndex ..< html.endIndex
            )?.upperBound
        else { return nil }
        guard
            let closingRange = html.range(
                of: "</pre>",
                options: .caseInsensitive,
                range: openTagEnd ..< html.endIndex
            )
        else { return nil }

        var content = String(html[openTagEnd ..< closingRange.lowerBound])

        if content.hasPrefix("<code>"), content.hasSuffix("</code>") {
            content = String(content.dropFirst(6).dropLast(7))
        }

        return (.codeBlock(content), closingRange.upperBound)
    }

    private func parseBlockquote(from html: String, startIndex: String.Index)
        -> (HTMLElement, String.Index)?
    {
        guard
            let openTagEnd = html.range(
                of: ">",
                range: startIndex ..< html.endIndex
            )?.upperBound
        else { return nil }
        guard
            let closingRange = html.range(
                of: "</blockquote>",
                options: .caseInsensitive,
                range: openTagEnd ..< html.endIndex
            )
        else { return nil }

        let content = String(html[openTagEnd ..< closingRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (.blockquote(content), closingRange.upperBound)
    }

    private func parseLink(
        from html: String,
        startIndex: String.Index,
        tagContent: String
    ) -> (HTMLElement, String.Index)? {
        var url = ""
        if let hrefRange = tagContent.range(
            of: "href=\"",
            options: .caseInsensitive
        ) {
            let afterHref = hrefRange.upperBound
            if let endQuote = tagContent[afterHref...].firstIndex(of: "\"") {
                url = String(tagContent[afterHref ..< endQuote])
            }
        }

        guard
            let openTagEnd = html.range(
                of: ">",
                range: startIndex ..< html.endIndex
            )?.upperBound
        else { return nil }
        guard
            let closingRange = html.range(
                of: "</a>",
                options: .caseInsensitive,
                range: openTagEnd ..< html.endIndex
            )
        else { return nil }

        let linkText = String(html[openTagEnd ..< closingRange.lowerBound])
        return (.link(text: linkText, url: url), closingRange.upperBound)
    }

    private func parseOrderedList(from html: String, startIndex: String.Index)
        -> (HTMLElement, String.Index)?
    {
        return parseList(
            from: html,
            startIndex: startIndex,
            listTag: "ol",
            element: HTMLElement.orderedList
        )
    }

    private func parseUnorderedList(from html: String, startIndex: String.Index)
        -> (HTMLElement, String.Index)?
    {
        return parseList(
            from: html,
            startIndex: startIndex,
            listTag: "ul",
            element: HTMLElement.unorderedList
        )
    }

    private func parseList(
        from html: String,
        startIndex: String.Index,
        listTag: String,
        element: @escaping ([String]) -> HTMLElement
    ) -> (HTMLElement, String.Index)? {
        guard
            let openTagEnd = html.range(
                of: ">",
                range: startIndex ..< html.endIndex
            )?.upperBound
        else { return nil }
        guard
            let closingRange = html.range(
                of: "</\(listTag)>",
                options: .caseInsensitive,
                range: openTagEnd ..< html.endIndex
            )
        else { return nil }

        let listContent = String(html[openTagEnd ..< closingRange.lowerBound])
        let items = extractListItems(from: listContent)

        return (element(items), closingRange.upperBound)
    }

    private func extractListItems(from content: String) -> [String] {
        var items: [String] = []
        var currentIndex = content.startIndex

        while currentIndex < content.endIndex {
            if let liStart = content.range(
                of: "<li",
                options: .caseInsensitive,
                range: currentIndex ..< content.endIndex
            ) {
                if let liOpenEnd = content.range(
                    of: ">",
                    range: liStart.lowerBound ..< content.endIndex
                )?.upperBound {
                    if let liClose = content.range(
                        of: "</li>",
                        options: .caseInsensitive,
                        range: liOpenEnd ..< content.endIndex
                    ) {
                        let itemText = String(
                            content[liOpenEnd ..< liClose.lowerBound]
                        ).trimmingCharacters(in: .whitespacesAndNewlines)
                        items.append(itemText)
                        currentIndex = liClose.upperBound
                    } else {
                        break
                    }
                } else {
                    break
                }
            } else {
                break
            }
        }

        return items
    }
}

// MARK: - HTML View

struct HTMLView: View {
    let html: String
    @Environment(\.font) private var environmentFont

    private var elements: [HTMLElement] {
        HTMLParser.shared.parse(html)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(elements.enumerated()), id: \.offset) {
                _,
                    element in
                renderElement(element)
            }
        }
    }

    @ViewBuilder
    private func renderElement(_ element: HTMLElement) -> some View {
        switch element {
        case let .text(content):
            if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(content)
                    .fixedSize(horizontal: false, vertical: true)
            }

        case let .bold(content):
            Text(content)
                .fontWeight(.bold)

        case let .italic(content):
            Text(content)
                .italic()

        case let .strikethrough(content):
            Text(content)
                .strikethrough()

        case let .link(text, url):
            Link(
                text,
                destination: URL(string: url) ?? URL(string: "about:blank")!
            )
            .foregroundColor(.blue)

        case let .code(content):
            Text(content)
                .monospaced()
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(4)

        case let .codeBlock(content):
            Text(content)
                .monospaced()
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)

        case let .blockquote(content):
            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 4)
                    .fixedSize() // don't let it stretch vertically unnecessarily

                Text(content)
                    .italic()
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true) // critical: size to content only
                    .layoutPriority(1) // claim space so parent doesn't add empty gap
            }
            .padding(.vertical, 2) // minimal vertical padding
            .padding(.leading, 4)
            .background(Color.clear)

        case let .orderedList(items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) {
                    index,
                        item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).")
                            .fontWeight(.medium)
                        Text(item)
                    }
                }
            }
            .padding(.leading, 8)

        case let .unorderedList(items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .fontWeight(.bold)
                        Text(item)
                    }
                }
            }
            .padding(.leading, 8)

        case let .paragraph(innerElements):
            renderParagraph(innerElements)
                .padding(.bottom, 4)

        case .lineBreak:
            Divider()
                .opacity(0)
                .frame(height: 8)
        }
    }

    private func renderParagraph(_ elements: [HTMLElement]) -> some View {
        ParagraphView(elements: elements)
    }
}

// MARK: - Preview

struct HTMLView_Previews: PreviewProvider {
    static var previews: some View {
        HTMLView(
            html: """
            <p>This is <b>bold text</b> and <i>italic text</i>.</p>
            <p>Here is <s>strikethrough</s> and a <a href="https://apple.com">link to Apple</a>.</p>

            <p>Inline code: <code>let x = 5</code></p>

            <pre><code>func hello() {
                print("Hello, World!")
            }</code></pre>

            <blockquote>This is a famous quote from someone important.</blockquote>

            <p><strong>Ordered List:</strong></p>
            <ol>
                <li>First item</li>
                <li>Second item</li>
                <li>Third item</li>
            </ol>

            <p><em>Unordered List:</em></p>
            <ul>
                <li>Apple</li>
                <li>Banana</li>
                <li>Orange</li>
            </ul>
            """
        ).font(.system(size: 12))
    }
}
