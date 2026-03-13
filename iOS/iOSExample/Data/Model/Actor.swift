//
//  Actor.swift
//  iOSExample
//
//  Created by Om More on 16/10/25.
//

import Foundation
import SQLiteData

actor DatabaseActor {
  let database: any DatabaseWriter

  init(database: any DatabaseWriter) {
    self.database = database
  }

  func read<T: Sendable>(_ block: @Sendable (Database) throws -> T) throws -> T {
    try self.database.read(block)
  }

  func write<T: Sendable>(_ block: @Sendable (Database) throws -> T) throws -> T {
    try self.database.write(block)
  }
}
