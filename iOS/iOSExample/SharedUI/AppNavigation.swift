//
//  AppNavigation.swift
//  iOSExample
//
//  Shared navigation state used by both the iOS and macOS apps.
//  Each platform maps `Destination` to its own views.
//

import Foundation
import SwiftUI

final class AppNavigationPath: Observable, ObservableObject {
  @Published var path = NavigationPath()
}

enum Destination: Hashable {
  case home
  case landing
  case codenameGenerator
  case password
  case chat(chatId: UUID) // add whatever "props" you need
  case logViewer
}
