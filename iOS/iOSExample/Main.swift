//
//  Main.swift
//  iOSExample
//
//  Created by Richard Carback on 3/4/24.
//

import Bindings
import SQLiteData
import SwiftUI

@main
struct Main: App {
  init() {
    prepareDependencies {
      $0.defaultDatabase = try! appDatabase()
      $0.appStorage = AppStorage()
    }
  }

  var body: some Scene {
    WindowGroup {
      Provider {
        Root()
      }
    }
  }
}
