//
//  ResTest.swift
//  iOSExample
//
//  Created by Om More on 22/09/25.
//

import SwiftUI

struct AdaptiveLayoutView: View {
    @State private var selectedView = 0

    private var users = ["Mayur", "Shashank", "Tom"]
    var body: some View {
        ViewThatFits {
            // Try horizontal layout first
            HStack(spacing: 20) {
                HomeView()
                    .frame(minWidth: 300, maxWidth: .infinity)

                Divider()

                ChatView(chatUser: "Mayur")
                    .frame(minWidth: 300, maxWidth: .infinity)
            }
            .padding()

            // Fall back to vertical/tabbed layout
            TabView(selection: $selectedView) {
                HomeView()
                    .tabItem {
                        Image(systemName: "1.circle")
                        Text("View A")
                    }
                    .tag(0)

                ChatView(chatUser: "Mayur")
                    .tabItem {
                        Image(systemName: "2.circle")
                        Text("View B")
                    }
                    .tag(1)
            }
        }
    }
}

#Preview {
    AdaptiveLayoutView()
}

// Alternative: Custom adaptive container
struct AdaptiveContainer<Content: View>: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        if horizontalSizeClass == .regular {
            HStack {
                content
            }
        } else {
            VStack {
                content
            }
        }
    }
}
