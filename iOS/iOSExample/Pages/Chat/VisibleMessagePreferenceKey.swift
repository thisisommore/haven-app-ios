//
//  VisibleMessagePreferenceKey.swift
//  iOSExample
//
//  Created by Om More on 22/09/25.
//

import SwiftUI

struct VisibleMessagePreferenceKey: PreferenceKey {
    static var defaultValue: Date? = nil
    static func reduce(value: inout Date?, nextValue: () -> Date?) {
        // Keep the earliest (topmost) visible message date
        if let next = nextValue() {
            if value == nil || next < value! {
                value = next
            }
        }
    }
}

