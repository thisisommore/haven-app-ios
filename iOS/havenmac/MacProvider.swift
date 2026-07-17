//
//  MacProvider.swift
//  haven
//
//  Injects the global dependencies as environment objects, mirroring the iOS
//  `Provider`. The shared `LogViewer` is passed in from the app so the log
//  window and the main window observe the same instance.
//

import SwiftUI

struct MacProvider<Content: View>: View {
  @StateObject private var logOutput: LogViewer
  @StateObject private var xxdk = XXDK()
  @StateObject private var navigation = AppNavigationPath()
  @StateObject private var selectedChat = SelectedChat()
  @ViewBuilder let content: Content

  init(logOutput: LogViewer, @ViewBuilder content: () -> Content) {
    _logOutput = StateObject(wrappedValue: logOutput)
    self.content = content()
  }

  var body: some View {
    self.content
      .environmentObject(self.logOutput)
      .environmentObject(self.xxdk)
      .environmentObject(self.selectedChat)
      .environmentObject(self.navigation)
  }
}
