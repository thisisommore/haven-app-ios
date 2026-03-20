//
//  TextFileDocument.swift
//  iOSExample
//
//  Created by Om More
//

import SwiftUI
import UniformTypeIdentifiers

struct TextFileDocument: FileDocument {
  static var readableContentTypes: [UTType] {
    [.plainText]
  }

  var data: Data

  init(data: Data) {
    self.data = data
  }

  init(configuration: ReadConfiguration) throws {
    if let data = configuration.file.regularFileContents {
      self.data = data
    } else {
      self.data = Data()
    }
  }

  func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
    FileWrapper(regularFileWithContents: self.data)
  }
}
