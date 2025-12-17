//
//  LogContentView.swift
//  iOSExample
//
//  Created by Om More on 17/12/25.
//

import Foundation
import SwiftUI

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
