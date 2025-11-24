import Foundation
import Combine
import CoreData

// MARK: - Execution Summary

/// Summary of a search execution for monitoring
public struct SearchExecutionSummary: Sendable, Identifiable {
    public let id: UUID
    public let searchId: String
    public let executionId: String
    public let dataSourceId: String  // DataSource sourceId (e.g., "base_new")
    public let query: String
    public let status: SearchStatus
    public let startTime: Date
    public let endTime: Date?
    public let resultCount: Int64
    public let errorMessage: String?

    public var isComplete: Bool {
        status == .completed || status == .failed || status == .cancelled
    }

    public var duration: TimeInterval? {
        guard let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }

    public init(id: UUID, searchId: String, executionId: String, dataSourceId: String, query: String,
                status: SearchStatus, startTime: Date, endTime: Date? = nil,
                resultCount: Int64 = 0, errorMessage: String? = nil) {
        self.id = id
        self.searchId = searchId
        self.executionId = executionId
        self.dataSourceId = dataSourceId
        self.query = query
        self.status = status
        self.startTime = startTime
        self.endTime = endTime
        self.resultCount = resultCount
        self.errorMessage = errorMessage
    }
}

// MARK: - Search Execution Monitor

/// Monitor for tracking active search executions
@MainActor
public class SearchExecutionMonitor: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var activeExecutions: [SearchExecutionSummary] = []
    @Published public private(set) var isMonitoring: Bool = false

    // MARK: - Private Properties

    private let coreDataManager: CoreDataManager
    private var monitoringTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Singleton

    public static let shared = SearchExecutionMonitor(coreDataManager: .shared)

    // MARK: - Init

    public init(coreDataManager: CoreDataManager) {
        self.coreDataManager = coreDataManager
    }

    // MARK: - Monitoring Control

    /// Start monitoring active executions
    public func startMonitoring(pollingInterval: TimeInterval = 2.0) {
        guard !isMonitoring else { return }

        isMonitoring = true

        monitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.updateActiveExecutions()
                try? await Task.sleep(for: .seconds(pollingInterval))
            }
        }
    }

    /// Stop monitoring
    public func stopMonitoring() {
        isMonitoring = false
        monitoringTask?.cancel()
        monitoringTask = nil
    }

    /// Manually refresh active executions
    public func refresh() async {
        await updateActiveExecutions()
    }

    // MARK: - Private Methods

    private func updateActiveExecutions() async {
        do {
            let executions = try await fetchActiveExecutions()
            activeExecutions = executions
        } catch {
            print("Error fetching active executions: \(error)")
        }
    }

    private func fetchActiveExecutions() async throws -> [SearchExecutionSummary] {
        // Get active executions from CoreDataManager
        let executions = try await coreDataManager.fetchActiveSearchExecutions()

        // Check status for each running execution and update if needed
        for execution in executions where execution.status == .running {
            await checkAndUpdateExecutionStatus(execution)
        }

        return executions
    }

    /// Check and update the status of a running execution
    private func checkAndUpdateExecutionStatus(_ execution: SearchExecutionSummary) async {
        do {
            // Get the data source config to find the registered data source
            guard let dataSource = await getDataSourceForExecution(execution) else {
                print("⚠️ No data source found for execution \(execution.executionId)")
                return
            }

            // Check status from Splunk
            let status = try await dataSource.checkSearchStatus(executionId: execution.executionId)

            // If status changed, update in CoreData
            if status != execution.status {
                print("📊 Status update for \(execution.executionId): \(execution.status) → \(status)")

                if status == .completed {
                    // Fetch results
                    let results = try await dataSource.fetchResults(
                        executionId: execution.executionId,
                        offset: 0,
                        limit: 10000
                    )

                    // Update execution with results
                    try await coreDataManager.updateSearchExecution(
                        executionId: execution.id,
                        status: status,
                        results: results
                    )

                    print("✅ Execution \(execution.executionId) completed with \(results.count) results")

                    // If this is an input search, process results to populate choices
                    if execution.dataSourceId.hasPrefix("input_search_") {
                        print("🎯 Processing input search results for \(execution.dataSourceId)")
                        if let dashboardId = try? await coreDataManager.getDashboardId(forExecutionId: execution.id) {
                            try? await coreDataManager.processInputSearchResults(dashboardId: dashboardId)
                        }
                    }

                    print("🔗 Checking for chained searches for base dataSourceId: \(execution.dataSourceId)")

                    // Trigger any chained searches that depend on this base search
                    await triggerChainedSearches(for: execution)
                } else {
                    // Just update status
                    try await coreDataManager.updateSearchExecution(
                        executionId: execution.id,
                        status: status
                    )
                }
            }
        } catch {
            print("❌ Error checking execution status: \(error)")
            // Mark as failed
            try? await coreDataManager.updateSearchExecution(
                executionId: execution.id,
                status: .failed,
                errorMessage: error.localizedDescription
            )
        }
    }

    /// Get the data source for an execution
    private func getDataSourceForExecution(_ execution: SearchExecutionSummary) async -> (any DataSourceProtocol)? {
        // Get the execution's data source config ID from CoreData
        guard let configId = try? await coreDataManager.getDataSourceConfigId(forExecutionId: execution.id) else {
            return nil
        }

        // Get the registered data source
        return await coreDataManager.getDataSource(withId: configId.uuidString)
    }

    /// Trigger chained searches that depend on a completed base search
    private func triggerChainedSearches(for baseExecution: SearchExecutionSummary) async {
        print("🔗 triggerChainedSearches called for dataSourceId: \(baseExecution.dataSourceId) (executionId: \(baseExecution.executionId))")
        do {
            // Get the dashboard ID for this execution
            guard let dashboardId = try await coreDataManager.getDashboardId(forExecutionId: baseExecution.id) else {
                print("⚠️ Could not find dashboard for execution \(baseExecution.id)")
                return
            }

            print("🔗 Dashboard ID: \(dashboardId)")

            // Find chained searches that depend on this base search
            // Use dataSourceId (e.g., "base_new") not searchId (Splunk SID)
            let chainedSearchIds = try await coreDataManager.getChainedSearches(
                forBaseSearchId: baseExecution.dataSourceId,
                in: dashboardId
            )

            print("🔗 Found \(chainedSearchIds.count) chained search(es) for base search \(baseExecution.dataSourceId)")

            guard !chainedSearchIds.isEmpty else {
                print("🔗 No chained searches found")
                return // No chained searches
            }

            print("🔗 Triggering \(chainedSearchIds.count) chained search(es) for base search \(baseExecution.searchId)")

            // Start execution of each chained search
            for chainedSearchId in chainedSearchIds {
                do {
                    let executionId = try await coreDataManager.startSearchExecution(
                        searchId: chainedSearchId,
                        in: dashboardId,
                        userTokenValues: [:],  // Chained searches inherit from base
                        timeRange: nil,         // Chained searches use base search's time range
                        parameterOverrides: [:],
                        credentials: nil,
                        baseExecutionId: baseExecution.executionId  // Pass base search's Splunk SID for loadjob
                    )
                    print("🔗 Started chained search \(chainedSearchId) with execution ID: \(executionId) (loading base results from \(baseExecution.executionId))")
                } catch {
                    print("❌ Error starting chained search \(chainedSearchId): \(error)")
                }
            }
        } catch {
            print("❌ Error triggering chained searches: \(error)")
        }
    }

    // MARK: - Public Helpers

    /// Get execution by ID
    public func getExecution(id: UUID) -> SearchExecutionSummary? {
        return activeExecutions.first(where: { $0.id == id })
    }

    /// Get executions by status
    public func getExecutions(withStatus status: SearchStatus) -> [SearchExecutionSummary] {
        return activeExecutions.filter { $0.status == status }
    }

    /// Get completed executions
    public var completedExecutions: [SearchExecutionSummary] {
        return activeExecutions.filter { $0.isComplete }
    }

    /// Get running executions
    public var runningExecutions: [SearchExecutionSummary] {
        return activeExecutions.filter { !$0.isComplete }
    }

    /// Clear completed executions
    public func clearCompleted() {
        activeExecutions.removeAll(where: { $0.isComplete })
    }

    // MARK: - Cleanup

    nonisolated deinit {
        monitoringTask?.cancel()
    }
}

// MARK: - CoreDataManager Extension for Monitoring

extension CoreDataManager {

    /// Fetch all active (non-completed) search executions
    public func fetchActiveSearchExecutions() async throws -> [SearchExecutionSummary] {
        return try await viewContext.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "SearchExecution")
            request.predicate = NSPredicate(format: "status IN %@", [
                SearchStatus.queued.rawValue,
                SearchStatus.running.rawValue
            ])
            request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]

            let results = try request.execute()

            return results.compactMap { object -> SearchExecutionSummary? in
                guard let id = object.value(forKey: "id") as? UUID,
                      let searchId = object.value(forKey: "searchId") as? String,
                      let executionId = object.value(forKey: "executionId") as? String,
                      let query = object.value(forKey: "query") as? String,
                      let statusString = object.value(forKey: "status") as? String,
                      let status = SearchStatus(rawValue: statusString),
                      let startTime = object.value(forKey: "startTime") as? Date,
                      let dataSource = object.value(forKey: "dataSource") as? NSManagedObject,
                      let dataSourceId = dataSource.value(forKey: "sourceId") as? String else {
                    return nil
                }

                let endTime = object.value(forKey: "endTime") as? Date
                let resultCount = object.value(forKey: "resultCount") as? Int64 ?? 0
                let errorMessage = object.value(forKey: "errorMessage") as? String

                return SearchExecutionSummary(
                    id: id,
                    searchId: searchId,
                    executionId: executionId,
                    dataSourceId: dataSourceId,
                    query: query,
                    status: status,
                    startTime: startTime,
                    endTime: endTime,
                    resultCount: resultCount,
                    errorMessage: errorMessage
                )
            }
        }
    }

    /// Fetch search execution history for a data source
    public func fetchSearchHistory(dataSourceId: UUID, limit: Int = 100) async throws -> [SearchExecutionSummary] {
        return try await viewContext.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "SearchExecution")
            request.predicate = NSPredicate(format: "dataSource.id == %@", dataSourceId as CVarArg)
            request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]
            request.fetchLimit = limit

            let results = try request.execute()

            return results.compactMap { object -> SearchExecutionSummary? in
                guard let id = object.value(forKey: "id") as? UUID,
                      let searchId = object.value(forKey: "searchId") as? String,
                      let executionId = object.value(forKey: "executionId") as? String,
                      let query = object.value(forKey: "query") as? String,
                      let statusString = object.value(forKey: "status") as? String,
                      let status = SearchStatus(rawValue: statusString),
                      let startTime = object.value(forKey: "startTime") as? Date,
                      let dataSource = object.value(forKey: "dataSource") as? NSManagedObject,
                      let dataSourceId = dataSource.value(forKey: "sourceId") as? String else {
                    return nil
                }

                let endTime = object.value(forKey: "endTime") as? Date
                let resultCount = object.value(forKey: "resultCount") as? Int64 ?? 0
                let errorMessage = object.value(forKey: "errorMessage") as? String

                return SearchExecutionSummary(
                    id: id,
                    searchId: searchId,
                    executionId: executionId,
                    dataSourceId: dataSourceId,
                    query: query,
                    status: status,
                    startTime: startTime,
                    endTime: endTime,
                    resultCount: resultCount,
                    errorMessage: errorMessage
                )
            }
        }
    }
}
