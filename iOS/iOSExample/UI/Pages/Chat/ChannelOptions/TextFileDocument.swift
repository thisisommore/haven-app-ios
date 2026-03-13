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

  var text: String

  init(text: String) {
    self.text = text
  }

  init(configuration: ReadConfiguration) throws {
    if let data = configuration.file.regularFileContents {
      self.text = String(data: data, encoding: .utf8) ?? ""
    } else {
      self.text = ""
    }
  }

  func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
    FileWrapper(regularFileWithContents: self.text.data(using: .utf8) ?? Data())
  }
}
