//
//  Main.swift
//  iOSExample
//
//  Created by Richard Carback on 3/4/24.
//

import Bindings
import HavenCore
import SQLiteData
import SwiftUI

@main
struct Main: App {
  @StateObject private var xxdk = XXDK()
  @UIApplicationDelegateAdaptor(Notifications.self) var notificationDelegate

  init() {
    prepareDependencies {
      $0.defaultDatabase = try! appDatabase(migrate: true)
      $0.appStorage = AppStorage()
    }
  }

  var body: some Scene {
    WindowGroup {
      Provider(xxdk: self.xxdk) {
        Root()
      }
      .onAppear {
        self.notificationDelegate.set(xxdk: self.xxdk)
      }
    }
  }
}
