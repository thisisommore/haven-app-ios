//
//  BottomActions.swift
//  iOSExample
//
//  Created by Om More on 16/12/25.
//

import SwiftUI
import Foundation

struct BottomActionsView: View {
    @Binding var isGenerating: Bool
    let selectedCodename: Codename?
    let onGenerate: () -> Void
    let onClaim: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Generate button
            Button(action: onGenerate) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .rotationEffect(.degrees(isGenerating ? 360 : 0))
                        .animation(
                            isGenerating ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                            value: isGenerating
                        )

                    Text("Generate New Set")
                        .font(.system(size: 12, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.haven)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isGenerating)

            // Claim button
            Button(action: onClaim) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))

                    Text("Claim Codename")
                        .font(.system(size: 12, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(selectedCodename != nil ? Color.haven : Color.secondary.opacity(0.3))
                .foregroundColor(selectedCodename != nil ? .white : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(selectedCodename == nil)
        }
    }
}
