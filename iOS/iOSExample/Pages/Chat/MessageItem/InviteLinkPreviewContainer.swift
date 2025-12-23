//
//  InviteLinkPreviewContainer.swift
//  iOSExample
//
//  Created by Om More on 23/12/25.
//

import SwiftUI

struct InviteLinkPreviewContainer<Content: View>: View {
    let isIncoming: Bool
    let timestamp: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content()

            if !timestamp.isEmpty {
                HStack {
                    Spacer()
                    Text(timestamp)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.secondary)
                }
            }
        }
        .padding(10)
        .background(Color.appBackground)
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: isIncoming ? 0 : 16,
                bottomTrailingRadius: isIncoming ? 16 : 0,
                topTrailingRadius: 0
            )
            .strokeBorder(Color.messageBubble, lineWidth: 1)
        )
    }
}

struct InviteLinkHeader: View {
    let icon: String
    let title: String
    let subtitle: String?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Color.haven)
                .font(.title)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.primary)

                if let subtitle = subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
    }
}

struct InviteLinkButton: View {
    let isLoading: Bool
    let isCompleted: Bool
    let completedText: String
    let actionText: String
    let errorMessage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
                Text(isCompleted ? completedText : (isLoading ? "Loading..." : actionText))
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(isCompleted ? Color.secondary : Color.haven)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isCompleted ? Color.secondary.opacity(0.15) : Color.haven.opacity(0.15))
            .cornerRadius(8)
        }
        .disabled(isLoading || isCompleted)
    }
}

#Preview {
    VStack(spacing: 16) {
        InviteLinkPreviewContainer(isIncoming: true, timestamp: "10:00 AM") {
            InviteLinkHeader(
                icon: "number.circle.fill",
                title: "Test Channel",
                subtitle: "A test channel description"
            )
            InviteLinkButton(
                isLoading: false,
                isCompleted: false,
                completedText: "Joined",
                actionText: "Join Channel",
                errorMessage: nil,
                action: {}
            )
        }
    }
    .padding()
}
