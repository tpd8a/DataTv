import Foundation
import Combine
import CoreData
import DashboardKit

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

    // MARK: - Initialization
    private init() {
        print("🔄 DashboardRefreshWorker initialized")
    }

    // MARK: - Public Methods

    /// Start refresh timers for all dashboards that have searches with refresh intervals
    public func startAllRefreshTimers() {
        Task {
            do {
                // Use CoreDataManager to fetch dashboards
                let dashboards = try await CoreDataManager.shared.fetchAllDashboards()

                print("🔄 Starting refresh timers for all dashboards...")

                var totalTimers = 0
                for dashboard in dashboards {
                    guard let dashboardId = dashboard.id else { continue }
                    // Use CoreDataManager to get searches with refresh
                    let searchesWithRefresh = try await CoreDataManager.shared.getSearchesWithRefresh(in: dashboardId)
                    if !searchesWithRefresh.isEmpty {
                        for (searchId, interval) in searchesWithRefresh {
                            startTimer(for: searchId, interval: interval, in: dashboardId)
                            totalTimers += 1
                        }
                    }
                }

                await MainActor.run {
                    print("✅ Started \(totalTimers) refresh timer(s) across \(dashboards.count) dashboard(s)")
                    self.isRunning = true
                    self.updateState()
                }
            } catch {
                print("❌ Error starting all refresh timers: \(error)")
            }
        }
    }

    /// Start refresh timers for a specific dashboard that has searches with refresh intervals
    /// - Parameter dashboardId: The ID of the dashboard to start timers for
    public func startTimersForDashboard(_ dashboardId: UUID) async {
        do {
            print("🔄 Starting refresh timers for dashboard: \(dashboardId)")

            // Use CoreDataManager to get searches with refresh for this dashboard
            let searchesWithRefresh = try await CoreDataManager.shared.getSearchesWithRefresh(in: dashboardId)

            guard !searchesWithRefresh.isEmpty else {
                print("ℹ️ No searches with refresh intervals found for dashboard \(dashboardId)")
                return
            }

            var timerCount = 0
            for (searchId, interval) in searchesWithRefresh {
                startTimer(for: searchId, interval: interval, in: dashboardId)
                timerCount += 1
            }

            await MainActor.run {
                print("✅ Started \(timerCount) refresh timer(s) for dashboard \(dashboardId)")
                self.isRunning = true
                self.updateState()
            }
        } catch {
            print("❌ Error starting timers for dashboard \(dashboardId): \(error)")
        }
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
    public func triggerRefresh(searchId: String, in dashboardId: UUID) async {
        print("🔄 Manually triggering refresh for search: \(searchId)")
        await refreshSearch(searchId: searchId, in: dashboardId)
    }

    // MARK: - Private Methods


    /// Start a timer for a specific search
    private func startTimer(for searchId: String, interval: TimeInterval, in dashboardId: UUID) {
        let timerKey = "\(dashboardId.uuidString):\(searchId)"

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
    private func refreshSearch(searchId: String, in dashboardId: UUID) async {
        print("🔄 Auto-refreshing search: \(searchId) in dashboard: \(dashboardId)")

        do {
            // Get current token values from DashboardTokenManager
            // Note: Only use tokens if the active dashboard matches
            let tokenValues = await MainActor.run {
                if DashboardTokenManager.shared.activeDashboardId == dashboardId {
                    return DashboardTokenManager.shared.getAllValues()
                } else {
                    print("⚠️ Token manager has different active dashboard, using empty token values")
                    return [:]
                }
            }

            print("🎛️ Using \(tokenValues.count) token value(s) for search execution")

            // Use CoreDataManager to actually execute the search
            // This will create the execution AND make the Splunk API call
            let executionId = try await CoreDataManager.shared.startSearchExecution(
                searchId: searchId,
                in: dashboardId,
                userTokenValues: tokenValues,
                timeRange: nil,  // CoreDataManager will extract from DataSource entity
                parameterOverrides: [:],
                credentials: nil  // Will use default config from settings
            )

            lastRefreshTime = Date()
            print("✅ Search \(searchId) refresh initiated with execution ID: \(executionId)")
        } catch {
            print("❌ Error refreshing search \(searchId): \(error)")
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
    public let dashboardId: UUID
    public let interval: TimeInterval
    public var lastRefresh: Date?
    public var nextRefresh: Date
}
