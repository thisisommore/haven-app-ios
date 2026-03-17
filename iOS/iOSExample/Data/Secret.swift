//
//  Secret.swift
//  iOSExample
//
//  Created by Om More on 18/10/25.
//

import Foundation

enum KeychainError: Error {
  case noPassword
  case unexpectedPasswordData
  case unhandledError(status: OSStatus)
}

@Observable
final class AppStorage {
  var isSetupComplete: Bool {
    get { UserDefaults.standard.bool(forKey: Self.setupCompleteKey) }
    set {
      UserDefaults.standard.set(newValue, forKey: Self.setupCompleteKey)
    }
  }

  private(set) var isPasswordSet: Bool = false
  private static let setupCompleteKey = "isSetupComplete"
  private static let baseQuery: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: "internalPassword",
  ]

  private static var searchQuery: [String: Any] = {
    var query = AppStorage.baseQuery
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    query[kSecReturnAttributes as String] = true
    query[kSecReturnData as String] = true
    return query
  }()

  init() {
    self.updatePasswordStatus()
  }

  /// Store password in keychain
  func storePassword(_ password: String) throws {
    var query = Self.baseQuery

    // Delete existing item if present
    SecItemDelete(query as CFDictionary)
    query[kSecValueData as String] = password.data
    query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

    // Add new item
    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess
    else {
      throw KeychainError.unhandledError(status: status)
    }

    self.updatePasswordStatus()
  }

  /// Retrieve password from keychain
  func getPassword() throws -> String {
    var item: CFTypeRef?
    let status = SecItemCopyMatching(Self.searchQuery as CFDictionary, &item)

    guard status != errSecItemNotFound
    else {
      throw KeychainError.noPassword
    }

    guard status == errSecSuccess
    else {
      throw KeychainError.unhandledError(status: status)
    }

    guard let existingItem = item as? [String: Any],
          let passwordData = existingItem[kSecValueData as String] as? Data,
          let password = try? passwordData.utf8()
    else {
      throw KeychainError.unexpectedPasswordData
    }

    return password
  }

  /// Delete password from keychain
  func deletePassword() throws {
    let status = SecItemDelete(Self.baseQuery as CFDictionary)

    guard status == errSecSuccess || status == errSecItemNotFound
    else {
      throw KeychainError.unhandledError(status: status)
    }

    self.updatePasswordStatus()
  }

  /// Clear all data (keychain + UserDefaults) for logout/reset
  func clearAll() {
    // Clear keychain
    self.clearKeychain()

    // Clear UserDefaults
    if let bundleId = Bundle.main.bundleIdentifier {
      UserDefaults.standard.removePersistentDomain(forName: bundleId)
    }

    self.updatePasswordStatus()
  }

  /// Clear all keychain items
  private func clearKeychain() {
    let secClasses = [
      kSecClassGenericPassword,
      kSecClassInternetPassword,
      kSecClassCertificate,
      kSecClassKey,
      kSecClassIdentity,
    ]

    for secClass in secClasses {
      let query: [String: Any] = [kSecClass as String: secClass]
      SecItemDelete(query as CFDictionary)
    }
  }

  /// Update the published isPasswordSet property
  private func updatePasswordStatus() {
    var query = AppStorage.baseQuery
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    let status = SecItemCopyMatching(query as CFDictionary, nil)
    let exist = status == errSecSuccess
    if self.isPasswordSet != exist {
      self.isPasswordSet = exist
    }
  }
}
