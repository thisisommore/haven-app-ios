//
//  CodeNameCard.swift
//  iOSExample
//
//  Created by Om More on 16/12/25.
//

import Foundation
import SwiftUI

struct CodenameCard: View {
  let codename: Codename
  let isSelected: Bool

  var body: some View {
    HStack(spacing: 16) {
      // Color accent bar
      RoundedRectangle(cornerRadius: 4)
        .fill(self.codename.color)
        .frame(width: 4, height: 48)

      // Codename text
      Text(self.codename.text)
        .font(.system(size: 17, weight: .medium, design: .monospaced))
        .foregroundColor(.primary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)

      Spacer()

      // Selection indicator
      ZStack {
        Circle()
          .stroke(self.isSelected ? self.codename.color : Color.secondary.opacity(0.3), lineWidth: 2)
          .frame(width: 28, height: 28)

        if self.isSelected {
          Circle()
            .fill(self.codename.color)
            .frame(width: 16, height: 16)
            .overlay(
              Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
            )
        }
      }
      .animation(.spring(response: 0.3, dampingFraction: 0.6), value: self.isSelected)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color(uiColor: .secondarySystemBackground))
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(
              self.isSelected ? self.codename.color : Color.clear,
              lineWidth: 2
            )
        )
    )
    .scaleEffect(self.isSelected ? 1.02 : 1.0)
  }
}
