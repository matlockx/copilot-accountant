import Foundation
import Security

/// Secure keychain storage for GitHub token
class KeychainService {
    private let service = "com.copilot-accountant.github-token"
    private let account = "github-api-token"
    private let log = LogService.shared
    
    enum KeychainError: Error, LocalizedError {
        case saveFailed(OSStatus)
        case loadFailed(OSStatus)
        case deleteFailed(OSStatus)
        case unexpectedData
        
        var errorDescription: String? {
            switch self {
            case .saveFailed(let status):
                return "Failed to save token to keychain (OSStatus: \(status))"
            case .loadFailed(let status):
                return "Failed to load token from keychain (OSStatus: \(status))"
            case .deleteFailed(let status):
                return "Failed to delete token from keychain (OSStatus: \(status))"
            case .unexpectedData:
                return "Unexpected data format in keychain"
            }
        }
    }
    
    /// Save token to keychain
    func saveToken(_ token: String) throws {
        log.info("Saving token to keychain (length: \(token.count) chars)")
        
        let data = token.data(using: .utf8)!
        
        // First, try to delete any existing token
        try? deleteToken()
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            log.error("Failed to save token to keychain (OSStatus: \(status))")
            throw KeychainError.saveFailed(status)
        }
        
        log.info("Token saved to keychain successfully")
    }
    
    /// Load token from keychain
    func loadToken() throws -> String {
        log.debug("Loading token from keychain")
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            log.warning("Token not found in keychain (OSStatus: \(status))")
            throw KeychainError.loadFailed(status)
        }
        
        guard let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            log.error("Unexpected data format in keychain")
            throw KeychainError.unexpectedData
        }
        
        log.debug("Token loaded from keychain (length: \(token.count) chars)")
        return token
    }
    
    /// Delete token from keychain
    func deleteToken() throws {
        log.info("Deleting token from keychain")
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            log.error("Failed to delete token from keychain (OSStatus: \(status))")
            throw KeychainError.deleteFailed(status)
        }
        
        log.info("Token deleted from keychain")
    }
    
    /// Check if token exists
    func hasToken() -> Bool {
        do {
            _ = try loadToken()
            return true
        } catch {
            return false
        }
    }
}
