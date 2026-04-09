//
//  Filter.swift
//  iOSExample
//
//  Created by Om More on 08/04/26.
//

import Foundation
import HavenCore

struct NotificationFilters {
  let dmFilter: Data?
  let channelFilter: Data?

  static func load() -> NotificationFilters {
    let defaults = UserDefaults(suiteName: GROUP_ID)
    return NotificationFilters(
      dmFilter: defaults?.data(forKey: USER_DEFAULT_DM_NOTIFICATION_FILTER_KEY),
      channelFilter: defaults?.data(forKey: USER_DEFAULT_CHANNEL_NOTIFICATION_FILTER_KEY)
    )
  }
}
