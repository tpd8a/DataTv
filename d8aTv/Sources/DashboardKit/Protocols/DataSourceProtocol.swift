import Foundation

/// Protocol defining data source capabilities for different backends (Splunk, Elastic, Prometheus)
public protocol DataSourceProtocol: Sendable {
    /// Type of data source (splunk, elastic, prometheus)
    var type: DataSourceType { get }

    /// Execute a search query
    func executeSearch(query: String, parameters: SearchParameters) async throws -> SearchExecutionResult

    /// Check the status of a running search
    func checkSearchStatus(executionId: String) async throws -> SearchStatus

    /// Retrieve results from a completed search
    func fetchResults(executionId: String, offset: Int, limit: Int) async throws -> [SearchResultRow]

    /// Cancel a running search
    func cancelSearch(executionId: String) async throws

    /// Validate connection to the data source
    func validateConnection() async throws -> Bool
}

/// Data source type enumeration
public enum DataSourceType: String, Codable, Sendable {
    case splunk
    case elastic
    case prometheus
}

/// Search execution parameters
public struct SearchParameters: Sendable {
    public let earliestTime: String?
    public let latestTime: String?
    public let maxResults: Int?
    public let timeout: TimeInterval?
    public let tokens: [String: String]

    public init(
        earliestTime: String? = nil,
        latestTime: String? = nil,
        maxResults: Int? = nil,
        timeout: TimeInterval? = nil,
        tokens: [String: String] = [:]
    ) {
        self.earliestTime = earliestTime
        self.latestTime = latestTime
        self.maxResults = maxResults
        self.timeout = timeout
        self.tokens = tokens
    }
}

/// Search execution result
public struct SearchExecutionResult: Sendable {
    public let executionId: String
    public let searchId: String
    public let status: SearchStatus
    public let startTime: Date

    public init(executionId: String, searchId: String, status: SearchStatus, startTime: Date) {
        self.executionId = executionId
        self.searchId = searchId
        self.status = status
        self.startTime = startTime
    }
}

/// Search status enumeration
public enum SearchStatus: String, Codable, Sendable {
    case queued
    case running
    case completed
    case failed
    case cancelled
}

/// Individual search result row
public struct SearchResultRow: Sendable {
    public let fields: [String: Any]
    public let timestamp: Date

    public init(fields: [String: Any], timestamp: Date) {
        self.fields = fields
        self.timestamp = timestamp
    }

    /// Convert to JSON data
    public func toJSON() throws -> Data {
        try JSONSerialization.data(withJSONObject: fields)
    }
}
