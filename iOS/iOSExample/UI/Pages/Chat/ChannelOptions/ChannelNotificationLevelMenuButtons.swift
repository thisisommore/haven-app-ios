//
//  ChannelNotificationLevelMenuButtons.swift
//  iOSExample
//

import HavenCore
import SwiftUI

struct ChannelNotificationsLevelMenuButtons: View {
  let levels: [NotificationLevel]
  let selectedLevel: NotificationLevel
  let onSelect: (NotificationLevel) -> Void

  var body: some View {
    ForEach(self.levels, id: \.self) { level in
      Button {
        self.onSelect(level)
      } label: {
        HStack {
          if self.selectedLevel == level {
            Image(systemName: "checkmark")
          }
          Text(level.displayName)
        }
      }
    }
  }
}
