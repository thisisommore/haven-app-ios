//
//  havenApp.swift
//  haven
//
//  Created by Om More on 17/07/26.
//

import SQLiteData
import SwiftUI

@main
struct HavenMacApp: App {
  /// Created once here so both the main window and the log window share the
  /// same pipe capture (and we never spin up a second XXDK client).
  private let logOutput = LogViewer()

  /// Single AppStorage instance shared by the dependency system and SwiftUI,
  /// so `isSetupComplete` changes re-render the root view.
  private let appStorage = AppStorage()

  init() {
    prepareDependencies {
      $0.defaultDatabase = try! appDatabase()
      $0.appStorage = self.appStorage
    }
  }

  var body: some Scene {
    WindowGroup {
      MacProvider(logOutput: self.logOutput) {
        MacRoot()
      }
      .environmentObject(self.appStorage)
      .frame(minWidth: 780, minHeight: 520)
    }
    .defaultSize(width: 1080, height: 700)
    .defaultPosition(.center)

    Window("Haven Log", id: "log-viewer") {
      LogViewerUI()
        .environmentObject(self.logOutput)
        .frame(minWidth: 640, minHeight: 420)
    }
    .keyboardShortcut("l", modifiers: [.command, .option])
    .defaultSize(width: 900, height: 600)
  }
}
