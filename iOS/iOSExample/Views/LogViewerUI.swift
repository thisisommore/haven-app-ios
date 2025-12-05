//
//  LogViewerUI.swift
//  iOS Example
//

import SwiftUI

// MARK: - Log Level Detection
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

// MARK: - Styled Log Message
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

// MARK: - Main Log Viewer UI
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

// MARK: - Header Bar
struct LogHeaderBar: View {
    let messageCount: Int
    let totalCount: Int
    @Binding var autoScroll: Bool
    @Binding var showFilters: Bool
    @Binding var showLineNumbers: Bool
    let allMessages: [LogMessage]
    
    @State private var showShareSheet = false
    @State private var logFileURL: URL?
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon & Title
            HStack(spacing: 8) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.haven)
                
                Text("Log")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                // Message count badge
                Text("\(messageCount)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.haven)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.haven.opacity(0.15))
                    .clipShape(Capsule())
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 4) {
                LogActionButton(
                    icon: "line.3.horizontal.decrease.circle",
                    isActive: showFilters,
                    activeColor: .haven
                ) {
                    showFilters.toggle()
                }
                
                LogActionButton(
                    icon: showLineNumbers ? "list.number" : "list.bullet",
                    isActive: showLineNumbers,
                    activeColor: .haven
                ) {
                    showLineNumbers.toggle()
                }
                
                LogActionButton(
                    icon: autoScroll ? "play.circle.fill" : "pause.circle",
                    isActive: autoScroll,
                    activeColor: .haven
                ) {
                    autoScroll.toggle()
                }
                
                LogActionButton(
                    icon: "square.and.arrow.up",
                    isActive: false,
                    activeColor: .haven
                ) {
                    exportLogs()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(uiColor: .secondarySystemBackground))
        .sheet(isPresented: $showShareSheet) {
            if let url = logFileURL {
                ShareSheet(items: [url])
            }
        }
    }
    
    private func exportLogs() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let fileName = "haven_\(timestamp).log"
        
        let logContent = allMessages.map { $0.Msg }.joined(separator: "\n")
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try logContent.write(to: fileURL, atomically: true, encoding: .utf8)
            logFileURL = fileURL
            showShareSheet = true
        } catch {
            print("Failed to export logs: \(error)")
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Action Button
struct LogActionButton: View {
    let icon: String
    let isActive: Bool
    let activeColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(isActive ? activeColor : .secondary)
                .frame(width: 32, height: 32)
                .background(isActive ? activeColor.opacity(0.15) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Filter Bar
struct LogFilterBar: View {
    @Binding var searchText: String
    @Binding var selectedFilter: LogLevel
    
    var body: some View {
        VStack(spacing: 12) {
            // Search Field
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                TextField("Search logs...", text: $searchText)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.primary)
                    .tint(.haven)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(uiColor: .tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 16)
            
            // Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(LogLevel.allCases, id: \.self) { level in
                        LogFilterPill(
                            level: level,
                            isSelected: selectedFilter == level
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedFilter = level
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .scrollClipDisabled()
        }
        .padding(.vertical, 12)
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.5))
    }
}

// MARK: - Filter Pill
struct LogFilterPill: View {
    let level: LogLevel
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: level.icon)
                    .font(.system(size: 11, weight: .semibold))
                
                Text(level.rawValue)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
            }
            .foregroundColor(isSelected ? .white : level.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? level.color : level.color.opacity(0.1))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(level.color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
    }
}

// MARK: - Log Content
struct LogContentView: View {
    let messages: [StyledLogMessage]
    let autoScroll: Bool
    let searchText: String
    let showLineNumbers: Bool
    
    @State private var isAtBottom = true
    @State private var showButton = false
    @Namespace private var bottomID
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        // Multiple attempts to overcome scroll inertia
        proxy.scrollTo(bottomID, anchor: .bottom)
        DispatchQueue.main.async {
            proxy.scrollTo(bottomID, anchor: .bottom)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            proxy.scrollTo(bottomID, anchor: .bottom)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            proxy.scrollTo(bottomID, anchor: .bottom)
        }
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottom) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                            LogRow(
                                message: message,
                                lineNumber: index + 1,
                                searchText: searchText,
                                isAlternate: index % 2 == 1,
                                showLineNumbers: showLineNumbers
                            )
                            .id(message.id)
                        }
                        
                        // Bottom anchor
                        Color.clear
                            .frame(height: 1)
                            .id(bottomID)
                            .onAppear {
                                isAtBottom = true
                                showButton = false
                            }
                            .onDisappear {
                                isAtBottom = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    if !isAtBottom {
                                        showButton = true
                                    }
                                }
                            }
                    }
                    .padding(.vertical, 8)
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        proxy.scrollTo(bottomID, anchor: .bottom)
                    }
                }
                .onChange(of: messages.count) { _, _ in
                    if autoScroll && isAtBottom {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(bottomID, anchor: .bottom)
                        }
                    }
                }
                
                // Scroll to bottom button
                if showButton {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Latest")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.haven)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                    .padding(.bottom, 16)
                    .onTapGesture {
                        scrollToBottom(proxy: proxy)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showButton)
        }
    }
}

// MARK: - Log Row
struct LogRow: View {
    let message: StyledLogMessage
    let lineNumber: Int
    let searchText: String
    let isAlternate: Bool
    let showLineNumbers: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Line number
            if showLineNumbers {
                Text("\(lineNumber)")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.5))
                    .frame(width: 40, alignment: .trailing)
                    .padding(.trailing, 12)
            }
            
            // Message text with highlighting
            HighlightedText(
                text: message.text,
                highlight: searchText,
                baseColor: textColor(for: message.level),
                highlightColor: .haven
            )
            .font(.system(size: 12, weight: .regular, design: .monospaced))
            .lineSpacing(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer(minLength: 16)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(isAlternate ? Color(uiColor: .secondarySystemBackground).opacity(0.5) : Color.clear)
        .contentShape(Rectangle())
        .contextMenu {
            Button(action: {
                UIPasteboard.general.string = message.text
            }) {
                Label("Copy", systemImage: "doc.on.doc")
            }
        }
    }
    
    private func textColor(for level: LogLevel) -> Color {
        switch level {
        case .error: return .red
        case .warning: return .orange
        case .debug: return .blue
        case .trace: return .purple
        default: return .primary
        }
    }
}

// MARK: - Highlighted Text
struct HighlightedText: View {
    let text: String
    let highlight: String
    let baseColor: Color
    let highlightColor: Color
    
    var body: some View {
        if highlight.isEmpty {
            Text(text)
                .foregroundColor(baseColor)
        } else {
            highlightedAttributedText
        }
    }
    
    private var highlightedAttributedText: Text {
        let ranges = text.ranges(of: highlight, options: .caseInsensitive)
        var result = Text("")
        var currentIndex = text.startIndex
        
        for range in ranges {
            // Add non-highlighted part
            if currentIndex < range.lowerBound {
                result = result + Text(text[currentIndex..<range.lowerBound])
                    .foregroundColor(baseColor)
            }
            // Add highlighted part with bold styling
            result = result + Text(text[range])
                .foregroundColor(highlightColor)
                .bold()
            
            currentIndex = range.upperBound
        }
        
        // Add remaining text
        if currentIndex < text.endIndex {
            result = result + Text(text[currentIndex...])
                .foregroundColor(baseColor)
        }
        
        return result
    }
}

// MARK: - String Extension for finding ranges
extension String {
    func ranges(of substring: String, options: CompareOptions = []) -> [Range<Index>] {
        var ranges: [Range<Index>] = []
        var searchRange = startIndex..<endIndex
        
        while let range = self.range(of: substring, options: options, range: searchRange) {
            ranges.append(range)
            searchRange = range.upperBound..<endIndex
        }
        
        return ranges
    }
}

// MARK: - Preview
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
