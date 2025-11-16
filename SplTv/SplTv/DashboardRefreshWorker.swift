import Foundation
import Combine
import CoreData
import d8aTvCore

/// Background worker that manages automatic refresh of dashboard searches
/// Runs timers for searches with refresh intervals and executes them periodically
@MainActor
public final class DashboardRefreshWorker: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = DashboardRefreshWorker()
    
    // MARK: - Published State
    @Published public private(set) var activeTimerCount: Int = 0
    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var lastRefreshTime: Date?
    @Published public private(set) var activeSearchTimers: [String: SearchTimerInfo] = [:]
    
    // MARK: - Private Properties
    private var timers: [String: AnyCancellable] = [:]
    private let backgroundContext: NSManagedObjectContext
    
    // MARK: - Dependency Tracking
    /// Maps post-process search keys to their base search IDs
    /// Key: "dashboardId:postProcessSearchId" -> Value: "baseSearchId"
    private var postProcessDependencies: [String: String] = [:]
    
    /// Maps base search IDs to arrays of dependent post-process search keys
    /// Key: "dashboardId:baseSearchId" -> Value: ["dashboardId:dependentSearchId1", ...]
    private var dependentSearches: [String: [String]] = [:]
    
    /// Tracks pending post-process searches waiting for their base search to complete
    /// Key: "dashboardId:postProcessSearchId" -> Value: PendingSearchInfo
    private var pendingPostProcessSearches: [String: PendingSearchInfo] = [:]
    
    /// Notification observer for search completion events
    private var notificationObserver: AnyCancellable?
    
    // MARK: - Initialization
    private init() {
        // Create a dedicated background context for refresh operations
        backgroundContext = CoreDataManager.shared.newBackgroundContext()
        backgroundContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyStoreTrumpMergePolicyType)
        
        // Ensure view context automatically merges changes from parent
        CoreDataManager.shared.context.automaticallyMergesChangesFromParent = true
        CoreDataManager.shared.context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        
        // Set up notification listener for search completion
        setupNotificationListener()
        
        print("🔄 DashboardRefreshWorker initialized")
    }
    
    // MARK: - Notification Handling
    
    /// Set up listener for search execution completion notifications
    private func setupNotificationListener() {
        notificationObserver = NotificationCenter.default.publisher(for: .searchExecutionCompleted)
            .sink { [weak self] notification in
                guard let self = self else { return }
                
                print("🔔 Received searchExecutionCompleted notification")
                if let userInfo = notification.userInfo {
                    print("   UserInfo keys: \(userInfo.keys)")
                    if let searchId = userInfo["searchId"] as? String {
                        print("   searchId: \(searchId)")
                    }
                    if let dashboardId = userInfo["dashboardId"] as? String {
                        print("   dashboardId: \(dashboardId)")
                    }
                }
                
                Task { @MainActor in
                    await self.handleSearchCompletion(notification)
                }
            }
        
        print("🔔 DashboardRefreshWorker: Notification listener set up")
    }
    
    /// Handle search execution completion notifications
    private func handleSearchCompletion(_ notification: Notification) async {
        guard let userInfo = notification.userInfo,
              let searchId = userInfo["searchId"] as? String,
              let dashboardId = userInfo["dashboardId"] as? String else {
            print("⚠️ Notification missing searchId or dashboardId")
            return
        }
        
        let baseSearchKey = "\(dashboardId):\(searchId)"
        
        // Check if any post-process searches are waiting for this base search
        guard let dependents = dependentSearches[baseSearchKey], !dependents.isEmpty else {
            print("🔍 No dependent searches found for base search '\(searchId)'")
            return
        }
        
        print("🎯 Base search '\(searchId)' completed, triggering \(dependents.count) dependent search(es)")
        
        // Execute all dependent post-process searches
        for dependentKey in dependents {
            // Extract searchId from the key format "dashboardId:searchId"
            let components = dependentKey.split(separator: ":").map(String.init)
            guard components.count == 2 else {
                print("  ⚠️ Invalid dependent key format: \(dependentKey)")
                continue
            }
            
            let dependentDashboardId = components[0]
            let dependentSearchId = components[1]
            
            print("  ↳ Executing dependent search: \(dependentSearchId)")
            
            // Execute the post-process search directly now that its base is ready
            await executeSearch(searchId: dependentSearchId, in: dependentDashboardId)
            
            // Remove from pending queue if it was there
            pendingPostProcessSearches.removeValue(forKey: dependentKey)
        }
    }
    
    // MARK: - Public Methods
    
    /// Start refresh timers for all searches in a dashboard
    /// - Parameter dashboardId: The dashboard ID to start timers for
    public func startRefreshTimers(for dashboardId: String) {
        let searchesWithRefresh = CoreDataManager.shared.getSearchesWithRefresh(in: dashboardId)
        
        guard !searchesWithRefresh.isEmpty else {
            print("⚠️ No searches with refresh intervals found in dashboard: \(dashboardId)")
            return
        }
        
        print("🔄 Starting \(searchesWithRefresh.count) refresh timer(s) for dashboard: \(dashboardId)")
        
        // Build dependency map for this dashboard
        buildDependencyMap(for: dashboardId)
        
        for (searchId, interval) in searchesWithRefresh {
            startTimer(for: searchId, interval: interval, in: dashboardId)
        }
        
        updateState()
    }
    
    /// Start refresh timers for all dashboards that have searches with refresh intervals
    public func startAllRefreshTimers() {
        let dashboards = CoreDataManager.shared.fetchAllDashboards()
        
        print("🔄 Starting refresh timers for all dashboards...")
        
        var totalTimers = 0
        for dashboard in dashboards {
            let searchesWithRefresh = CoreDataManager.shared.getSearchesWithRefresh(in: dashboard.id)
            if !searchesWithRefresh.isEmpty {
                startRefreshTimers(for: dashboard.id)
                totalTimers += searchesWithRefresh.count
            }
        }
        
        print("✅ Started \(totalTimers) refresh timer(s) across \(dashboards.count) dashboard(s)")
        isRunning = true
    }
    
    /// Stop refresh timers for a specific dashboard
    /// - Parameter dashboardId: The dashboard ID to stop timers for
    public func stopRefreshTimers(for dashboardId: String) {
        let keysToRemove = timers.keys.filter { key in
            activeSearchTimers[key]?.dashboardId == dashboardId
        }
        
        for key in keysToRemove {
            timers[key]?.cancel()
            timers.removeValue(forKey: key)
            activeSearchTimers.removeValue(forKey: key)
        }
        
        // Clean up dependencies for this dashboard
        let dependencyKeysToRemove = postProcessDependencies.keys.filter { $0.hasPrefix("\(dashboardId):") }
        dependencyKeysToRemove.forEach { postProcessDependencies.removeValue(forKey: $0) }
        
        let baseKeysToRemove = dependentSearches.keys.filter { $0.hasPrefix("\(dashboardId):") }
        baseKeysToRemove.forEach { dependentSearches.removeValue(forKey: $0) }
        
        let pendingKeysToRemove = pendingPostProcessSearches.keys.filter { $0.hasPrefix("\(dashboardId):") }
        pendingKeysToRemove.forEach { pendingPostProcessSearches.removeValue(forKey: $0) }
        
        print("⏹️ Stopped \(keysToRemove.count) timer(s) for dashboard: \(dashboardId)")
        updateState()
    }
    
    /// Stop all refresh timers
    public func stopAllTimers() {
        let count = timers.count
        
        for timer in timers.values {
            timer.cancel()
        }
        
        timers.removeAll()
        activeSearchTimers.removeAll()
        
        // Clean up all dependencies
        postProcessDependencies.removeAll()
        dependentSearches.removeAll()
        pendingPostProcessSearches.removeAll()
        
        print("⏹️ Stopped all \(count) refresh timer(s)")
        isRunning = false
        updateState()
    }
    
    /// Manually trigger a refresh for a specific search (bypasses timer)
    /// - Parameters:
    ///   - searchId: The search ID
    ///   - dashboardId: The dashboard ID
    public func triggerRefresh(searchId: String, in dashboardId: String) async {
        print("🔄 Manually triggering refresh for search: \(searchId)")
        await refreshSearch(searchId: searchId, in: dashboardId)
    }
    
    // MARK: - Private Methods
    
    /// Build dependency map for base searches and their post-process searches
    private func buildDependencyMap(for dashboardId: String) {
        guard let dashboard = CoreDataManager.shared.findDashboard(by: dashboardId) else {
            print("⚠️ Dashboard not found: \(dashboardId)")
            return
        }
        
        // Get all searches in the dashboard
        let allSearches = dashboard.allSearches
        print("🔍 Building dependency map for dashboard '\(dashboardId)' with \(allSearches.count) searches")
        
        // Clear existing dependencies for this dashboard
        let keysToRemove = postProcessDependencies.keys.filter { $0.hasPrefix("\(dashboardId):") }
        keysToRemove.forEach { postProcessDependencies.removeValue(forKey: $0) }
        
        let baseKeysToRemove = dependentSearches.keys.filter { $0.hasPrefix("\(dashboardId):") }
        baseKeysToRemove.forEach { dependentSearches.removeValue(forKey: $0) }
        
        // Build new dependency maps
        var dependencyCount = 0
        for search in allSearches {
            let baseRef = search.base ?? search.ref
            
            if let baseSearchId = baseRef, !baseSearchId.isEmpty {
                let postProcessKey = "\(dashboardId):\(search.id)"
                let baseSearchKey = "\(dashboardId):\(baseSearchId)"
                
                // Map post-process search to its base search
                postProcessDependencies[postProcessKey] = baseSearchId
                
                // Map base search to its dependent post-process searches
                if dependentSearches[baseSearchKey] == nil {
                    dependentSearches[baseSearchKey] = []
                }
                dependentSearches[baseSearchKey]?.append(postProcessKey)
                
                dependencyCount += 1
                print("  📎 Mapped dependency: '\(search.id)' depends on base search '\(baseSearchId)'")
                print("     Post-process key: \(postProcessKey)")
                print("     Base search key: \(baseSearchKey)")
            }
        }
        
        if dependencyCount > 0 {
            print("✅ Built dependency map: \(dependencyCount) post-process search(es) with base dependencies")
            print("   Current dependentSearches map:")
            for (baseKey, dependents) in dependentSearches {
                print("     \(baseKey) -> \(dependents)")
            }
        }
    }
    
    /// Start a timer for a specific search
    private func startTimer(for searchId: String, interval: TimeInterval, in dashboardId: String) {
        let timerKey = "\(dashboardId):\(searchId)"
        
        // Cancel existing timer if any
        timers[timerKey]?.cancel()
        
        // Store timer info
        activeSearchTimers[timerKey] = SearchTimerInfo(
            searchId: searchId,
            dashboardId: dashboardId,
            interval: interval,
            lastRefresh: nil,
            nextRefresh: Date().addingTimeInterval(interval)
        )
        
        // Create new timer using Combine
        let timer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                
                Task { @MainActor in
                    await self.refreshSearch(searchId: searchId, in: dashboardId)
                    self.updateTimerInfo(for: timerKey, interval: interval)
                }
            }
        
        timers[timerKey] = timer
        print("✅ Started timer for search \(searchId) (every \(Self.formatInterval(interval)))")
    }
    
    /// Execute a search refresh
    private func refreshSearch(searchId: String, in dashboardId: String) async {
        print("🔄 Auto-refreshing search: \(searchId) in dashboard: \(dashboardId)")
        
        let searchKey = "\(dashboardId):\(searchId)"
        
        // Check if this is a post-process search that depends on a base search
        if let baseSearchId = postProcessDependencies[searchKey] {
            print("  📎 Search '\(searchId)' is a post-process search depending on base: '\(baseSearchId)'")
            
            // Check if the base search has a recent completed execution
            if CoreDataManager.shared.getSearchSID(searchId: baseSearchId, in: dashboardId) == nil {
                print("  ⏳ Base search '\(baseSearchId)' has no recent execution. Queuing post-process search.")
                
                // Queue this post-process search to execute when base completes
                pendingPostProcessSearches[searchKey] = PendingSearchInfo(
                    searchId: searchId,
                    dashboardId: dashboardId,
                    baseSearchId: baseSearchId,
                    timestamp: Date()
                )
                
                // Trigger the base search if it has a timer (so it can complete and trigger this one)
                let baseSearchKey = "\(dashboardId):\(baseSearchId)"
                if activeSearchTimers[baseSearchKey] != nil {
                    print("  🔄 Triggering base search '\(baseSearchId)' first")
                    await executeSearch(searchId: baseSearchId, in: dashboardId)
                } else {
                    print("  ⚠️ Base search '\(baseSearchId)' has no active timer. Post-process search may fail.")
                    // Execute anyway - CoreDataManager will handle the error
                    await executeSearch(searchId: searchId, in: dashboardId)
                }
                return
            } else {
                print("  ✅ Base search '\(baseSearchId)' has recent execution. Proceeding with post-process search.")
            }
        }
        
        // Execute the search (either base search or post-process with available base)
        await executeSearch(searchId: searchId, in: dashboardId)
    }
    
    /// Execute a search without dependency checks (internal helper)
    private func executeSearch(searchId: String, in dashboardId: String) async {
        do {
            // Use the existing search execution system
            let executionId = CoreDataManager.shared.startSearchExecution(
                searchId: searchId,
                in: dashboardId,
                userTokenValues: [:],
                timeRange: nil,
                parameterOverrides: SearchParameterOverrides(),
                splunkCredentials: nil
            )
            
            lastRefreshTime = Date()
            print("✅ Search \(searchId) refresh initiated with execution ID: \(executionId)")
        }
    }
    
    /// Update timer info after a refresh
    private func updateTimerInfo(for key: String, interval: TimeInterval) {
        if var info = activeSearchTimers[key] {
            info.lastRefresh = Date()
            info.nextRefresh = Date().addingTimeInterval(interval)
            activeSearchTimers[key] = info
        }
    }
    
    /// Update published state
    private func updateState() {
        activeTimerCount = timers.count
        isRunning = !timers.isEmpty
    }
    
    // MARK: - Utility
    
    /// Parse Splunk refresh interval format (e.g., "1m", "30s", "2h") into seconds
    /// - Parameter splunkInterval: The Splunk interval string (e.g., "1m", "30s", "2h", "1d", "1w", "1MON")
    /// - Returns: The interval in seconds, or nil if the format is invalid
    public static func parseInterval(_ splunkInterval: String) -> TimeInterval? {
        let trimmed = splunkInterval.trimmingCharacters(in: .whitespaces)
        
        guard !trimmed.isEmpty else {
            return nil
        }
        
        // Extract numeric value and unit
        var numericPart = ""
        var unitPart = ""
        
        for char in trimmed {
            if char.isNumber || char == "." {
                numericPart.append(char)
            } else {
                unitPart.append(char)
            }
        }
        
        guard let value = Double(numericPart), value > 0 else {
            print("⚠️ Invalid numeric value in interval: \(splunkInterval)")
            return nil
        }
        
        // Convert based on unit
        let unit = unitPart.uppercased()
        let multiplier: TimeInterval
        
        switch unit {
        case "S":
            multiplier = 1 // seconds
        case "M":
            multiplier = 60 // minutes
        case "H":
            multiplier = 3600 // hours
        case "D":
            multiplier = 86400 // days
        case "W":
            multiplier = 604800 // weeks (7 days)
        case "MON":
            multiplier = 2592000 // months (30 days)
        default:
            print("⚠️ Unknown interval unit: \(unitPart) in \(splunkInterval)")
            return nil
        }
        
        return value * multiplier
    }
    
    /// Format a time interval for display
    public static func formatInterval(_ interval: TimeInterval) -> String {
        if interval < 60 {
            return "\(Int(interval))s"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))h"
        } else if interval < 604800 {
            return "\(Int(interval / 86400))d"
        } else if interval < 2592000 {
            return "\(Int(interval / 604800))w"
        } else {
            return "\(Int(interval / 2592000))MON"
        }
    }
}

// MARK: - Supporting Types

/// Information about an active search timer
public struct SearchTimerInfo: Identifiable, Sendable {
    public let id = UUID()
    public let searchId: String
    public let dashboardId: String
    public let interval: TimeInterval
    public var lastRefresh: Date?
    public var nextRefresh: Date
}

/// Information about a post-process search waiting for its base search
private struct PendingSearchInfo {
    let searchId: String
    let dashboardId: String
    let baseSearchId: String
    let timestamp: Date
}
