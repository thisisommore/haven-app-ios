//
//  Database.swift
//  iOSExample
//
//  Created by Om More on 06/03/26.
//

import Foundation
import SQLiteData

public func appDatabase(migrate: Bool) throws -> any DatabaseWriter {
  @Dependency(\.context) var context
  var configuration = Configuration()
  #if DEBUG
    configuration.prepareDatabase { db in
      db.trace(options: .profile) {
        if context == .preview {
          print("\($0.expandedDescription)")
        } else {
          AppLogger.storage.debug("\($0.expandedDescription)")
        }
      }
    }
  #endif
  let appSupportDir = FileManager.default.containerURL(
    forSecurityApplicationGroupIdentifier: GROUP_ID
  )
  let dbPath = appSupportDir!.appendingPathComponent("SQLiteData.db").path
  let database = try defaultDatabase(path: dbPath, configuration: configuration)
  if migrate {
    var migrator = DatabaseMigrator()
    #if DEBUG
      migrator.eraseDatabaseOnSchemaChange = true
    #endif

    migrator.v1()
    try migrator.migrate(database)
  }

  return database
}
