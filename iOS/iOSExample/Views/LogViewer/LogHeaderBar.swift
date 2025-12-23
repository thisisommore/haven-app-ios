//
//  LogHeaderBar.swift
//  iOSExample
//
//  Created by Om More on 17/12/25.
//
import Foundation
import SwiftUI

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
            AppLogger.app.error("Failed to export logs: \(error.localizedDescription, privacy: .public)")
        }
    }
}
