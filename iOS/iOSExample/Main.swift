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
