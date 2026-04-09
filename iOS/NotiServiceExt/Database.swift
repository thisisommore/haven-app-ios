//
//  Database.swift
//  iOSExample
//
//  Created by Om More on 09/04/26.
//

import Foundation
import HavenCore
import SQLiteData

enum Database {
  @Dependency(\.defaultDatabase) static var db
  static func title(for report: DMNotificationReport) -> String? {
    let d = try? self.db.read { db in
      try? ChatModel.where {
        $0.pubKey.eq(report.partner)
      }.fetchOne(db)
    }
    return d?.name
  }

  static func title(for report: ChannelNotificationReport) -> String? {
    let d = try? self.db.read { db in
      try? ChatModel.where {
        $0.channelId.eq(report.channel.base64EncodedString())
      }.fetchOne(db)
    }
    guard let d else { return nil }
    return "#" + d.name
  }
}
