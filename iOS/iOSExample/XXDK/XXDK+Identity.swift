//
//  XXDK+Identity.swift
//  iOSExample
//
//  Created by Om More on 17/03/26.
//

import Bindings
import Foundation

extension XXDK {
  /// Generate multiple channel identities
  func generateIdentities(amountOfIdentities: Int) -> [GeneratedIdentity] {
    guard let cmix
    else {
      AppLogger.identity.error("cmix is not available")
      return []
    }

    var identities: [GeneratedIdentity] = []

    for _ in 0 ..< amountOfIdentities {
      let privateIdentity: Data?
      do {
        privateIdentity = try BindingsStatic.generateChannelIdentity(cmix.getID())
      } catch {
        AppLogger.identity.error(
          "Failed to generate private identity: \(error.localizedDescription, privacy: .public)"
        )
        continue
      }

      guard let privateIdentity
      else {
        AppLogger.identity.error("Failed to generate private identity: returned nil")
        continue
      }

      let publicIdentity: IdentityJSON?
      do {
        publicIdentity = try BindingsStatic.getPublicChannelIdentityFromPrivate(
          privateIdentity
        )
      } catch {
        AppLogger.identity.error(
          "Failed to derive public identity: \(error.localizedDescription, privacy: .public)"
        )
        continue
      }

      guard let identity = publicIdentity
      else {
        AppLogger.identity.error("Failed to derive public identity: returned nil")
        continue
      }

      let generatedIdentity = GeneratedIdentity(
        privateIdentity: privateIdentity,
        codename: identity.Codename,
        codeset: identity.CodesetVersion,
        pubkey: identity.PubKey
      )

      identities.append(generatedIdentity)
    }

    return identities
  }

  func savePrivateIdentity(privateIdentity: Data) throws {
    guard let cmix
    else {
      throw XXDKError.cmixNotInitialized
    }
    try cmix.ekvSet("MyPrivateIdentity", value: privateIdentity)
  }

  func loadSavedPrivateIdentity() throws -> Data {
    guard let cmix
    else {
      throw XXDKError.cmixNotInitialized
    }
    return try cmix.ekvGet("MyPrivateIdentity")
  }

  /// Export identity with password encryption
  func exportIdentity(password _: String) throws -> Data {
    return try self.loadSavedPrivateIdentity()
  }

  /// Import a private identity using a password
  func importIdentity(password: String, data: Data) throws -> Data {
    guard
      let imported = try BindingsStatic.importPrivateIdentity(password: password, data: data)
    else {
      throw XXDKError.importReturnedNil
    }
    return imported
  }
}
