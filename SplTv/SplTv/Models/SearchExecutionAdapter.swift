import Foundation
import DashboardKit

/// Adapter that bridges DashboardKit's SearchExecution to the interface expected by UI
/// NOTE: This is a compatibility layer. The old code uses SearchExecutionEntity from d8aTvCore,
/// but we're transitioning to SearchExecution from DashboardKit.
public struct SearchExecutionAdapter: Identifiable {
    public let id: UUID
    public let searchExecution: SearchExecution

    // MARK: - Basic Properties

    public var executionId: String {
        searchExecution.executionId ?? "unknown"
    }

    public var startTime: Date {
        searchExecution.startTime ?? Date()
    }

    public var endTime: Date? {
        searchExecution.endTime
    }

    public var status: String {
        searchExecution.status ?? "unknown"
    }

    public var resultCount: Int? {
        searchExecution.resultCount as? Int
    }

    public var errorMessage: String? {
        searchExecution.errorMessage
    }

    // MARK: - Display Properties

    /// Status text for UI display
    public var statusText: String {
        switch status {
        case "completed": return "Completed"
        case "running": return "Running"
        case "failed": return "Failed"
        case "cancelled": return "Cancelled"
        default: return status.capitalized
        }
    }

    /// Status color for UI display
    public var statusColor: String {
        switch status {
        case "completed": return "green"
        case "running": return "blue"
        case "failed": return "red"
        case "cancelled": return "orange"
        default: return "gray"
        }
    }

    /// Duration of execution (if completed)
    public var duration: TimeInterval? {
        guard let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }

    /// Formatted duration string
    public var durationText: String {
        guard let duration = duration else { return "Running..." }
        return String(format: "%.2fs", duration)
    }

    // MARK: - Results Access

    /// Get all results for this execution (sorted by rowIndex)
    public var results: [SearchResult] {
        guard let resultsSet = searchExecution.results as? Set<SearchResult> else {
            return []
        }
        return resultsSet.sorted { ($0.rowIndex) < ($1.rowIndex) }
    }

    /// Get result count
    public var actualResultCount: Int {
        results.count
    }

    // MARK: - Initialization

    public init(searchExecution: SearchExecution) {
        self.id = searchExecution.id ?? UUID()
        self.searchExecution = searchExecution
    }
}

// MARK: - Collection Helpers

extension Collection where Element == SearchExecution {
    /// Convert collection of SearchExecution to SearchExecutionAdapter array
    public var asAdapters: [SearchExecutionAdapter] {
        return map { SearchExecutionAdapter(searchExecution: $0) }
    }
}
