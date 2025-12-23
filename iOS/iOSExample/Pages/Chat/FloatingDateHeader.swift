//
//  FloatingDateHeader.swift
//  iOSExample
//
//  Created by Om More on 22/09/25.
//

import SwiftUI

struct FloatingDateHeader: View {
    let date: Date?
    let scrollingToOlder: Bool

    private var dateText: String {
        guard let date else { return "" }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = calendar.isDate(date, equalTo: Date(), toGranularity: .year) ? "EEE d MMM" : "EEE d MMM yyyy"
            return formatter.string(from: date)
        }
    }

    var body: some View {
        if date != nil {
            Text(dateText)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                .id(dateText)
                .transition(.asymmetric(
                    insertion: .opacity,
                    removal: .offset(y: scrollingToOlder ? 30 : -30).combined(with: .opacity)
                ))
        }
    }
}

