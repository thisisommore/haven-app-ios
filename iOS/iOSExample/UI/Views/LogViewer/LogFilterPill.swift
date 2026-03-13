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
    Button(action: self.action) {
      HStack(spacing: 6) {
        Image(systemName: self.level.icon)
          .font(.system(size: 11, weight: .semibold))

        Text(self.level.rawValue)
          .font(.system(size: 12, weight: .semibold, design: .monospaced))
      }
      .foregroundColor(self.isSelected ? .white : self.level.color)
      .padding(.horizontal, 12)
      .padding(.vertical, 7)
      .background(self.isSelected ? self.level.color : self.level.color.opacity(0.1))
      .clipShape(Capsule())
      .overlay(
        Capsule()
          .stroke(self.level.color.opacity(0.3), lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
    .scaleEffect(self.isSelected ? 1.05 : 1.0)
  }
}
