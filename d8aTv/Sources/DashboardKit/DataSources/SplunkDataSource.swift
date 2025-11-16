import Foundation

/// Splunk REST API data source implementation
public actor SplunkDataSource: DataSourceProtocol {
    public let type: DataSourceType = .splunk

    private let host: String
    private let port: Int
    private let username: String?
    private let authToken: String?
    private let useSSL: Bool

    private var baseURL: URL {
        let scheme = useSSL ? "https" : "http"
        return URL(string: "\(scheme)://\(host):\(port)")!
    }

    public init(
        host: String,
        port: Int = 8089,
        username: String? = nil,
        authToken: String? = nil,
        useSSL: Bool = true
    ) {
        self.host = host
        self.port = port
        self.username = username
        self.authToken = authToken
        self.useSSL = useSSL
    }

    // MARK: - DataSourceProtocol Implementation

    public func executeSearch(query: String, parameters: SearchParameters) async throws -> SearchExecutionResult {
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent("/services/search/jobs"), resolvingAgainstBaseURL: true)!

        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)

        // Build search parameters with token substitution
        let processedQuery = substituteTokens(in: query, tokens: parameters.tokens)

        var formData: [String: String] = [
            "search": processedQuery,
            "output_mode": "json"
        ]

        if let earliest = parameters.earliestTime {
            formData["earliest_time"] = earliest
        }

        if let latest = parameters.latestTime {
            formData["latest_time"] = latest
        }

        if let maxResults = parameters.maxResults {
            formData["max_count"] = String(maxResults)
        }

        request.httpBody = formData.percentEncoded()
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw DataSourceError.apiError(message: "Failed to create search job")
        }

        let searchJob = try JSONDecoder().decode(SplunkSearchJobResponse.self, from: data)

        return SearchExecutionResult(
            executionId: searchJob.sid,
            searchId: searchJob.sid,
            status: .running,
            startTime: Date()
        )
    }

    public func checkSearchStatus(executionId: String) async throws -> SearchStatus {
        let url = baseURL.appendingPathComponent("/services/search/jobs/\(executionId)")
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        urlComponents.queryItems = [URLQueryItem(name: "output_mode", value: "json")]

        var request = URLRequest(url: urlComponents.url!)
        addAuthHeaders(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw DataSourceError.apiError(message: "Failed to get search status")
        }

        let statusResponse = try JSONDecoder().decode(SplunkSearchStatusResponse.self, from: data)

        if statusResponse.entry.first?.content.isFailed == true {
            return .failed
        } else if statusResponse.entry.first?.content.isDone == true {
            return .completed
        } else {
            return .running
        }
    }

    public func fetchResults(executionId: String, offset: Int, limit: Int) async throws -> [SearchResultRow] {
        let url = baseURL.appendingPathComponent("/services/search/jobs/\(executionId)/results")
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        urlComponents.queryItems = [
            URLQueryItem(name: "output_mode", value: "json"),
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "count", value: String(limit))
        ]

        var request = URLRequest(url: urlComponents.url!)
        addAuthHeaders(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw DataSourceError.apiError(message: "Failed to fetch results")
        }

        let resultsResponse = try JSONDecoder().decode(SplunkSearchResultsResponse.self, from: data)

        return resultsResponse.results.map { result in
            SearchResultRow(
                fields: result,
                timestamp: Date()
            )
        }
    }

    public func cancelSearch(executionId: String) async throws {
        let url = baseURL.appendingPathComponent("/services/search/jobs/\(executionId)/control")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeaders(to: &request)

        let formData = ["action": "cancel"]
        request.httpBody = formData.percentEncoded()
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw DataSourceError.apiError(message: "Failed to cancel search")
        }
    }

    public func validateConnection() async throws -> Bool {
        let url = baseURL.appendingPathComponent("/services/server/info")
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        urlComponents.queryItems = [URLQueryItem(name: "output_mode", value: "json")]

        var request = URLRequest(url: urlComponents.url!)
        addAuthHeaders(to: &request)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }

        return (200...299).contains(httpResponse.statusCode)
    }

    // MARK: - Private Helpers

    private func addAuthHeaders(to request: inout URLRequest) {
        if let authToken = authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        } else if let username = username {
            // Basic auth (for testing/development only)
            let credentials = "\(username):password"
            if let credentialsData = credentials.data(using: .utf8) {
                let base64Credentials = credentialsData.base64EncodedString()
                request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
            }
        }
    }

    private func substituteTokens(in query: String, tokens: [String: String]) -> String {
        var result = query
        for (token, value) in tokens {
            result = result.replacingOccurrences(of: "$\(token)$", with: value)
        }
        return result
    }
}

// MARK: - Splunk API Response Models

private struct SplunkSearchJobResponse: Codable {
    let sid: String
}

private struct SplunkSearchStatusResponse: Codable {
    let entry: [SplunkSearchStatusEntry]
}

private struct SplunkSearchStatusEntry: Codable {
    let content: SplunkSearchStatusContent
}

private struct SplunkSearchStatusContent: Codable {
    let isDone: Bool
    let isFailed: Bool

    enum CodingKeys: String, CodingKey {
        case isDone = "isDone"
        case isFailed = "isFailed"
    }
}

private struct SplunkSearchResultsResponse: Codable {
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

// MARK: - Dictionary Encoding Extension

extension Dictionary where Key == String, Value == String {
    func percentEncoded() -> Data? {
        let encoded = map { key, value in
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            return "\(encodedKey)=\(encodedValue)"
        }.joined(separator: "&")

        return encoded.data(using: .utf8)
    }
}

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
