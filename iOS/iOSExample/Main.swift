//
//  Main.swift
//  iOSExample
//
//  Created by Richard Carback on 3/4/24.
//

import Bindings
import SwiftData
import SwiftUI

@main
struct Main: App {
    var body: some Scene {
        WindowGroup {
            Provider {
                Root()
            }
        }
    }
}
