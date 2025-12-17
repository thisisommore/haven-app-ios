//
//  LogViewerUI.swift
//  iOS Example
//

import SwiftUI

enum LogLevel: String, CaseIterable {
    case all = "ALL"
    case error = "ERROR"
    case warning = "WARN"
    case info = "INFO"
    case debug = "DEBUG"
    case trace = "TRACE"

    var color: Color {
        switch self {
        case .error: return .red
        case .warning: return .orange
        case .info: return .green
        case .debug: return .blue
        case .trace: return .purple
        case .all: return .secondary
        }
    }

    var icon: String {
        switch self {
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        case .debug: return "ladybug.fill"
        case .trace: return "waveform.path"
        case .all: return "list.bullet"
        }
    }

    static func detect(from message: String) -> LogLevel {
        let upper = message.uppercased()
        if upper.contains("ERROR") || upper.contains("FATAL") || upper.contains("FAIL") {
            return .error
        } else if upper.contains("WARN") {
            return .warning
        } else if upper.contains("DEBUG") {
            return .debug
        } else if upper.contains("TRACE") || upper.contains("VERBOSE") {
            return .trace
        }
        return .info
    }
}

struct StyledLogMessage: Identifiable {
    let id: UUID
    let text: String
    let level: LogLevel
    let timestamp: Date

    init(from message: LogMessage) {
        id = message.id
        text = message.Msg
        level = LogLevel.detect(from: message.Msg)
        timestamp = Date()
    }
}

struct LogViewerUI: View {
    @EnvironmentObject var logOutput: LogViewer
    @State private var searchText = ""
    @State private var selectedFilter: LogLevel = .all
    @State private var autoScroll = true
    @State private var showFilters = false
    @State private var showLineNumbers = false

    private var filteredMessages: [StyledLogMessage] {
        let styled = logOutput.Messages.map { StyledLogMessage(from: $0) }
        return styled.filter { msg in
            let matchesSearch = searchText.isEmpty || msg.text.localizedCaseInsensitiveContains(searchText)
            let matchesFilter = selectedFilter == .all || msg.level == selectedFilter
            return matchesSearch && matchesFilter
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            LogHeaderBar(
                messageCount: filteredMessages.count,
                totalCount: logOutput.Messages.count,
                autoScroll: $autoScroll,
                showFilters: $showFilters,
                showLineNumbers: $showLineNumbers,
                allMessages: logOutput.Messages
            )

            // Search & Filters
            if showFilters {
                LogFilterBar(
                    searchText: $searchText,
                    selectedFilter: $selectedFilter
                )
                .transition(.asymmetric(
                    insertion: .push(from: .top).combined(with: .opacity),
                    removal: .push(from: .bottom).combined(with: .opacity)
                ))
            }

            // Log Content
            LogContentView(
                messages: filteredMessages,
                autoScroll: autoScroll,
                searchText: searchText,
                showLineNumbers: showLineNumbers
            )
        }
        .background(Color(uiColor: .systemBackground))
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showFilters)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context _: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}

extension String {
    func ranges(of substring: String, options: CompareOptions = []) -> [Range<Index>] {
        var ranges: [Range<Index>] = []
        var searchRange = startIndex ..< endIndex

        while let range = range(of: substring, options: options, range: searchRange) {
            ranges.append(range)
            searchRange = range.upperBound ..< endIndex
        }

        return ranges
    }
}

#Preview("Log Viewer") {
    LogViewerUI()
        .environmentObject(LogViewer())
        .frame(height: 500)
        .padding()
}

#Preview("Dark Mode") {
    LogViewerUI()
        .environmentObject(LogViewer())
        .preferredColorScheme(.dark)
}
