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

  // Cmix
  func newCmix(downloadedNdf: Data) async
  func loadCmix() async
  func logout() async throws

  // network
  func startNetworkFollower() async
  func downloadNdf() async -> Data

  // dm channel clients
  func loadClients(privateIdentity: Data) async
  func setupClients(privateIdentity: Data, successCallback: () -> Void) async

  // identity
  func savePrivateIdentity(privateIdentity: Data) throws
  func loadSavedPrivateIdentity() throws -> Data
  func generateIdentities(amountOfIdentities: Int) -> [GeneratedIdentity]
  func exportIdentity(password: String) throws -> Data
  func importIdentity(password: String, data: Data) throws -> Data
  func addApnsToken(_ token: String)
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
