import SwiftUI
import CoreData
import Combine
import DashboardKit

/// Manages token state for dashboards
/// Tracks current values, provides change notifications, and integrates with CoreDataManager
@MainActor
public class DashboardTokenManager: ObservableObject {

    // MARK: - Published State

    /// Current token values for the active dashboard
    @Published public private(set) var tokenValues: [String: TokenValue] = [:]

    /// Token adapters (bridges DashboardInput to token interface)
    @Published public private(set) var tokenAdapters: [String: TokenAdapter] = [:]

    /// Currently active dashboard ID
    @Published public private(set) var activeDashboardId: UUID?

    // MARK: - Singleton

    public static let shared = DashboardTokenManager()

    private init() {
        print("🎛️ DashboardTokenManager initialized")
    }

    // MARK: - Dashboard Token Management

    /// Load tokens for a specific dashboard
    public func loadTokens(for dashboard: Dashboard) {
        guard let dashboardId = dashboard.id else {
            print("⚠️ Dashboard has no ID")
            return
        }

        print("🎛️ Loading tokens for dashboard: \(dashboard.title ?? dashboardId.uuidString)")

        activeDashboardId = dashboardId
        tokenAdapters.removeAll()
        tokenValues.removeAll()

        // Get all inputs from the dashboard
        guard let inputs = dashboard.inputs as? Set<DashboardInput> else {
            print("🎛️ No inputs found")
            return
        }

        // Convert to adapters and initialize values
        for input in inputs {
            let adapter = TokenAdapter(input: input)
            tokenAdapters[adapter.name] = adapter

            // Initialize with default or initial value
            let initialValue = adapter.initialValue ?? ""
            let tokenValue = TokenValue(
                name: adapter.name,
                value: initialValue,
                source: .default,
                lastUpdated: Date()
            )

            tokenValues[adapter.name] = tokenValue
            print("  ✅ Token '\(adapter.name)': \(initialValue)")
        }

        print("🎛️ Loaded \(tokenValues.count) token(s)")
    }

    /// Update a token value
    public func setTokenValue(_ value: String, forToken name: String, source: TokenValueSource = .user) {
        guard activeDashboardId != nil else {
            print("⚠️ No active dashboard, cannot set token value")
            return
        }

        let tokenValue = TokenValue(
            name: name,
            value: value,
            source: source,
            lastUpdated: Date()
        )

        tokenValues[name] = tokenValue
        print("🎛️ Token '\(name)' set to '\(value)' (source: \(source.rawValue))")

        // Post notification for listeners
        NotificationCenter.default.post(
            name: .tokenValueChanged,
            object: nil,
            userInfo: [
                "tokenName": name,
                "tokenValue": value,
                "dashboardId": activeDashboardId as Any,
                "source": source.rawValue
            ]
        )
    }

    /// Get current value for a token
    public func getValue(forToken name: String) -> String? {
        return tokenValues[name]?.value
    }

    /// Get all current token values as dictionary (for CoreDataManager integration)
    public func getAllValues() -> [String: String] {
        return tokenValues.mapValues { $0.value }
    }

    /// Clear all tokens
    public func clearTokens() {
        tokenValues.removeAll()
        tokenAdapters.removeAll()
        activeDashboardId = nil
        print("🎛️ All tokens cleared")
    }

    // MARK: - Token Statistics

    /// Get statistics about current token state
    public func getStatistics() -> TokenStatistics {
        let userModified = tokenValues.values.filter { $0.source == .user }.count
        let defaults = tokenValues.values.filter { $0.source == .default }.count
        let calculated = tokenValues.values.filter { $0.source == .calculated }.count

        return TokenStatistics(
            totalTokens: tokenValues.count,
            userModified: userModified,
            defaults: defaults,
            calculated: calculated,
            lastUpdate: tokenValues.values.map { $0.lastUpdated }.max()
        )
    }
}

// MARK: - Supporting Types

/// Represents a token's current value and metadata
public struct TokenValue: Equatable, Identifiable {
    public let id = UUID()
    public let name: String
    public let value: String
    public let source: TokenValueSource
    public let lastUpdated: Date
}

/// Source of token value
public enum TokenValueSource: String {
    case user = "user"              // Set by user input
    case `default` = "default"      // From token default/initial value
    case calculated = "calculated"  // Calculated/computed value
    case search = "search"          // Populated from search results
}

/// Statistics about token state
public struct TokenStatistics {
    public let totalTokens: Int
    public let userModified: Int
    public let defaults: Int
    public let calculated: Int
    public let lastUpdate: Date?
}

// MARK: - Notification Extensions

public extension Notification.Name {
    static let tokenValueChanged = Notification.Name("tokenValueChanged")
}
