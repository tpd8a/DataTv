import Foundation
import Combine
import CoreData

// MARK: - Execution Summary

/// Summary of a search execution for monitoring
public struct SearchExecutionSummary: Sendable, Identifiable {
    public let id: UUID
    public let searchId: String
    public let executionId: String
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

    public init(id: UUID, searchId: String, executionId: String, query: String,
                status: SearchStatus, startTime: Date, endTime: Date? = nil,
                resultCount: Int64 = 0, errorMessage: String? = nil) {
        self.id = id
        self.searchId = searchId
        self.executionId = executionId
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
        // This would need to be implemented in CoreDataManager
        // For now, return empty array as placeholder
        return []
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
                      let startTime = object.value(forKey: "startTime") as? Date else {
                    return nil
                }

                let endTime = object.value(forKey: "endTime") as? Date
                let resultCount = object.value(forKey: "resultCount") as? Int64 ?? 0
                let errorMessage = object.value(forKey: "errorMessage") as? String

                return SearchExecutionSummary(
                    id: id,
                    searchId: searchId,
                    executionId: executionId,
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
                      let startTime = object.value(forKey: "startTime") as? Date else {
                    return nil
                }

                let endTime = object.value(forKey: "endTime") as? Date
                let resultCount = object.value(forKey: "resultCount") as? Int64 ?? 0
                let errorMessage = object.value(forKey: "errorMessage") as? String

                return SearchExecutionSummary(
                    id: id,
                    searchId: searchId,
                    executionId: executionId,
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
