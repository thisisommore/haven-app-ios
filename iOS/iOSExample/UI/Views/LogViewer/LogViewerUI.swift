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
    self.id = message.id
    self.text = message.Msg
    self.level = LogLevel.detect(from: message.Msg)
    self.timestamp = Date()
  }
}

struct LogViewerUI: View {
  @Environment(LogViewer.self) var logOutput
  @State private var searchText = ""
  @State private var selectedFilter: LogLevel = .all
  @State private var autoScroll = true
  @State private var showFilters = false
  @State private var showLineNumbers = false

  private var filteredMessages: [StyledLogMessage] {
    let styled = self.logOutput.Messages.map { StyledLogMessage(from: $0) }
    return styled.filter { msg in
      let matchesSearch =
        self.searchText.isEmpty || msg.text.localizedCaseInsensitiveContains(self.searchText)
      let matchesFilter = self.selectedFilter == .all || msg.level == self.selectedFilter
      return matchesSearch && matchesFilter
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      // Header Bar
      LogHeaderBar(
        messageCount: self.filteredMessages.count,
        totalCount: self.logOutput.Messages.count,
        autoScroll: self.$autoScroll,
        showFilters: self.$showFilters,
        showLineNumbers: self.$showLineNumbers,
        allMessages: self.logOutput.Messages
      )

      // Search & Filters
      if self.showFilters {
        LogFilterBar(
          searchText: self.$searchText,
          selectedFilter: self.$selectedFilter
        )
        .transition(
          .asymmetric(
            insertion: .push(from: .top).combined(with: .opacity),
            removal: .push(from: .bottom).combined(with: .opacity)
          )
        )
      }

      // Log Content
      LogContentView(
        messages: self.filteredMessages,
        autoScroll: self.autoScroll,
        searchText: self.searchText,
        showLineNumbers: self.showLineNumbers
      )
    }
    .background(Color(uiColor: .systemBackground))
    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: self.showFilters)
  }
}

struct ShareSheet: UIViewControllerRepresentable {
  let items: [Any]

  func makeUIViewController(context _: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: self.items, applicationActivities: nil)
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
    .environment(LogViewer())
    .frame(height: 500)
    .padding()
}

#Preview("Dark Mode") {
  LogViewerUI()
    .environment(LogViewer())
    .preferredColorScheme(.dark)
}
