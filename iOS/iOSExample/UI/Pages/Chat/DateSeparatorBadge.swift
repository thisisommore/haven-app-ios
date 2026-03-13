//
//  DateSeparatorBadge.swift
//  iOSExample
//
//  Created by Om More on 22/09/25.
//

import SwiftUI

struct DateSeparatorBadge: View {
  let date: Date
  let isFirst: Bool

  private var dateText: String {
    let calendar = Calendar.current
    if calendar.isDateInToday(self.date) {
      return "Today"
    } else if calendar.isDateInYesterday(self.date) {
      return "Yesterday"
    } else {
      let formatter = DateFormatter()
      formatter.dateFormat =
        calendar.isDate(self.date, equalTo: Date(), toGranularity: .year)
          ? "EEE d MMM" : "EEE d MMM yyyy"
      return formatter.string(from: self.date)
    }
  }

  var body: some View {
    HStack {
      Spacer()
      Text(self.dateText)
        .font(.caption)
        .fontWeight(.medium)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
      Spacer()
    }
    .padding(.top, self.isFirst ? 0 : 28)
    .padding(.bottom, 12)
  }
}
