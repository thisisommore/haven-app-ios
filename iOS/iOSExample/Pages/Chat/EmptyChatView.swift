//
//  EmptyChatView.swift
//  iOSExample
//
//  Created by Om More on 22/09/25.
//

import SwiftUI

struct EmptyChatView: View {
    var body: some View {
        VStack {
            Spacer()
            Text("No messages yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .clipShape(Capsule())
            Spacer()
        }
    }
}
