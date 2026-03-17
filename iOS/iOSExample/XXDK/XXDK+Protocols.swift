//
//  XXDK+Protocols.swift
//  iOSExample
//
//  Created by Om More on 24/09/25.
//

import Bindings
import Foundation
import Kronos
import SQLiteData
import SwiftData

struct GeneratedIdentity {
  let privateIdentity: Data
  let codename: String
  let codeset: Int
  let pubkey: String
}

protocol XXDKP: ObservableObject, AnyObject {
  associatedtype ChannelType: ChannelsP
  associatedtype DirectMessageType: DirectMessageP
  var status: String { get }
  var statusPercentage: Double { get }
  var codename: String? { get }
  var codeset: Int { get }
  var channel: ChannelType { get }
  var dm: DirectMessageType? { get }
  func newCmix(downloadedNdf: Data) async
  func loadCmix() async
  func startNetworkFollower() async
  func downloadNdf() async -> Data
  func loadClients(privateIdentity: Data) async
  func setupClients(privateIdentity: Data, successCallback: () -> Void) async
  func savePrivateIdentity(privateIdentity: Data) throws
  func loadSavedPrivateIdentity() throws -> Data
  func generateIdentities(amountOfIdentities: Int) -> [GeneratedIdentity]
  func setAppStorage(_: AppStorage)
  func exportIdentity(password: String) throws -> Data
  func importIdentity(password: String, data: Data) throws -> Data
  func logout() async throws
}

/// These are common helpers extending the string class which are essential for working with XXDK
extension StringProtocol {
  var data: Data {
    .init(utf8)
  }

  var bytes: [UInt8] {
    .init(utf8)
  }
}

extension DataProtocol {
  func utf8() throws -> String {
    let result = String(bytes: self, encoding: .utf8)
    guard let result else {
      throw XXDKError.invalidUTF8
    }
    return result
  }
}
