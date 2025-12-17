//
//  Header.swift
//  iOSExample
//
//  Created by Om More on 16/12/25.
//
import SwiftUI
import Foundation
struct HeaderView: View {
    // State to control the tooltip popover visibility
    @State private var showTooltip = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Find your Codename")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                // Tooltip icon that shows a popover when tapped
                Button(action: {
                    showTooltip.toggle()
                }) {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .popover(isPresented: $showTooltip, arrowEdge: .top) {
                    Text("Codenames are generated on your computer by you. No servers or databases are involved at all. Your Codename is your personally owned anonymous identity shared across every Haven Chat you join. It is private and it can never be traced back to you.")
                        .font(.caption)
                        .padding(24)
                        .frame(width: UIScreen.screenWidth)
                        .fixedSize(horizontal: false, vertical: true)
                        // Adapts the popover size for a better fit on different devices
                        .presentationCompactAdaptation(.popover)
                }
            }
        }
        .padding(6)
    }
}
