//
//  Secret.swift
//  iOSExample
//
//  Created by Om More on 18/10/25.
//

import Combine
import Foundation

enum KeychainError: Error {
  case noPassword
  case unexpectedPasswordData
  case unhandledError(status: OSStatus)
}

final class AppStorage: ObservableObject {
  @Published private(set) var isPasswordSet: Bool = false

  private let serviceName = "internalPassword"
  private let setupCompleteKey = "isSetupComplete"

  private var baseQuery: [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: self.serviceName,
    ]
  }

  private var searchQuery: [String: Any] {
    var query = self.baseQuery
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    query[kSecReturnAttributes as String] = true
    query[kSecReturnData as String] = true
    return query
  }

  var isSetupComplete: Bool {
    get { UserDefaults.standard.bool(forKey: self.setupCompleteKey) }
    set {
      objectWillChange.send()
      UserDefaults.standard.set(newValue, forKey: self.setupCompleteKey)
    }
  }

  init() {
    self.updatePasswordStatus()
  }

  /// Store password in keychain
  func storePassword(_ password: String) throws {
    guard let passData = password.data(using: .utf8)
    else {
      throw KeychainError.unexpectedPasswordData
    }

    var query = self.baseQuery
    query[kSecValueData as String] = passData
    query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

    // Delete existing item if present
    SecItemDelete(query as CFDictionary)

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
    let status = SecItemCopyMatching(searchQuery as CFDictionary, &item)

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

  /// Check if password is set in keychain
  func checkPasswordExists() -> Bool {
    var item: CFTypeRef?
    let status = SecItemCopyMatching(searchQuery as CFDictionary, &item)

    return status == errSecSuccess
  }

  /// Delete password from keychain
  func deletePassword() throws {
    let status = SecItemDelete(baseQuery as CFDictionary)

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
    UserDefaults.standard.synchronize()

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
    self.isPasswordSet = self.checkPasswordExists()
  }
}
