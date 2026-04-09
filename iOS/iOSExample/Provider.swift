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
  @ObservedObject var xxdk: XXDK
  @StateObject private var navigation = AppNavigationPath()
  @StateObject private var selectedChat = SelectedChat()
  @ViewBuilder let content: Content

  init(xxdk: XXDK, @ViewBuilder content: () -> Content) {
    self.xxdk = xxdk
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
