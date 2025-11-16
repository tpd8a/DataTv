import SwiftUI
import CoreData
import Combine
import d8aTvCore

/// Manages token state for dashboards
/// Tracks current values, provides change notifications, and integrates with CoreDataManager
@MainActor
public class DashboardTokenManager: ObservableObject {
    
    // MARK: - Published State
    
    /// Current token values for the active dashboard
    @Published public private(set) var tokenValues: [String: TokenValue] = [:]
    
    /// Token definitions from CoreData
    @Published public private(set) var tokenDefinitions: [String: TokenEntity] = [:]
    
    /// Currently active dashboard
    @Published public private(set) var activeDashboardId: String?
    
    // MARK: - Singleton
    
    public static let shared = DashboardTokenManager()
    
    private init() {
        print("🎛️ DashboardTokenManager initialized")
    }
    
    // MARK: - Dashboard Token Management
    
    /// Load tokens for a specific dashboard
    public func loadTokens(for dashboard: DashboardEntity) {
        print("🎛️ Loading tokens for dashboard: \(dashboard.id)")
        
        activeDashboardId = dashboard.id
        tokenDefinitions.removeAll()
        tokenValues.removeAll()
        
        // Get all tokens from the dashboard
        let allTokens = dashboard.allTokens
        
        for token in allTokens {
            tokenDefinitions[token.name] = token
            
            // Initialize with default or initial value
            let initialValue = token.initialValue ?? token.defaultValue ?? ""
            let tokenValue = TokenValue(
                name: token.name,
                value: initialValue,
                source: .default,
                lastUpdated: Date()
            )
            
            tokenValues[token.name] = tokenValue
            print("  ✅ Token '\(token.name)': \(initialValue)")
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
        tokenDefinitions.removeAll()
        activeDashboardId = nil
        print("🎛️ All tokens cleared")
    }
    
    // MARK: - CoreDataManager Integration
    
    /// Execute a search using current token values
    public func executeSearch(
        searchId: String,
        in dashboardId: String,
        timeRange: (earliest: String?, latest: String?)? = nil,
        parameterOverrides: SearchParameterOverrides = SearchParameterOverrides(),
        splunkCredentials: SplunkCredentials? = nil
    ) -> String {
        let userTokenValues = getAllValues()
        
        print("🎛️ Executing search '\(searchId)' with \(userTokenValues.count) token(s)")
        for (name, value) in userTokenValues {
            print("  🎯 \(name) = '\(value)'")
        }
        
        return CoreDataManager.shared.startSearchExecution(
            searchId: searchId,
            in: dashboardId,
            userTokenValues: userTokenValues,
            timeRange: timeRange,
            parameterOverrides: parameterOverrides,
            splunkCredentials: splunkCredentials
        )
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

// MARK: - Token Debug View

/// Debug view showing all tokens and their current state
struct TokenDebugView: View {
    @ObservedObject private var tokenManager = DashboardTokenManager.shared
    @State private var isExpanded = false
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                // Header with expand/collapse
                Button {
                    withAnimation {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Image(systemName: "list.bullet.rectangle")
                            .foregroundStyle(.purple)
                        
                        Text("Token Registry")
                            .font(.headline)
                        
                        Spacer()
                        
                        let stats = tokenManager.getStatistics()
                        Text("\(stats.totalTokens) tokens")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                
                if isExpanded {
                    Divider()
                    
                    // Statistics
                    statisticsSection
                    
                    Divider()
                    
                    // Token list
                    if tokenManager.tokenValues.isEmpty {
                        Text("No tokens loaded")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    } else {
                        tokenListSection
                    }
                }
            }
        }
    }
    
    private var statisticsSection: some View {
        let stats = tokenManager.getStatistics()
        
        return VStack(spacing: 6) {
            HStack(spacing: 16) {
                statBadge(label: "Total", value: "\(stats.totalTokens)", color: .blue)
                statBadge(label: "User", value: "\(stats.userModified)", color: .green)
                statBadge(label: "Default", value: "\(stats.defaults)", color: .gray)
            }
            
            if let lastUpdate = stats.lastUpdate {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text("Last update: \(lastUpdate, formatter: timeFormatter)")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
        }
    }
    
    private func statBadge(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var tokenListSection: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(Array(tokenManager.tokenValues.values).sorted(by: { $0.name < $1.name })) { tokenValue in
                    TokenDebugRow(tokenValue: tokenValue)
                }
            }
        }
        .frame(maxHeight: 300)
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }
}

// MARK: - Token Debug Row

struct TokenDebugRow: View {
    let tokenValue: TokenValue
    @ObservedObject private var tokenManager = DashboardTokenManager.shared
    
    var body: some View {
        HStack(spacing: 8) {
            // Source indicator
            sourceIcon
                .frame(width: 20)
            
            // Token name
            VStack(alignment: .leading, spacing: 2) {
                Text(tokenValue.name)
                    .font(.caption)
                    .fontWeight(.medium)
                
                if let definition = tokenManager.tokenDefinitions[tokenValue.name] {
                    Text(definition.label ?? definition.type)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Current value
            VStack(alignment: .trailing, spacing: 2) {
                Text(tokenValue.value.isEmpty ? "(empty)" : tokenValue.value)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(tokenValue.value.isEmpty ? .secondary : .primary)
                
                Text(tokenValue.lastUpdated, formatter: timeFormatter)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(rowBackground)
        .cornerRadius(6)
    }
    
    private var sourceIcon: some View {
        let (icon, color) = sourceIndicator
        return Image(systemName: icon)
            .font(.caption)
            .foregroundStyle(color)
    }
    
    private var sourceIndicator: (icon: String, color: Color) {
        switch tokenValue.source {
        case .user:
            return ("person.fill", .green)
        case .default:
            return ("gear", .gray)
        case .calculated:
            return ("function", .blue)
        case .search:
            return ("magnifyingglass", .orange)
        }
    }
    
    private var rowBackground: Color {
        switch tokenValue.source {
        case .user:
            return Color.green.opacity(0.1)
        case .default:
            return Color.gray.opacity(0.05)
        case .calculated:
            return Color.blue.opacity(0.1)
        case .search:
            return Color.orange.opacity(0.1)
        }
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }
}

// MARK: - Preview

#if DEBUG
struct TokenDebugView_Previews: PreviewProvider {
    static var previews: some View {
        TokenDebugView()
            .padding()
    }
}
#endif
