//
//  Provider.swift
//  iOSExample
//
//  Created by Om More on 16/12/25.
//

import SQLiteData
import SwiftUI

struct Provider<Content: View>: View {
  @State private var logOutput = LogViewer()
  @State private var xxdk = XXDK()
  @State private var appStorage = AppStorage()
  @State private var navigation = AppNavigationPath()
  @State private var selectedChat = SelectedChat()
  @ViewBuilder let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    self.content
      .environment(self.logOutput)
      .environment(self.appStorage)
      .environment(self.xxdk)
      .environment(self.selectedChat)
      .environment(self.navigation)
  }
}
