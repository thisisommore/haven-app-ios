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
    proxy.scrollTo(self.bottomID, anchor: .bottom)
    DispatchQueue.main.async {
      proxy.scrollTo(self.bottomID, anchor: .bottom)
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      proxy.scrollTo(self.bottomID, anchor: .bottom)
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      proxy.scrollTo(self.bottomID, anchor: .bottom)
    }
  }

  var body: some View {
    ScrollViewReader { proxy in
      ZStack(alignment: .bottom) {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(Array(self.messages.enumerated()), id: \.element.id) { index, message in
              LogRow(
                message: message,
                lineNumber: index + 1,
                searchText: self.searchText,
                isAlternate: index % 2 == 1,
                showLineNumbers: self.showLineNumbers
              )
              .id(message.id)
            }

            // Bottom anchor
            Color.clear
              .frame(height: 1)
              .id(self.bottomID)
              .onAppear {
                self.isAtBottom = true
                self.showButton = false
              }
              .onDisappear {
                self.isAtBottom = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                  if !self.isAtBottom {
                    self.showButton = true
                  }
                }
              }
          }
          .padding(.vertical, 8)
        }
        .onAppear {
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            proxy.scrollTo(self.bottomID, anchor: .bottom)
          }
        }
        .onChange(of: self.messages.count) { _, _ in
          if self.autoScroll && self.isAtBottom {
            withAnimation(.easeOut(duration: 0.2)) {
              proxy.scrollTo(self.bottomID, anchor: .bottom)
            }
          }
        }

        // Scroll to bottom button
        if self.showButton {
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
            self.scrollToBottom(proxy: proxy)
          }
          .transition(.move(edge: .bottom).combined(with: .opacity))
        }
      }
      .animation(.spring(response: 0.3, dampingFraction: 0.8), value: self.showButton)
    }
  }
}
