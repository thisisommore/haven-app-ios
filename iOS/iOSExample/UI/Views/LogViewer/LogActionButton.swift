//
//  LogActionButton.swift
//  iOSExample
//
//  Created by Om More on 17/12/25.
//
import Foundation
import SwiftUI

struct LogActionButton: View {
    let icon: String
    let isActive: Bool
    let activeColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(isActive ? activeColor : .secondary)
                .frame(width: 32, height: 32)
                .background(isActive ? activeColor.opacity(0.15) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
