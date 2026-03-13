//
//  Common.swift
//  iOSExample
//
//  Created by Om More on 10/03/26.
//
import Foundation

extension Int {
  func idxPath() -> IndexPath {
    return IndexPath(item: self, section: 0)
  }
}

extension IndexPath {
  func next() -> IndexPath {
    return IndexPath(item: item + 1, section: section)
  }
}
