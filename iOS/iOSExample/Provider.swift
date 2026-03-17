//
//  Provider.swift
//  iOSExample
//
//  Created by Om More on 16/12/25.
//

import SQLiteData
import SwiftUI

struct Provider<Content: View>: View {
  @StateObject private var logOutput = LogViewer()
  @StateObject private var xxdk = XXDK()
  @StateObject private var appStorage = AppStorage()
  @StateObject private var navigation = AppNavigationPath()
  @StateObject private var selectedChat = SelectedChat()
  @ViewBuilder let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    self.content
      .environmentObject(self.logOutput)
      .environmentObject(self.appStorage)
      .environmentObject(self.xxdk)
      .environmentObject(self.selectedChat)
      .environmentObject(self.navigation)
  }
}
