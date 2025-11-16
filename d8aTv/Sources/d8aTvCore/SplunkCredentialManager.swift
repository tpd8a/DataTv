import Foundation
import Security

/// Secure credential storage and retrieval using macOS Keychain
public class SplunkCredentialManager {
    
    private let serviceName = "SplunkDashboardCLI"
    
    public init() {}
    
    /// Store credentials securely in keychain
    public func storeCredentials(server: String, username: String, password: String) throws {
        let account = "\(username)@\(server)"
        
        // Delete existing item if present
        try? deleteCredentials(server: server, username: username)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: server,
            kSecAttrAccount as String: account,
            kSecValueData as String: password.data(using: .utf8) ?? Data(),
            kSecAttrService as String: serviceName
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.storageFailure(status)
        }
    }
    
    /// Store API token securely in keychain  
    public func storeToken(server: String, token: String) throws {
        let account = "token@\(server)"
        
        // Delete existing item if present
        try? deleteToken(server: server)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: server,
            kSecAttrAccount as String: account,
            kSecValueData as String: token.data(using: .utf8) ?? Data(),
            kSecAttrService as String: serviceName
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.storageFailure(status)
        }
    }
    
    /// Retrieve stored credentials from keychain
    public func retrieveCredentials(server: String, username: String) throws -> String {
        let account = "\(username)@\(server)"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: server,
            kSecAttrAccount as String: account,
            kSecAttrService as String: serviceName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess else {
            throw KeychainError.retrievalFailure(status)
        }
        
        guard let passwordData = item as? Data,
              let password = String(data: passwordData, encoding: .utf8) else {
            throw KeychainError.dataCorruption
        }
        
        return password
    }
    
    /// Retrieve stored token from keychain
    public func retrieveToken(server: String) throws -> String {
        let account = "token@\(server)"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: server,
            kSecAttrAccount as String: account,
            kSecAttrService as String: serviceName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess else {
            throw KeychainError.retrievalFailure(status)
        }
        
        guard let tokenData = item as? Data,
              let token = String(data: tokenData, encoding: .utf8) else {
            throw KeychainError.dataCorruption
        }
        
        return token
    }
    
    /// Delete stored credentials
    public func deleteCredentials(server: String, username: String) throws {
        let account = "\(username)@\(server)"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: server,
            kSecAttrAccount as String: account,
            kSecAttrService as String: serviceName
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deletionFailure(status)
        }
    }
    
    /// Delete stored token
    public func deleteToken(server: String) throws {
        let account = "token@\(server)"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: server,
            kSecAttrAccount as String: account,
            kSecAttrService as String: serviceName
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deletionFailure(status)
        }
    }
    
    /// List all stored credentials for this service
    public func listStoredCredentials() throws -> [StoredCredential] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrService as String: serviceName,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        
        var items: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &items)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return []
            }
            throw KeychainError.retrievalFailure(status)
        }
        
        guard let itemArray = items as? [[String: Any]] else {
            return []
        }
        
        return itemArray.compactMap { item in
            guard let server = item[kSecAttrServer as String] as? String,
                  let account = item[kSecAttrAccount as String] as? String else {
                return nil
            }
            
            let isToken = account.hasPrefix("token@")
            let displayAccount = isToken ? "API Token" : account.replacingOccurrences(of: "@\(server)", with: "")
            
            return StoredCredential(
                server: server,
                account: displayAccount,
                isToken: isToken
            )
        }
    }
}

// MARK: - Supporting Types

public struct StoredCredential {
    public let server: String
    public let account: String
    public let isToken: Bool
    
    public var displayString: String {
        return "\(account) @ \(server) (\(isToken ? "Token" : "Password"))"
    }
}

public enum KeychainError: Error, LocalizedError {
    case storageFailure(OSStatus)
    case retrievalFailure(OSStatus)
    case deletionFailure(OSStatus)
    case dataCorruption
    
    public var errorDescription: String? {
        switch self {
        case .storageFailure(let status):
            return "Failed to store credentials in keychain: \(status)"
        case .retrievalFailure(let status):
            return "Failed to retrieve credentials from keychain: \(status)"
        case .deletionFailure(let status):
            return "Failed to delete credentials from keychain: \(status)"
        case .dataCorruption:
            return "Stored credential data is corrupted"
        }
    }
}