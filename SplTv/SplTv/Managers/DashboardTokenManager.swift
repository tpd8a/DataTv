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

            // Apply formatting based on input type
            let formattedValue: String
            let rawValue: String

            if ["multiselect", "checkbox"].contains(adapter.type.lowercased()) && !initialValue.isEmpty {
                // Parse comma-separated values and apply multiselect formatting
                let values = initialValue.split(separator: ",").map {
                    String($0).trimmingCharacters(in: .whitespaces)
                }
                formattedValue = adapter.formatTokenValue("", values: values)
                rawValue = initialValue
            } else if !initialValue.isEmpty {
                // For single-value types, format with prefix/suffix
                formattedValue = adapter.formatTokenValue(initialValue)
                rawValue = initialValue
            } else {
                // Empty value - don't set token at all
                formattedValue = ""
                rawValue = ""
            }

            // Only set token if there's a value
            if !formattedValue.isEmpty {
                let tokenValue = TokenValue(
                    name: adapter.name,
                    value: formattedValue,
                    source: .default,
                    lastUpdated: Date()
                )
                tokenValues[adapter.name] = tokenValue
                print("  ✅ Token '\(adapter.name)': '\(formattedValue)' (from: '\(rawValue)')")

                // Execute change handler if present (with RAW initial value, not formatted)
                if let handler = adapter.changeHandler {
                    let label = adapter.getLabel(forValue: rawValue) ?? rawValue
                    executeChangeHandler(handler, selectedValue: rawValue, selectedLabel: label)
                    print("  🔄 Executed change handler for '\(adapter.name)'")
                }
            } else {
                print("  ⚪ Token '\(adapter.name)': No default value, token not set")
            }
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

    /// Unset (remove) a token value
    public func unsetTokenValue(forToken name: String) {
        guard activeDashboardId != nil else {
            print("⚠️ No active dashboard, cannot unset token value")
            return
        }

        tokenValues.removeValue(forKey: name)
        print("🎛️ Token '\(name)' unset (removed)")

        // Post notification for listeners
        NotificationCenter.default.post(
            name: .tokenValueChanged,
            object: nil,
            userInfo: [
                "tokenName": name,
                "tokenValue": "",
                "dashboardId": activeDashboardId as Any,
                "source": TokenValueSource.user.rawValue
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

    // MARK: - Change Handler Execution

    /// Execute a change handler and apply resulting token updates
    /// - Parameters:
    ///   - handler: The change handler to execute
    ///   - selectedValue: The value of the selected choice
    ///   - selectedLabel: The label of the selected choice
    public func executeChangeHandler(
        _ handler: InputChangeHandler,
        selectedValue: String,
        selectedLabel: String
    ) {
        // Helper function to perform variable substitution
        func substitute(_ input: String?) -> String? {
            guard var result = input else { return nil }

            // Replace $label$
            result = result.replacingOccurrences(of: "$label$", with: selectedLabel)

            // Replace $value$
            result = result.replacingOccurrences(of: "$value$", with: selectedValue)

            // Replace $form.xxx$ with current token values
            for (tokenName, tokenValue) in tokenValues {
                let formToken = "$form.\(tokenName)$"
                result = result.replacingOccurrences(of: formToken, with: tokenValue.value)
            }

            return result
        }

        var tokenUpdates: [String: String?] = [:]

        // Execute unconditional actions first
        for action in handler.unconditionalActions {
            switch action.type {
            case .set:
                tokenUpdates[action.token] = substitute(action.value)
            case .unset:
                tokenUpdates[action.token] = nil
            case .eval:
                tokenUpdates[action.token] = substitute(action.value)
            case .link:
                // Link actions don't set tokens
                break
            }
        }

        // Check conditions and execute matching actions
        for condition in handler.conditions {
            var matches = false

            switch condition.matchType {
            case .label:
                matches = (selectedLabel == condition.matchValue)
            case .value:
                matches = (selectedValue == condition.matchValue)
            case .match:
                // Regex match on value
                if let regex = try? NSRegularExpression(pattern: condition.matchValue) {
                    let nsValue = selectedValue as NSString
                    matches = regex.firstMatch(
                        in: selectedValue,
                        range: NSRange(location: 0, length: nsValue.length)
                    ) != nil
                }
            }

            // If condition matches, execute its actions (first match wins)
            if matches {
                for action in condition.actions {
                    switch action.type {
                    case .set:
                        tokenUpdates[action.token] = substitute(action.value)
                    case .unset:
                        tokenUpdates[action.token] = nil
                    case .eval:
                        tokenUpdates[action.token] = substitute(action.value)
                    case .link:
                        break
                    }
                }
                break // Stop after first matching condition
            }
        }

        // Apply the token updates
        for (tokenName, value) in tokenUpdates {
            if let value = value {
                setTokenValue(value, forToken: tokenName, source: .calculated)
            } else {
                // Unset token
                tokenValues.removeValue(forKey: tokenName)
                print("🎛️ Token '\(tokenName)' unset")
            }
        }
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
