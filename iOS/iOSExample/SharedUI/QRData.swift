//
//  QRData.swift
//  iOSExample
//
//  Payload for the "share my contact" QR code sheet.
//

import Foundation

struct QRData: Identifiable {
  let id = UUID()
  let token: Int64
  let pubKey: Data
  let codeset: Int
}
