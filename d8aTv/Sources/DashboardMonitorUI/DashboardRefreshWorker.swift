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
    
    // MARK: - Initialization
    private init() {
        // Create a dedicated background context for refresh operations
        backgroundContext = CoreDataManager.shared.newBackgroundContext()
        backgroundContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyStoreTrumpMergePolicyType)

        
        // Ensure view context automatically merges changes from parent
        CoreDataManager.shared.context.automaticallyMergesChangesFromParent = true
        CoreDataManager.shared.context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)

        print("🔄 DashboardRefreshWorker initialized")
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
        } else {
            return "\(Int(interval / 604800))w"
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
