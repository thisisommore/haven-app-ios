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

public class SecretManager: ObservableObject {
    @Published var isPasswordSet: Bool = false

    private let serviceName = "internalPassword"
    private let setupCompleteKey = "isSetupComplete"

    var isSetupComplete: Bool {
        get { UserDefaults.standard.bool(forKey: setupCompleteKey) }
        set { UserDefaults.standard.set(newValue, forKey: setupCompleteKey) }
    }

    init() {
        updatePasswordStatus()
    }

    /// Store password in keychain
    func storePassword(_ password: String) throws {
        guard let passData = password.data(using: .utf8) else {
            throw KeychainError.unexpectedPasswordData
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecValueData as String: passData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        // Delete existing item if present
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }

        updatePasswordStatus()
    }

    /// Retrieve password from keychain
    func getPassword() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status != errSecItemNotFound else {
            throw KeychainError.noPassword
        }

        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }

        guard let existingItem = item as? [String: Any],
              let passwordData = existingItem[kSecValueData as String] as? Data,
              let password = String(data: passwordData, encoding: .utf8)
        else {
            throw KeychainError.unexpectedPasswordData
        }

        return password
    }

    /// Check if password is set in keychain
    func checkPasswordExists() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        return status == errSecSuccess
    }

    /// Delete password from keychain
    func deletePassword() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }

        updatePasswordStatus()
    }

    /// Clear all data (keychain + UserDefaults) for logout/reset
    func clearAll() {
        // Clear keychain
        clearKeychain()

        // Clear UserDefaults
        if let bundleId = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleId)
        }
        UserDefaults.standard.synchronize()

        updatePasswordStatus()
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
        isPasswordSet = checkPasswordExists()
    }
}

/*

 // In your SwiftUI View:
 @StateObject private var keychainManager = KeychainManager()

 // Store password
 do {
     try keychainManager.storePassword("mySecurePassword123")
     print("Password stored successfully")
 } catch {
     print("Error storing password: \(error)")
 }

 // Get password
 do {
     let password = try keychainManager.getPassword()
     print("Retrieved password: \(password)")
 } catch {
     print("Error retrieving password: \(error)")
 }

 // Check if password exists (using published property)
 if keychainManager.isPasswordSet {
     print("Password is set")
 }

 // Delete password
 do {
     try keychainManager.deletePassword()
     print("Password deleted")
 } catch {
     print("Error deleting password: \(error)")
 }

 */
