//
//  LogFilterPill.swift
//  iOSExample
//
//  Created by Om More on 17/12/25.
//

import Foundation
import SwiftUI

struct LogFilterPill: View {
    let level: LogLevel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: level.icon)
                    .font(.system(size: 11, weight: .semibold))

                Text(level.rawValue)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
            }
            .foregroundColor(isSelected ? .white : level.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? level.color : level.color.opacity(0.1))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(level.color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
    }
}
