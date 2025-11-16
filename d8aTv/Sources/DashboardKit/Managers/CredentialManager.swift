import Foundation
import Security

/// Manager for securely storing and retrieving credentials
public actor CredentialManager {

    public static let shared = CredentialManager()

    private init() {}

    // MARK: - Keychain Operations

    /// Store credentials in keychain
    public func storeCredentials(host: String, username: String, password: String) throws {
        let service = "DashboardKit-\(host)"
        let account = username

        // Delete existing item if present
        _ = try? deleteCredentials(host: host, username: username)

        // Create new item
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: password.data(using: .utf8)!
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw CredentialError.storeFailed(status: status)
        }
    }

    /// Store auth token in keychain
    public func storeAuthToken(host: String, token: String) throws {
        let service = "DashboardKit-Token-\(host)"
        let account = "token"

        // Delete existing item if present
        _ = try? deleteAuthToken(host: host)

        // Create new item
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: token.data(using: .utf8)!
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw CredentialError.storeFailed(status: status)
        }
    }

    /// Retrieve credentials from keychain
    public func retrieveCredentials(host: String, username: String) throws -> String {
        let service = "DashboardKit-\(host)"
        let account = username

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let password = String(data: data, encoding: .utf8) else {
            throw CredentialError.retrieveFailed(status: status)
        }

        return password
    }

    /// Retrieve auth token from keychain
    public func retrieveAuthToken(host: String) throws -> String {
        let service = "DashboardKit-Token-\(host)"
        let account = "token"

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            throw CredentialError.retrieveFailed(status: status)
        }

        return token
    }

    /// Delete credentials from keychain
    public func deleteCredentials(host: String, username: String) throws {
        let service = "DashboardKit-\(host)"
        let account = username

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialError.deleteFailed(status: status)
        }
    }

    /// Delete auth token from keychain
    public func deleteAuthToken(host: String) throws {
        let service = "DashboardKit-Token-\(host)"
        let account = "token"

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialError.deleteFailed(status: status)
        }
    }

    /// Check if credentials exist
    public func hasCredentials(host: String, username: String) -> Bool {
        do {
            _ = try retrieveCredentials(host: host, username: username)
            return true
        } catch {
            return false
        }
    }

    /// Check if auth token exists
    public func hasAuthToken(host: String) -> Bool {
        do {
            _ = try retrieveAuthToken(host: host)
            return true
        } catch {
            return false
        }
    }
}

// MARK: - Errors

public enum CredentialError: Error, LocalizedError {
    case storeFailed(status: OSStatus)
    case retrieveFailed(status: OSStatus)
    case deleteFailed(status: OSStatus)

    public var errorDescription: String? {
        switch self {
        case .storeFailed(let status):
            return "Failed to store credentials (status: \(status))"
        case .retrieveFailed(let status):
            return "Failed to retrieve credentials (status: \(status))"
        case .deleteFailed(let status):
            return "Failed to delete credentials (status: \(status))"
        }
    }
}
