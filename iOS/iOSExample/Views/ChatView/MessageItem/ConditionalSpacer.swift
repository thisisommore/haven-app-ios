//
//  ConditionalSpacer.swift
//  iOSExample
//
//  Created by Om More on 19/10/25.
//

import SwiftUI

/// A spacer that only appears when a condition is met
struct ConditionalSpacer: View {
    let show: Bool

    init(_ show: Bool) {
        self.show = show
    }

    var body: some View {
        show ? Spacer() : nil
    }
}
