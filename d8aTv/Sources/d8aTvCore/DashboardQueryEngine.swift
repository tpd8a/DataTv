import Foundation
import CoreData

/// Query engine for exploring Core Data dashboard contents
@MainActor
public class DashboardQueryEngine {
    
    private let coreDataManager: CoreDataManager
    private let context: NSManagedObjectContext
    
    public init(coreDataManager: CoreDataManager = CoreDataManager.shared) {
        self.coreDataManager = coreDataManager
        self.context = coreDataManager.context
    }
    
    // MARK: - Dashboard Queries
    
    /// List all dashboards with summary information
    public func listDashboards(appName: String? = nil) {
        let dashboards: [DashboardEntity]
        
        if let appName = appName {
            dashboards = coreDataManager.dashboardsInApp(appName)
            print("📋 Found \(dashboards.count) dashboard(s) in app '\(appName)':")
        } else {
            dashboards = coreDataManager.allDashboards()
            print("📋 Found \(dashboards.count) dashboard(s) across all apps:")
        }
        
        if dashboards.isEmpty {
            print("   No dashboards found")
            return
        }
        
        print()
        
        for dashboard in dashboards {
            // Extract app and dashboard names for display
            let (extractedApp, extractedDashboard) = extractFromCompositeId(dashboard.id)
            let displayApp = dashboard.appName ?? extractedApp ?? "unknown"
            let displayDashboard = dashboard.dashboardName ?? extractedDashboard
            
            print("🔹 \(displayDashboard)")
            print("   App: \(displayApp)")
            if let title = dashboard.title {
                print("   Title: \(title)")
            }
            if let description = dashboard.dashboardDescription {
                print("   Description: \(description)")
            }
            print("   ID: \(dashboard.id)")
            print("   Parsed: \(dashboard.lastParsed)")
            print("   Rows: \(dashboard.rowsArray.count)")
            print("   Fieldsets: \(dashboard.fieldsetsArray.count)")
            print("   Total Tokens: \(dashboard.allTokens.count)")
            print()
        }
    }
    
    /// Show detailed information about a specific dashboard
    public func showDashboard(_ dashboardId: String) {
        guard let dashboard = coreDataManager.findDashboard(by: dashboardId) else {
            print("❌ Dashboard '\(dashboardId)' not found")
            return
        }
        
        // Extract app and dashboard names for display
        let (extractedApp, extractedDashboard) = extractFromCompositeId(dashboard.id)
        let displayApp = dashboard.appName ?? extractedApp ?? "unknown"
        let displayDashboard = dashboard.dashboardName ?? extractedDashboard
        
        print("📊 Dashboard Details:")
        print("═" * 50)
        print("App: \(displayApp)")
        print("Name: \(displayDashboard)")
        print("ID: \(dashboard.id)")
        print()
        
        // Basic info
        if let title = dashboard.title {
            print("Title: \(title)")
        }
        if let description = dashboard.dashboardDescription {
            print("Description: \(description)")
        }
        if let version = dashboard.version {
            print("Version: \(version)")
        }
        if let theme = dashboard.theme {
            print("Theme: \(theme)")
        }
        
        print("Last Parsed: \(dashboard.lastParsed)")
        print("Hide Edit: \(dashboard.hideEdit)")
        print("Hide Export: \(dashboard.hideExport)")
        
        if dashboard.refreshInterval > 0 {
            print("Refresh Interval: \(dashboard.refreshInterval)s")
        }
        
        print()
        
        // Fieldsets and tokens
        print("📝 Form Inputs:")
        if dashboard.fieldsetsArray.isEmpty {
            print("  No fieldsets found")
        } else {
            for fieldset in dashboard.fieldsetsArray {
                print("  🔸 Fieldset: \(fieldset.id)")
                print("    Submit Button: \(fieldset.submitButton)")
                print("    Auto Run: \(fieldset.autoRun)")
                
                if !fieldset.tokensArray.isEmpty {
                    print("    Tokens:")
                    for token in fieldset.tokensArray {
                        print("      • \(token.name) (\(token.tokenType.displayName))")
                        if let defaultValue = token.defaultValue {
                            print("        Default: \(defaultValue)")
                        }
                        if token.hasChoices {
                            print("        Choices: \(token.choicesArray.count)")
                        }
                    }
                }
                print()
            }
        }
        
        // Rows and panels
        print("📐 Layout Structure:")
        if dashboard.rowsArray.isEmpty {
            print("  No rows found")
        } else {
            for row in dashboard.rowsArray {
                print("  📏 Row: \(row.id)")
                if let depends = row.depends {
                    print("    Depends: \(depends)")
                }
                
                for panel in row.panelsArray {
                    print("    📊 Panel: \(panel.id)")
                    if let title = panel.title {
                        print("       Title: \(title)")
                    }
                    if let ref = panel.ref {
                        print("       Ref: \(ref)")
                    }
                    
                    // Show visualizations
                    if !panel.visualizationsArray.isEmpty {
                        print("       Visualizations:")
                        for viz in panel.visualizationsArray {
                            print("         • \(viz.type)")
                            if let title = viz.title {
                                print("           Title: \(title)")
                            }
                        }
                    }
                    
                    // Show searches
                    if !panel.searchesArray.isEmpty {
                        print("       Searches:")
                        for search in panel.searchesArray {
                            if let query = search.query {
                                let truncated = query.count > 60 ? String(query.prefix(60)) + "..." : query
                                print("         • \(truncated)")
                            }
                            if ((search.refresh?.isEmpty) == nil) {
                                print("           Refresh: \(search.refresh ?? "")")
                            }
                            if !search.tokenReferencesArray.isEmpty {
                                print("           Tokens: \(search.tokenReferencesArray.joined(separator: ", "))")
                            }
                        }
                    }
                }
                print()
            }
        }
        
        // Global searches
        if !dashboard.globalSearchesArray.isEmpty {
            print("🔍 Global Searches:")
            for search in dashboard.globalSearchesArray {
                if let query = search.query {
                    let truncated = query.count > 80 ? String(query.prefix(80)) + "..." : query
                    print("  • \(truncated)")
                }
                if !search.tokenReferencesArray.isEmpty {
                    print("    Tokens: \(search.tokenReferencesArray.joined(separator: ", "))")
                }
            }
            print()
        }
        
        // Custom content
        if !dashboard.customContentArray.isEmpty {
            print("🎨 Custom Content:")
            for content in dashboard.customContentArray {
                print("  • \(content.contentType): \(content.id)")
            }
            print()
        }
    }
    
    // MARK: - Token Queries
    
    /// List all tokens across all dashboards
    public func listAllTokens(inApp appName: String? = nil) {
        let dashboards: [DashboardEntity]
        
        if let appName = appName {
            dashboards = coreDataManager.dashboardsInApp(appName)
            print("🏷️ Listing tokens in app '\(appName)':")
        } else {
            dashboards = coreDataManager.allDashboards()
            print("🏷️ Listing tokens across all apps:")
        }
        
        var allTokens: [TokenEntity] = []
        
        for dashboard in dashboards {
            allTokens.append(contentsOf: dashboard.allTokens)
        }
        
        if allTokens.isEmpty {
            print("   No tokens found")
            return
        }
        
        print("   Found \(allTokens.count) token(s):")
        print()
        
        let groupedTokens = Dictionary(grouping: allTokens) { $0.tokenType }
        
        for (tokenType, tokens) in groupedTokens.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            print("📂 \(tokenType.displayName) (\(tokens.count))")
            for token in tokens.sorted(by: { $0.name < $1.name }) {
                print("  • \(token.name)")
                if let defaultValue = token.defaultValue {
                    print("    Default: \(defaultValue)")
                }
                if token.hasChoices {
                    print("    Choices: \(token.choicesArray.map { $0.value }.joined(separator: ", "))")
                }
                if let dashboard = token.fieldset?.dashboard ?? token.panel?.row?.dashboard {
                    let (extractedApp, extractedDashboard) = extractFromCompositeId(dashboard.id)
                    let displayApp = dashboard.appName ?? extractedApp ?? "unknown"
                    let displayDashboard = dashboard.dashboardName ?? extractedDashboard
                    print("    App/Dashboard: \(displayApp)/\(displayDashboard)")
                }
            }
            print()
        }
    }
    
    /// Search for tokens by name pattern
    public func findTokens(matching pattern: String, inApp appName: String? = nil) {
        let dashboards: [DashboardEntity]
        
        if let appName = appName {
            dashboards = coreDataManager.dashboardsInApp(appName)
            print("🔍 Searching for tokens matching '\(pattern)' in app '\(appName)':")
        } else {
            dashboards = coreDataManager.allDashboards()
            print("🔍 Searching for tokens matching '\(pattern)' across all apps:")
        }
        
        var matchingTokens: [TokenEntity] = []
        let lowercasePattern = pattern.lowercased()
        
        for dashboard in dashboards {
            for token in dashboard.allTokens {
                if token.name.lowercased().contains(lowercasePattern) {
                    matchingTokens.append(token)
                }
            }
        }
        
        if matchingTokens.isEmpty {
            print("   No tokens found matching '\(pattern)'")
            return
        }
        
        print("   Found \(matchingTokens.count) token(s) matching '\(pattern)':")
        print()
        
        for token in matchingTokens.sorted(by: { $0.name < $1.name }) {
            // Get dashboard info for this token
            let dashboard = token.fieldset?.dashboard ?? token.panel?.row?.dashboard
            let (extractedApp, extractedDashboard) = DashboardLoader.extractFromCompositeId(dashboard?.id ?? "unknown")
            
            print("🏷️ \(token.name) (\(token.tokenType.displayName))")
            let appName = dashboard?.appName ?? extractedApp
            if let appName = appName {
                print("   App: \(appName)")
            }
            let dashboardName = dashboard?.dashboardName ?? extractedDashboard
            print("   Dashboard: \(dashboardName)")
            if let defaultValue = token.defaultValue {
                print("   Default: \(defaultValue)")
            }
            if let label = token.label {
                print("   Label: \(label)")
            }
            if token.hasChoices {
                print("   Choices: \(token.choicesArray.map { $0.value }.joined(separator: ", "))")
            }
            if let dashboard = token.fieldset?.dashboard ?? token.panel?.row?.dashboard {
                let (extractedApp, extractedDashboard) = extractFromCompositeId(dashboard.id)
                let displayApp = dashboard.appName ?? extractedApp ?? "unknown"
                let displayDashboard = dashboard.dashboardName ?? extractedDashboard
                print("   App: \(displayApp)")
                print("   Dashboard: \(displayDashboard)")
            }
            print()
        }
    }
    
    /// Show detailed token information
    public func showToken(_ tokenName: String, in dashboardId: String? = nil) {
        let dashboards = dashboardId != nil ?
        [coreDataManager.findDashboard(by: dashboardId!)].compactMap { $0 } :
        coreDataManager.allDashboards()
        
        var foundTokens: [TokenEntity] = []
        
        for dashboard in dashboards {
            foundTokens.append(contentsOf: dashboard.allTokens.filter { $0.name == tokenName })
        }
        
        if foundTokens.isEmpty {
            print("❌ Token '\(tokenName)' not found")
            return
        }
        
        for token in foundTokens {
            print("🏷️ Token: \(token.name)")
            print("═" * 30)
            print("Type: \(token.tokenType.displayName)")
            
            if let label = token.label {
                print("Label: \(label)")
            }
            if let defaultValue = token.defaultValue {
                print("Default Value: \(defaultValue)")
            }
            if let prefix = token.prefix {
                print("Prefix: \(prefix)")
            }
            if let suffix = token.suffix {
                print("Suffix: \(suffix)")
            }
            
            print("Search When Changed: \(token.searchWhenChanged)")
            print("Submit On Change: \(token.submitOnChange)")
            print("Required: \(token.required)")
            
            if let depends = token.depends {
                print("Depends: \(depends)")
            }
            if let populatingSearch = token.populatingSearch {
                print("Populating Search: \(populatingSearch)")
            }
            
            // Show choices
            if token.hasChoices {
                print("\nChoices:")
                for choice in token.choicesArray {
                    let marker = choice.isDefault ? " (default)" : ""
                    print("  • \(choice.value): \(choice.label)\(marker)")
                }
            }
            
            // Show conditions
            if token.hasConditions {
                print("\nConditions:")
                for condition in token.conditionsArray {
                    print("  🔄 \(condition.id)")
                    if let match = condition.match {
                        print("     Match: \(match)")
                    }
                    for action in condition.actionsArray {
                        print("     Action: \(action.action) \(action.targetToken) = \(action.value ?? action.expression ?? "N/A")")
                    }
                }
            }
            
            if let dashboard = token.fieldset?.dashboard ?? token.panel?.row?.dashboard {
                let (extractedApp, extractedDashboard) = extractFromCompositeId(dashboard.id)
                let displayApp = dashboard.appName ?? extractedApp ?? "unknown"
                let displayDashboard = dashboard.dashboardName ?? extractedDashboard
                print("\nApp: \(displayApp)")
                print("Dashboard: \(displayDashboard)")
            }
            
            print()
        }
    }
    
    // MARK: - Search Queries
    
    /// List all searches with token usage
    public func listSearches(in dashboardId: String? = nil) {
        let dashboards = dashboardId != nil ?
        [coreDataManager.findDashboard(by: dashboardId!)].compactMap { $0 } :
        coreDataManager.allDashboards()
        
        var allSearches: [(search: SearchEntity, dashboard: DashboardEntity)] = []
        
        for dashboard in dashboards {
            for search in dashboard.allSearches {
                allSearches.append((search, dashboard))
            }
        }
        
        if allSearches.isEmpty {
            print("🔍 No searches found")
            return
        }
        
        print("🔍 Found \(allSearches.count) search(es):")
        print()
        
        for (search, dashboard) in allSearches {
            let (extractedApp, extractedDashboard) = extractFromCompositeId(dashboard.id)
            let displayApp = dashboard.appName ?? extractedApp ?? "unknown"
            let displayDashboard = dashboard.dashboardName ?? extractedDashboard
            
            print("🔎 \(search.id)")
            print("   App: \(displayApp)")
            print("   Dashboard: \(displayDashboard)")
            
            if let query = search.query {
                let truncated = query.count > 100 ? String(query.prefix(100)) + "..." : query
                print("   Query: \(truncated)")
            }
            
            let tokenRefs = search.tokenReferencesArray
            if !tokenRefs.isEmpty {
                print("   Tokens: \(tokenRefs.joined(separator: ", "))")
            }
            
            if let earliest = search.earliestTime {
                print("   Earliest: \(earliest)")
            }
            if let latest = search.latestTime {
                print("   Latest: \(latest)")
            }
            
            print("   Autostart: \(search.autostart)")
            print()
        }
    }
    
    /// Find searches containing specific tokens
    public func findSearchesUsing(token tokenName: String) {
        let dashboards = coreDataManager.allDashboards()
        var matchingSearches: [(search: SearchEntity, dashboard: DashboardEntity)] = []
        
        for dashboard in dashboards {
            for search in dashboard.allSearches {
                if search.tokenReferencesArray.contains(tokenName) {
                    matchingSearches.append((search, dashboard))
                }
            }
        }
        
        if matchingSearches.isEmpty {
            print("🔍 No searches found using token '\(tokenName)'")
            return
        }
        
        print("🔍 Found \(matchingSearches.count) search(es) using token '\(tokenName)':")
        print()
        
        for (search, dashboard) in matchingSearches {
            let (extractedApp, extractedDashboard) = extractFromCompositeId(dashboard.id)
            let displayApp = dashboard.appName ?? extractedApp ?? "unknown"
            let displayDashboard = dashboard.dashboardName ?? extractedDashboard
            
            print("🔎 \(search.id)")
            print("   App: \(displayApp)")
            print("   Dashboard: \(displayDashboard)")
            if let query = search.query {
                print("   \(query)")
            }
            print()
        }
    }
    
    // MARK: - Statistics
    
    /// Show statistics about loaded dashboards
    public func showStatistics() {
        let dashboards = coreDataManager.allDashboards()
        
        if dashboards.isEmpty {
            print("📊 No dashboards loaded")
            return
        }
        
        print("📊 Dashboard Statistics")
        print("═" * 30)
        print("Total Dashboards: \(dashboards.count)")
        
        let totalRows = dashboards.reduce(0) { $0 + $1.rowsArray.count }
        let totalPanels = dashboards.reduce(0) { sum, dashboard in
            sum + dashboard.rowsArray.reduce(0) { $0 + $1.panelsArray.count }
        }
        let totalTokens = dashboards.reduce(0) { $0 + $1.allTokens.count }
        let totalSearches = dashboards.reduce(0) { $0 + $1.allSearches.count }
        
        print("Total Rows: \(totalRows)")
        print("Total Panels: \(totalPanels)")
        print("Total Tokens: \(totalTokens)")
        print("Total Searches: \(totalSearches)")
        
        // Token type breakdown
        var tokenTypeCounts: [CoreDataTokenType: Int] = [:]
        for dashboard in dashboards {
            for token in dashboard.allTokens {
                tokenTypeCounts[token.tokenType, default: 0] += 1
            }
        }
        
        if !tokenTypeCounts.isEmpty {
            print("\nToken Types:")
            for (type, count) in tokenTypeCounts.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
                print("  \(type.displayName): \(count)")
            }
        }
        
        // Dashboards by theme
        let themes = dashboards.compactMap { $0.theme }
        if !themes.isEmpty {
            let themeCounts = Dictionary(grouping: themes) { $0 }
                .mapValues { $0.count }
            
            print("\nThemes:")
            for (theme, count) in themeCounts.sorted(by: { $0.key < $1.key }) {
                print("  \(theme): \(count)")
            }
        }
        
        print()
    }
}

// MARK: - Helper Functions

/// Extract app name and dashboard ID from composite ID
/// Returns tuple of (appName, dashboardId) or (nil, originalId) if not a composite ID
private func extractFromCompositeId(_ compositeId: String) -> (appName: String?, dashboardId: String) {
    let parts = compositeId.components(separatedBy: "§")
    if parts.count == 2 {
        return (appName: parts[0], dashboardId: parts[1])
    } else {
        return (appName: nil, dashboardId: compositeId)
    }
}

// MARK: - String Extension for Formatting

private extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}
