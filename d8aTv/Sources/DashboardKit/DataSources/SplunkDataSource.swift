import Foundation

/// Splunk REST API data source implementation
/// Now uses consolidated SplunkIntegration services instead of direct API calls
public actor SplunkDataSource: DataSourceProtocol {
    public let type: DataSourceType = .splunk

    private let searchService: SplunkSearchService
    private let restClient: SplunkRestClient

    /// Initialize with a SplunkConfiguration (recommended - preserves all credentials and settings)
    public init(configuration: SplunkConfiguration) {
        self.restClient = SplunkRestClient(configuration: configuration)
        self.searchService = SplunkSearchService(restClient: restClient)
    }

    /// Initialize with individual parameters (legacy - for simple cases)
    public init(
        host: String,
        port: Int = 8089,
        username: String? = nil,
        authToken: String? = nil,
        useSSL: Bool = true,
        validateSSL: Bool = true
    ) {
        // Build base URL
        let scheme = useSSL ? "https" : "http"
        guard let baseURL = URL(string: "\(scheme)://\(host):\(port)") else {
            fatalError("Invalid Splunk URL: \(scheme)://\(host):\(port)")
        }

        // Create credentials
        let credentials: SplunkCredentials
        if let token = authToken {
            credentials = .token(token)
        } else if let user = username {
            // Basic auth (for testing/development only - password hardcoded)
            credentials = .basic(username: user, password: "password")
        } else {
            // No auth
            credentials = .basic(username: "", password: "")
        }

        // Create Splunk configuration
        let config = SplunkConfiguration(
            baseURL: baseURL,
            credentials: credentials,
            timeout: 60,
            allowInsecureConnections: !validateSSL,
            validateSSLCertificate: validateSSL
        )

        // Create REST client and search service
        self.restClient = SplunkRestClient(configuration: config)
        self.searchService = SplunkSearchService(restClient: restClient)
    }

    // MARK: - DataSourceProtocol Implementation

    public func executeSearch(query: String, parameters: SearchParameters) async throws -> SearchExecutionResult {
        // Substitute tokens in query
        let processedQuery = substituteTokens(in: query, tokens: parameters.tokens)

        print("🌐 Executing search via SplunkSearchService:")
        print("   Query: \(processedQuery)")
        print("   Earliest: \(parameters.earliestTime ?? "none")")
        print("   Latest: \(parameters.latestTime ?? "none")")

        // Use SplunkSearchService to create the search job
        let searchJob = try await searchService.createSearchJob(
            query: processedQuery,
            earliest: parameters.earliestTime,
            latest: parameters.latestTime,
            maxCount: parameters.maxResults,
            parameters: [:] as [String: String]  // Empty dict with explicit type to satisfy Sendable
        )

        print("✅ Search job created: \(searchJob.sid)")

        return SearchExecutionResult(
            executionId: searchJob.sid,
            searchId: searchJob.sid,
            status: .running,
            startTime: Date()
        )
    }

    public func checkSearchStatus(executionId: String) async throws -> SearchStatus {
        // Use SplunkSearchService to check status
        let status = try await searchService.getSearchJobStatus(sid: executionId)

        if status.isFailed {
            return .failed
        } else if status.isDone {
            return .completed
        } else {
            return .running
        }
    }

    public func fetchResults(executionId: String, offset: Int, limit: Int) async throws -> [SearchResultRow] {
        // Use SplunkSearchService to fetch results
        let results = try await searchService.getSearchResults(
            sid: executionId,
            offset: offset,
            count: limit
        )

        return results.results.map { result in
            // Unwrap AnyCodable values to get the actual values
            let unwrappedFields: [String: Any] = result.mapValues { $0.value }
            return SearchResultRow(
                fields: unwrappedFields,
                timestamp: Date()
            )
        }
    }

    public func cancelSearch(executionId: String) async throws {
        // Cancel search by deleting the job
        // Note: SplunkSearchService doesn't have a cancel method yet,
        // but we can delete the job via REST client
        let endpoint = "services/search/jobs/\(executionId)"
        let _: EmptyResponse = try await restClient.delete(endpoint, responseType: EmptyResponse.self)
    }

    public func validateConnection() async throws -> Bool {
        // Validate connection by checking server info
        do {
            struct ServerInfoResponse: Codable {}
            _ = try await restClient.get(
                "services/server/info",
                parameters: ["output_mode": "json"],
                responseType: ServerInfoResponse.self
            )
            return true
        } catch {
            return false
        }
    }

    /// Fetch saved search metadata (owner, app, query) from Splunk
    public func fetchSavedSearchMetadata(ref: String) async throws -> (owner: String, app: String, query: String) {
        print("🔍 Fetching saved search metadata for ref: \(ref)")

        // Execute Splunk REST search to find saved search details
        let query = """
        | rest /servicesNS/-/-/saved/searches
        | search title="\(ref)"
        | table title, eai:acl.app, eai:acl.owner, search
        | head 1
        """

        // Create a search job
        let searchJob = try await searchService.createSearchJob(
            query: query,
            earliest: nil,
            latest: nil,
            maxCount: 1,
            parameters: [:] as [String: String]
        )

        // Wait for job to complete (poll for up to 30 seconds)
        var attempts = 0
        while attempts < 30 {
            let status = try await searchService.getSearchJobStatus(sid: searchJob.sid)
            if status.isDone {
                break
            }
            try await Task.sleep(for: .seconds(1))
            attempts += 1
        }

        // Fetch results
        let results = try await searchService.getSearchResults(sid: searchJob.sid, offset: 0, count: 1)

        guard let firstResult = results.results.first else {
            throw DataSourceError.searchFailed(message: "Saved search '\(ref)' not found")
        }

        // Extract fields
        let owner = (firstResult["eai:acl.owner"]?.value as? String) ?? "admin"
        let app = (firstResult["eai:acl.app"]?.value as? String) ?? "search"
        let savedQuery = (firstResult["search"]?.value as? String) ?? ""

        print("✅ Found saved search: owner=\(owner), app=\(app)")

        return (owner: owner, app: app, query: savedQuery)
    }

    // MARK: - Private Helpers

    private func substituteTokens(in query: String, tokens: [String: String]) -> String {
        var result = query
        for (token, value) in tokens {
            result = result.replacingOccurrences(of: "$\(token)$", with: value)
        }
        return result
    }
}

// MARK: - Splunk API Response Models
// Note: Using types from SplunkIntegration.swift

private struct SplunkSearchResultsResponse: Decodable {
    let results: [[String: Any]]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let resultsArray = try container.decode([[String: AnyCodable]].self, forKey: .results)
        self.results = resultsArray.map { dict in
            dict.mapValues { $0.value }
        }
    }

    enum CodingKeys: String, CodingKey {
        case results
    }
}

// MARK: - Data Source Errors

/// Data source error types
public enum DataSourceError: Error, CustomStringConvertible {
    case connectionFailed(message: String)
    case authenticationFailed
    case apiError(message: String)
    case invalidResponse
    case searchFailed(message: String)

    public var description: String {
        switch self {
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .authenticationFailed:
            return "Authentication failed"
        case .apiError(let message):
            return "API error: \(message)"
        case .invalidResponse:
            return "Invalid response from server"
        case .searchFailed(let message):
            return "Search failed: \(message)"
        }
    }
}

// NOTE: Dictionary encoding and SSL handling now provided by SplunkIntegration.swift
