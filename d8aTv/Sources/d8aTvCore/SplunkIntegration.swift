import Foundation
import Combine

// MARK: - Splunk Configuration

/// Configuration for Splunk instance connection
public struct SplunkConfiguration {
    public let baseURL: URL
    public let credentials: SplunkCredentials
    public let defaultApp: String
    public let defaultOwner: String
    public let timeout: TimeInterval
    public let maxRetries: Int
    public let retryDelay: TimeInterval
    public let allowInsecureConnections: Bool
    public let validateSSLCertificate: Bool
    public let dashboardSyncSettings: DashboardSyncSettings
    public let appFilters: AppFilters
    public let authenticationMethods: AuthenticationMethods
    public let coreDataMapping: CoreDataMapping
    public let debugSettings: DebugSettings
    
    public init(
        baseURL: URL,
        credentials: SplunkCredentials,
        defaultApp: String = "search",
        defaultOwner: String = "admin",
        timeout: TimeInterval = 30,
        maxRetries: Int = 3,
        retryDelay: TimeInterval = 2.0,
        allowInsecureConnections: Bool = false,
        validateSSLCertificate: Bool = true,
        dashboardSyncSettings: DashboardSyncSettings = DashboardSyncSettings(),
        appFilters: AppFilters = AppFilters(),
        authenticationMethods: AuthenticationMethods = AuthenticationMethods(),
        coreDataMapping: CoreDataMapping = CoreDataMapping(),
        debugSettings: DebugSettings = DebugSettings()
    ) {
        self.baseURL = baseURL
        self.credentials = credentials
        self.defaultApp = defaultApp
        self.defaultOwner = defaultOwner
        self.timeout = timeout
        self.maxRetries = maxRetries
        self.retryDelay = retryDelay
        self.allowInsecureConnections = allowInsecureConnections
        self.validateSSLCertificate = validateSSLCertificate
        self.dashboardSyncSettings = dashboardSyncSettings
        self.appFilters = appFilters
        self.authenticationMethods = authenticationMethods
        self.coreDataMapping = coreDataMapping
        self.debugSettings = debugSettings
    }
    
    /// Load configuration from SplunkConfiguration.plist resource
    public static func loadFromPlist() throws -> SplunkConfigurationTemplate {
        guard let plistURL = Bundle.module.url(forResource: "SplunkConfiguration", withExtension: "plist") else {
            throw SplunkError.configurationNotFound
        }
        
        do {
            let plistData = try Data(contentsOf: plistURL)
            
            let plistObject = try PropertyListSerialization.propertyList(
                from: plistData,
                options: [],
                format: nil
            )
            
            guard let plist = plistObject as? [String: Any] else {
                throw SplunkError.configurationLoadFailed("Invalid plist format")
            }
            
            return try SplunkConfigurationTemplate.from(plist: plist)
        } catch let error as SplunkError {
            throw error
        } catch {
            throw SplunkError.configurationLoadFailed("Failed to load SplunkConfiguration.plist: \(error.localizedDescription)")
        }
    }
}

// MARK: - Configuration Template (from plist)

/// Template loaded from plist - needs credentials to become full configuration
public struct SplunkConfigurationTemplate {
    public let baseURL: URL
    public let defaultApp: String
    public let defaultOwner: String
    public let timeout: TimeInterval
    public let maxRetries: Int
    public let retryDelay: TimeInterval
    public let allowInsecureConnections: Bool
    public let validateSSLCertificate: Bool
    public let dashboardSyncSettings: DashboardSyncSettings
    public let appFilters: AppFilters
    public let authenticationMethods: AuthenticationMethods
    public let coreDataMapping: CoreDataMapping
    public let debugSettings: DebugSettings
    
    /// Convert template to full configuration by adding credentials
    public func withCredentials(_ credentials: SplunkCredentials) -> SplunkConfiguration {
        return SplunkConfiguration(
            baseURL: baseURL,
            credentials: credentials,
            defaultApp: defaultApp,
            defaultOwner: defaultOwner,
            timeout: timeout,
            maxRetries: maxRetries,
            retryDelay: retryDelay,
            allowInsecureConnections: allowInsecureConnections,
            validateSSLCertificate: validateSSLCertificate,
            dashboardSyncSettings: dashboardSyncSettings,
            appFilters: appFilters,
            authenticationMethods: authenticationMethods,
            coreDataMapping: coreDataMapping,
            debugSettings: debugSettings
        )
    }
    
    static func from(plist: [String: Any]) throws -> SplunkConfigurationTemplate {
        guard let baseURLString = plist["baseURL"] as? String,
              let baseURL = URL(string: baseURLString) else {
            throw SplunkError.configurationLoadFailed("Missing or invalid baseURL")
        }
        
        let defaultApp = plist["defaultApp"] as? String ?? "search"
        let defaultOwner = plist["defaultOwner"] as? String ?? "admin"
        let timeout = plist["timeout"] as? TimeInterval ?? 30.0
        let maxRetries = plist["maxRetries"] as? Int ?? 3
        let retryDelay = plist["retryDelay"] as? TimeInterval ?? 2.0
        let allowInsecureConnections = plist["allowInsecureConnections"] as? Bool ?? false
        let validateSSLCertificate = plist["validateSSLCertificate"] as? Bool ?? true
        
        let dashboardSyncSettings = try DashboardSyncSettings.from(
            plist: plist["dashboardSyncSettings"] as? [String: Any] ?? [:]
        )
        
        let appFilters = try AppFilters.from(
            plist: plist["appFilters"] as? [String: Any] ?? [:]
        )
        
        let authenticationMethods = try AuthenticationMethods.from(
            plist: plist["authenticationMethods"] as? [String: Any] ?? [:]
        )
        
        let coreDataMapping = try CoreDataMapping.from(
            plist: plist["coreDataMapping"] as? [String: Any] ?? [:]
        )
        
        let debugSettings = try DebugSettings.from(
            plist: plist["debugSettings"] as? [String: Any] ?? [:]
        )
        
        return SplunkConfigurationTemplate(
            baseURL: baseURL,
            defaultApp: defaultApp,
            defaultOwner: defaultOwner,
            timeout: timeout,
            maxRetries: maxRetries,
            retryDelay: retryDelay,
            allowInsecureConnections: allowInsecureConnections,
            validateSSLCertificate: validateSSLCertificate,
            dashboardSyncSettings: dashboardSyncSettings,
            appFilters: appFilters,
            authenticationMethods: authenticationMethods,
            coreDataMapping: coreDataMapping,
            debugSettings: debugSettings
        )
    }
}

// MARK: - Configuration Subsections

public struct DashboardSyncSettings {
    public let batchSize: Int
    public let maxDashboards: Int
    public let includePrivate: Bool
    public let defaultAppsToSync: [String]
    public let excludeSystemApps: Bool
    
    public init(
        batchSize: Int = 50,
        maxDashboards: Int = 1000,
        includePrivate: Bool = false,
        defaultAppsToSync: [String] = ["search"],
        excludeSystemApps: Bool = true
    ) {
        self.batchSize = batchSize
        self.maxDashboards = maxDashboards
        self.includePrivate = includePrivate
        self.defaultAppsToSync = defaultAppsToSync
        self.excludeSystemApps = excludeSystemApps
    }
    
    static func from(plist: [String: Any]) throws -> DashboardSyncSettings {
        return DashboardSyncSettings(
            batchSize: plist["batchSize"] as? Int ?? 50,
            maxDashboards: plist["maxDashboards"] as? Int ?? 1000,
            includePrivate: plist["includePrivate"] as? Bool ?? false,
            defaultAppsToSync: plist["defaultAppsToSync"] as? [String] ?? ["search"],
            excludeSystemApps: plist["excludeSystemApps"] as? Bool ?? true
        )
    }
}

public struct AppFilters {
    public let excludePatterns: [String]
    public let includeOnlyVisible: Bool
    public let includeOnlyEnabled: Bool
    
    public init(
        excludePatterns: [String] = [],
        includeOnlyVisible: Bool = true,
        includeOnlyEnabled: Bool = true
    ) {
        self.excludePatterns = excludePatterns
        self.includeOnlyVisible = includeOnlyVisible
        self.includeOnlyEnabled = includeOnlyEnabled
    }
    
    static func from(plist: [String: Any]) throws -> AppFilters {
        return AppFilters(
            excludePatterns: plist["excludePatterns"] as? [String] ?? [],
            includeOnlyVisible: plist["includeOnlyVisible"] as? Bool ?? true,
            includeOnlyEnabled: plist["includeOnlyEnabled"] as? Bool ?? true
        )
    }
}

public struct AuthenticationMethods {
    public let preferredMethod: String
    public let supportedMethods: [String]
    public let tokenEndpoint: String
    public let sessionKeyEndpoint: String
    
    public init(
        preferredMethod: String = "token",
        supportedMethods: [String] = ["token", "basic", "sessionKey"],
        tokenEndpoint: String = "/services/auth/login",
        sessionKeyEndpoint: String = "/services/auth/login"
    ) {
        self.preferredMethod = preferredMethod
        self.supportedMethods = supportedMethods
        self.tokenEndpoint = tokenEndpoint
        self.sessionKeyEndpoint = sessionKeyEndpoint
    }
    
    static func from(plist: [String: Any]) throws -> AuthenticationMethods {
        return AuthenticationMethods(
            preferredMethod: plist["preferredMethod"] as? String ?? "token",
            supportedMethods: plist["supportedMethods"] as? [String] ?? ["token", "basic", "sessionKey"],
            tokenEndpoint: plist["tokenEndpoint"] as? String ?? "/services/auth/login",
            sessionKeyEndpoint: plist["sessionKeyEndpoint"] as? String ?? "/services/auth/login"
        )
    }
}

public struct CoreDataMapping {
    public let entityName: String
    public let batchInsertSize: Int
    public let preserveSourceXML: Bool
    public let extractTokens: Bool
    public let parseSearches: Bool
    
    public init(
        entityName: String = "SplunkDashboard",
        batchInsertSize: Int = 100,
        preserveSourceXML: Bool = true,
        extractTokens: Bool = true,
        parseSearches: Bool = true
    ) {
        self.entityName = entityName
        self.batchInsertSize = batchInsertSize
        self.preserveSourceXML = preserveSourceXML
        self.extractTokens = extractTokens
        self.parseSearches = parseSearches
    }
    
    static func from(plist: [String: Any]) throws -> CoreDataMapping {
        return CoreDataMapping(
            entityName: plist["entityName"] as? String ?? "SplunkDashboard",
            batchInsertSize: plist["batchInsertSize"] as? Int ?? 100,
            preserveSourceXML: plist["preserveSourceXML"] as? Bool ?? true,
            extractTokens: plist["extractTokens"] as? Bool ?? true,
            parseSearches: plist["parseSearches"] as? Bool ?? true
        )
    }
}

public struct DebugSettings {
    public let logLevel: String
    public let logNetworkRequests: Bool
    public let logCoreDataOperations: Bool
    public let enablePerformanceMetrics: Bool
    
    public init(
        logLevel: String = "info",
        logNetworkRequests: Bool = true,
        logCoreDataOperations: Bool = false,
        enablePerformanceMetrics: Bool = true
    ) {
        self.logLevel = logLevel
        self.logNetworkRequests = logNetworkRequests
        self.logCoreDataOperations = logCoreDataOperations
        self.enablePerformanceMetrics = enablePerformanceMetrics
    }
    
    static func from(plist: [String: Any]) throws -> DebugSettings {
        return DebugSettings(
            logLevel: plist["logLevel"] as? String ?? "info",
            logNetworkRequests: plist["logNetworkRequests"] as? Bool ?? true,
            logCoreDataOperations: plist["logCoreDataOperations"] as? Bool ?? false,
            enablePerformanceMetrics: plist["enablePerformanceMetrics"] as? Bool ?? true
        )
    }
}

// MARK: - Splunk REST Client

/// Low-level Splunk REST API client
public class SplunkRestClient {
    
    public let configuration: SplunkConfiguration
    private let session: URLSession
    
    public init(configuration: SplunkConfiguration) {
        self.configuration = configuration
        
        // Configure session for Splunk API
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = configuration.timeout
        config.timeoutIntervalForResource = 300
        
        // Create session with SSL handling
        if configuration.allowInsecureConnections || !configuration.validateSSLCertificate {
            // Create a session delegate to handle SSL certificate validation
            let delegate = SplunkURLSessionDelegate(
                allowInsecureConnections: configuration.allowInsecureConnections,
                validateSSLCertificate: configuration.validateSSLCertificate
            )
            self.session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        } else {
            self.session = URLSession(configuration: config)
        }
    }
    
    // MARK: - Network Testing
    
    /// Test basic network connectivity to the Splunk server
    public func testConnectivity() async throws {
        let testURL = configuration.baseURL.appendingPathComponent("/services/server/info")
        
        var request = URLRequest(url: testURL)
        request.httpMethod = "GET"
        request.timeoutInterval = configuration.timeout
        
        if configuration.debugSettings.logNetworkRequests {
            print("🌐 Testing connectivity to: \(testURL)")
            print("📋 Request headers: \(request.allHTTPHeaderFields ?? [:])")
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if configuration.debugSettings.logNetworkRequests {
                    print("✅ Network response: \(httpResponse.statusCode)")
                    print("📥 Response headers: \(httpResponse.allHeaderFields)")
                    print("📦 Response size: \(data.count) bytes")
                }
            }
        } catch {
            if configuration.debugSettings.logNetworkRequests {
                print("❌ Network error: \(error)")
                if let nsError = error as NSError? {
                    print("📋 Error domain: \(nsError.domain)")
                    print("📋 Error code: \(nsError.code)")
                    print("📋 Error info: \(nsError.userInfo)")
                }
            }
            throw SplunkError.networkError(error)
        }
    }
    
    // MARK: - Generic REST Methods
    
    /// Generic GET request to Splunk REST API
    public func get<T: Codable>(_ endpoint: String, 
                               parameters: [String: String] = [:],
                               responseType: T.Type) async throws -> T {
        let request = try buildRequest(endpoint: endpoint, 
                                     method: "GET", 
                                     parameters: parameters)
        return try await executeRequest(request, responseType: responseType)
    }
    
    /// Generic POST request to Splunk REST API  
    public func post<T: Codable>(_ endpoint: String,
                               body: (any Codable)? = nil,
                               parameters: [String: String] = [:],
                               responseType: T.Type) async throws -> T {
        let request = try buildRequest(endpoint: endpoint,
                                     method: "POST",
                                     parameters: parameters,
                                     body: body)
        return try await executeRequest(request, responseType: responseType)
    }
    
    /// Generic PUT request to Splunk REST API
    public func put<T: Codable>(_ endpoint: String,
                              body: (any Codable)? = nil,
                              parameters: [String: String] = [:],
                              responseType: T.Type) async throws -> T {
        let request = try buildRequest(endpoint: endpoint,
                                     method: "PUT",
                                     parameters: parameters,
                                     body: body)
        return try await executeRequest(request, responseType: responseType)
    }
    
    /// Generic DELETE request to Splunk REST API
    public func delete<T: Codable>(_ endpoint: String,
                                 parameters: [String: String] = [:],
                                 responseType: T.Type) async throws -> T {
        let request = try buildRequest(endpoint: endpoint,
                                     method: "DELETE",
                                     parameters: parameters)
        return try await executeRequest(request, responseType: responseType)
    }
    
    // MARK: - Request Building
    
    private func buildRequest(endpoint: String,
                            method: String,
                            parameters: [String: String] = [:],
                            body: (any Codable)? = nil) throws -> URLRequest {
        
        var components = URLComponents(url: configuration.baseURL.appendingPathComponent(endpoint), 
                                     resolvingAgainstBaseURL: true)!
        
        // Add query parameters
        if !parameters.isEmpty {
            components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        
        guard let url = components.url else {
            throw SplunkError.invalidURL(endpoint)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        // Add authentication
        switch configuration.credentials {
        case .token(let token):
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        case .basic(let username, let password):
            let credentials = "\(username):\(password)".data(using: .utf8)!.base64EncodedString()
            request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        case .sessionKey(let key):
            request.setValue("Splunk \(key)", forHTTPHeaderField: "Authorization")
        }
        
        // Set content type
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add body if present
        if let body = body {
            if let formBody = body as? FormEncodedBody {
                request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                request.httpBody = formBody.formEncodedString().data(using: .utf8)
            } else {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONEncoder().encode(body)
            }
        }
        
        return request
    }
    
    // MARK: - Request Execution
    
    private func executeRequest<T: Codable>(_ request: URLRequest, 
                                          responseType: T.Type) async throws -> T {
        
        if configuration.debugSettings.logNetworkRequests {
            print("🌐 Executing request: \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "unknown")")
            print("📋 Request headers: \(request.allHTTPHeaderFields ?? [:])")
            if let body = request.httpBody {
                print("📦 Request body: \(String(data: body, encoding: .utf8) ?? "binary data")")
            }
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SplunkError.invalidResponse
        }
        
        if configuration.debugSettings.logNetworkRequests {
            print("✅ Response status: \(httpResponse.statusCode)")
            print("📥 Response headers: \(httpResponse.allHeaderFields)")
            print("📦 Response data size: \(data.count) bytes")
            if data.count > 0 && data.count < 1000 {
                print("📝 Response body: \(String(data: data, encoding: .utf8) ?? "unable to decode")")
            }
        }
        
        // Handle HTTP status codes
        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401:
            throw SplunkError.unauthorized
        case 403:
            throw SplunkError.forbidden
        case 404:
            throw SplunkError.notFound
        case 500...599:
            throw SplunkError.serverError(httpResponse.statusCode)
        default:
            throw SplunkError.httpError(httpResponse.statusCode)
        }
        
        // Check for empty response data
        guard !data.isEmpty else {
            throw SplunkError.decodingError(NSError(
                domain: "SplunkIntegration", 
                code: -1, 
                userInfo: [NSLocalizedDescriptionKey: "Empty response data from server"]
            ))
        }
        
        // Parse JSON response
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(responseType, from: data)
        } catch {
            if configuration.debugSettings.logNetworkRequests {
                print("❌ JSON decoding failed for response: \(String(data: data, encoding: .utf8) ?? "unable to decode")")
                print("🔍 Attempted to decode as type: \(responseType)")
                print("🔍 Decoding error details: \(error)")
                
                // Additional detail for DecodingError
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .typeMismatch(let type, let context):
                        print("   Type mismatch: Expected \(type) at \(context.codingPath)")
                        print("   Context: \(context.debugDescription)")
                    case .valueNotFound(let type, let context):
                        print("   Value not found: \(type) at \(context.codingPath)")
                        print("   Context: \(context.debugDescription)")
                    case .keyNotFound(let key, let context):
                        print("   Key not found: \(key) at \(context.codingPath)")
                        print("   Context: \(context.debugDescription)")
                    case .dataCorrupted(let context):
                        print("   Data corrupted at \(context.codingPath)")
                        print("   Context: \(context.debugDescription)")
                    @unknown default:
                        print("   Unknown decoding error: \(decodingError)")
                    }
                }
            }
            throw SplunkError.decodingError(error)
        }
    }
}

// MARK: - URL Session Delegate for SSL Handling

/// URLSession delegate to handle SSL certificate validation based on configuration
private final class SplunkURLSessionDelegate: NSObject, URLSessionDelegate {
    private let allowInsecureConnections: Bool
    private let validateSSLCertificate: Bool
    
    init(allowInsecureConnections: Bool, validateSSLCertificate: Bool) {
        self.allowInsecureConnections = allowInsecureConnections
        self.validateSSLCertificate = validateSSLCertificate
        super.init()
    }
    
    func urlSession(_ session: URLSession, 
                   didReceive challenge: URLAuthenticationChallenge, 
                   completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        // Handle server trust challenges (SSL certificates)
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        // If we don't want to validate SSL certificates, accept any certificate
        if !validateSSLCertificate {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                let credential = URLCredential(trust: serverTrust)
                completionHandler(.useCredential, credential)
                return
            }
        }
        
        // If we allow insecure connections, be more lenient with certificates
        if allowInsecureConnections {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                let credential = URLCredential(trust: serverTrust)
                completionHandler(.useCredential, credential)
                return
            }
        }
        
        // Default behavior - use system validation
        completionHandler(.performDefaultHandling, nil)
    }
}

// MARK: - Splunk Dashboard Service

/// High-level service for dashboard operations
public class SplunkDashboardService {
    
    private let restClient: SplunkRestClient
    private let searchService: SplunkSearchService
    
    public init(restClient: SplunkRestClient) {
        self.restClient = restClient
        self.searchService = SplunkSearchService(restClient: restClient)
    }
    
    /// List all available dashboards with configurable scope
    public func listDashboards(
        owner: String? = nil, 
        app: String? = nil,
        count: Int = 0,
        offset: Int = 0
    ) async throws -> SplunkDashboardList {
        // let finalOwner = owner ?? restClient.configuration.defaultOwner
        let finalApp = app ?? restClient.configuration.defaultApp

        // Build the search query to get dashboard information
        // Using the REST command to query the views endpoint
        var searchQuery = "| rest /servicesNS/-/\(finalApp)/data/ui/views"
        
        // Filter for dashboards only (exclude other view types)
        searchQuery += " | where match('eai:type', \"views\") AND NOT match ('eai:data',\"version=.2.\")  AND NOT match ('eai:data',\"script=.*?js\")  AND isDashboard=1 AND ( like(rootNode,\"dashboard\") OR like(rootNode,\"form\") ) "
        
        
        // Select and rename fields for easier parsing
        searchQuery += " | eval name=title | fields title, name, author, updated, published, eai:data, eai:type, eai:acl.owner, rootNode"
        
        // Execute the search and wait for results
        let searchResults = try await searchService.executeSearchAndWait(
            query: searchQuery,
            app: finalApp,
            timeout: 60,
            parameters: ["output_mode": "json"]
        )
        
        // Convert search results to dashboard list
        return try convertSearchResultsToDashboardList(searchResults)
    }
    
    /// Convert search results to SplunkDashboardList
    private func convertSearchResultsToDashboardList(_ searchResults: SplunkSearchResults) throws -> SplunkDashboardList {
        var dashboards: [SplunkDashboard] = []
        
        for result in searchResults.results {
            // Extract dashboard information from search result fields
            // The REST endpoint returns different field names than the direct API
            guard let title = result["title"]?.value as? String ?? result["name"]?.value as? String else {
                continue // Skip results without a name/title
            }
            
            let author = result["author"]?.value as? String ?? 
                        result["eai:acl.owner"]?.value as? String ?? 
                        result["eai:acl.app"]?.value as? String ?? 
                        "unknown"
            
            let updated = result["updated"]?.value as? String ?? 
                         result["eai:updated"]?.value as? String ?? 
                         ""
            
            let published = result["published"]?.value as? String ?? 
                           result["eai:published"]?.value as? String ?? 
                           updated
            
            let eaiData = result["eai:data"]?.value as? String ?? ""
            let eaiType = result["eai:type"]?.value as? String ?? "views"
            let rootNode = result["rootNode"]?.value as? String ?? result["eai:attributes.rootNode"]?.value as? String
            
            // Check if it's a dashboard (vs other view types)
            let isDashboard = result["isDashboard"]?.value as? String == "1" ||
                             result["isDashboard"]?.value as? Bool == true ||
                             eaiType == "views"
            
            let dashboard = SplunkDashboard(
                name: title,
                author: author,
                published: published,
                updated: updated,
                content: SplunkDashboard.SplunkDashboardContent(
                    eaiData: eaiData,
                    eaiType: eaiType,
                    rootNode: rootNode,
                    isDashboard: isDashboard
                )
            )
            
            dashboards.append(dashboard)
        }
        
        // Create paging information based on search results
        let paging = SplunkPaging(
            total: dashboards.count,
            perPage: searchResults.results.count,
            offset: searchResults.offset
        )
        
        return SplunkDashboardList(entry: dashboards, paging: paging)
    }
    
    /// Get specific dashboard configuration
    public func getDashboard(
        name: String,
        owner: String? = nil,
        app: String? = nil
    ) async throws -> SplunkDashboard {
        //let finalOwner = owner ?? restClient.configuration.defaultOwner
        let finalApp = app ?? restClient.configuration.defaultApp
        
        let endpoint = "servicesNS/-/\(finalApp)/data/ui/views/\(name)"
        let parameters = [
            "output_mode": "json"
        ]
        
        let response = try await restClient.get(endpoint,
                                              parameters: parameters,
                                              responseType: SplunkDashboardResponse.self)
        
        guard let dashboard = response.entry.first else {
            throw SplunkError.dashboardNotFound(name)
        }
        
        return dashboard
    }
    
    /// Get dashboard XML content
    public func getDashboardXML(
        name: String,
        owner: String? = nil, 
        app: String? = nil
    ) async throws -> String {
        let dashboard = try await getDashboard(name: name, owner: owner, app: app)
        return dashboard.content.eaiData
    }
    
    /// Get available apps for dashboard listing
    public func getAvailableApps() async throws -> [SplunkApp] {
        let endpoint = "services/apps/local"
        let parameters = [
            "output_mode": "json",
            "count": "0"
        ]
        
        return try await restClient.get(endpoint,
                                      parameters: parameters,
                                      responseType: SplunkAppList.self).entry
    }
}

// MARK: - Splunk Search Service

/// Service for executing searches and managing search jobs
public class SplunkSearchService {
    
    private let restClient: SplunkRestClient
    
    public init(restClient: SplunkRestClient) {
        self.restClient = restClient
    }
    
    /// Execute a search and return job SID with comprehensive parameters
    public func createSearchJob(
        query: String,
        earliest: String? = nil,
        latest: String? = nil,
        app: String? = nil,
        maxCount: Int? = nil,
        parameters: [String: Any] = [:]
    ) async throws -> SplunkSearchJob {
        let endpoint = "services/search/jobs"
        
        var searchParams = parameters
        searchParams["search"] = query
        searchParams["output_mode"] = "json"
        
        // Add time range parameters if provided
        if let earliest = earliest {
            searchParams["earliest_time"] = earliest
        }
        if let latest = latest {
            searchParams["latest_time"] = latest
        }
        
        // Add app context if provided
        if let app = app {
            searchParams["namespace"] = app
        }
        
        // Add result limits if provided
        if let maxCount = maxCount {
            searchParams["max_count"] = maxCount
        }
        
        // Create a form-encoded body for the POST request
        let formBody = FormEncodedBody(searchParams)
        
        let jobResponse = try await restClient.post(endpoint, 
                                                  body: formBody,
                                                  responseType: SplunkSearchJobResponse.self)
        return SplunkSearchJob(sid: jobResponse.sid)
    }
    

    
    /// Get search job status
    public func getSearchJobStatus(sid: String) async throws -> SplunkSearchJobStatus {
        let endpoint = "services/search/jobs/\(sid)"
        let parameters = ["output_mode": "json"]
        
        do {
            let response = try await restClient.get(endpoint,
                                                  parameters: parameters,
                                                  responseType: SplunkSearchJobStatusResponse.self)
            
            guard let entry = response.entry.first else {
                throw SplunkError.searchJobNotFound(sid)
            }
            
            return entry.content
            
        } catch SplunkError.notFound {
            // Search job might not exist yet or has been cleaned up
            throw SplunkError.searchJobNotFound(sid)
        } catch SplunkError.decodingError(let error) {
            // Log the actual error for debugging
            if restClient.configuration.debugSettings.logNetworkRequests {
                print("❌ Failed to decode search job status for SID \(sid): \(error)")
            }
            throw SplunkError.decodingError(error)
        }
    }
    
    /// Get search results with pagination
    public func getSearchResults(
        sid: String,
        offset: Int = 0,
        count: Int = 100,
        outputMode: String = "json"
    ) async throws -> SplunkSearchResults {
        let endpoint = "services/search/jobs/\(sid)/results"
        let parameters = [
            "output_mode": outputMode,
            "offset": String(offset),
            "count": String(count)
        ]
        
        return try await restClient.get(endpoint,
                                      parameters: parameters,
                                      responseType: SplunkSearchResults.self)
    }
    
    /// Submit search job and return immediately for monitoring
    public func submitSearch(
        query: String,
        earliest: String? = nil,
        latest: String? = nil,
        app: String? = nil,
        parameters: [String: Any] = [:]
    ) async throws -> MonitorableSearchJob {
        let job = try await createSearchJob(
            query: query,
            earliest: earliest,
            latest: latest,
            app: app,
            parameters: parameters
        )
        
        if restClient.configuration.debugSettings.logNetworkRequests {
            print("🔍 Submitted search job with SID: \(job.sid)")
        }
        
        return MonitorableSearchJob(sid: job.sid, restClient: restClient)
    }
    
    /// Wait for search completion and return results
    public func executeSearchAndWait(
        query: String,
        earliest: String? = nil,
        latest: String? = nil,
        app: String? = nil,
        timeout: TimeInterval = 3000,
        pollInterval: TimeInterval = 1,
        parameters: [String: Any] = [:]
    ) async throws -> SplunkSearchResults {
        
        // Create search job
        let job = try await createSearchJob(
            query: query,
            earliest: earliest,
            latest: latest,
            app: app,
            parameters: parameters
        )
        
        if restClient.configuration.debugSettings.logNetworkRequests {
            print("🔍 Created search job with SID: \(job.sid)")
        }
        
        // Poll for completion
        let startTime = Date()
        var pollCount = 0
        
        while Date().timeIntervalSince(startTime) < timeout {
            let status = try await getSearchJobStatus(sid: job.sid)
            
            pollCount += 1
            
            if restClient.configuration.debugSettings.logNetworkRequests {
                print("📊 Poll \(pollCount): Job \(job.sid) status: \(status.dispatchState) (Progress: \(status.doneProgress), Results: \(status.resultCount ?? 0))")
            }
            
            switch status.dispatchState {
            case "DONE":
                if restClient.configuration.debugSettings.logNetworkRequests {
                    print("✅ Search completed! Getting results for job: \(job.sid)")
                }
                let results = try await getSearchResults(sid: job.sid)
                if restClient.configuration.debugSettings.logNetworkRequests {
                    print("📋 Retrieved \(results.results.count) results")
                }
                return results
            case "FAILED":
                if restClient.configuration.debugSettings.logNetworkRequests {
                    print("❌ Search failed for job: \(job.sid)")
                    if let messages = status.messages {
                        for message in messages {
                            print("   \(message.type): \(message.text)")
                        }
                    }
                }
                
                let errorMessages = status.messages?.map { "\($0.type): \($0.text)" }.joined(separator: "; ") ?? "Unknown error"
                throw SplunkError.searchFailed("\(job.sid) - \(errorMessages)")
            case "QUEUED", "PARSING", "RUNNING":
                // Continue polling
                try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
            default:
                if restClient.configuration.debugSettings.logNetworkRequests {
                    print("⚠️ Unknown search state: \(status.dispatchState) for job: \(job.sid)")
                }
                throw SplunkError.unknownSearchState(status.dispatchState)
            }
        }
        
        if restClient.configuration.debugSettings.logNetworkRequests {
            print("⏰ Search timed out after \(timeout) seconds for job: \(job.sid)")
        }
        throw SplunkError.searchTimeout(job.sid)
    }
}

// MARK: - Splunk Authentication Service

/// Service for handling authentication with Splunk
public class SplunkAuthenticationService {
    
    private let restClient: SplunkRestClient
    
    public init(restClient: SplunkRestClient) {
        self.restClient = restClient
    }
    
    /// Authenticate using username and password, returns session key
    public func authenticate(username: String, password: String) async throws -> String {
        let endpoint = "services/auth/login"
        let formParams = [
            "username": username,
            "password": password,
            "output_mode": "json"
        ]
        
        let formBody = FormEncodedBody(formParams)
        
        do {
            let response = try await restClient.post(endpoint,
                                                   body: formBody,
                                                   responseType: SplunkAuthResponse.self)
            return response.sessionKey
        } catch {
            throw SplunkError.authenticationFailed("Invalid username or password")
        }
    }
    
    /// Verify that current credentials are valid
    public func verifyCredentials() async throws -> Bool {
        let endpoint = "services/authentication/current-context"
        let parameters = ["output_mode": "json"]
        
        do {
            let _ = try await restClient.get(endpoint,
                                           parameters: parameters,
                                           responseType: SplunkCurrentUserResponse.self)
            return true
        } catch SplunkError.unauthorized, SplunkError.forbidden {
            return false
        } catch {
            throw error
        }
    }
    
    /// Get information about the current user
    public func getCurrentUser() async throws -> SplunkUser {
        let endpoint = "services/authentication/current-context"
        let parameters = ["output_mode": "json"]
        
        let response = try await restClient.get(endpoint,
                                              parameters: parameters,
                                              responseType: SplunkCurrentUserResponse.self)
        
        guard let user = response.entry.first else {
            throw SplunkError.authenticationFailed("Could not retrieve current user info")
        }
        
        return user.content
    }
}

// MARK: - Splunk Dashboard Sync Service  

/// Service for syncing dashboards from Splunk to Core Data
public class SplunkDashboardSyncService {
    
    private let dashboardService: SplunkDashboardService
    private let configuration: SplunkConfiguration
    
    public init(dashboardService: SplunkDashboardService, configuration: SplunkConfiguration) {
        self.dashboardService = dashboardService
        self.configuration = configuration
    }
    
    /// Sync all dashboards from specified apps to Core Data
    public func syncDashboards(fromApps apps: [String]? = nil, 
                             toCoreData coreDataLoader: DashboardLoaderProtocol) async throws -> SyncResult {
        let startTime = Date()
        var syncResult = SyncResult()
        
        // Use provided apps or default from configuration
        let appsToSync = apps ?? configuration.dashboardSyncSettings.defaultAppsToSync
        
        for appName in appsToSync {
            do {
                let appSyncResult = try await syncDashboardsFromApp(appName, 
                                                                   toCoreData: coreDataLoader)
                syncResult.merge(with: appSyncResult)
                
                if configuration.debugSettings.enablePerformanceMetrics {
                    print("✅ Synced \(appSyncResult.successCount) dashboards from app '\(appName)'")
                }
                
            } catch {
                syncResult.errors.append("Failed to sync app '\(appName)': \(error.localizedDescription)")
                
                if configuration.debugSettings.logLevel == "debug" {
                    print("⚠️ Error syncing app '\(appName)': \(error)")
                }
            }
        }
        
        syncResult.duration = Date().timeIntervalSince(startTime)
        return syncResult
    }
    
    /// Sync dashboards from a specific app
    private func syncDashboardsFromApp(_ appName: String,
                                     toCoreData coreDataLoader: DashboardLoaderProtocol) async throws -> SyncResult {
        var syncResult = SyncResult()
        
        // Get list of dashboards in the app
        let dashboardList = try await dashboardService.listDashboards(
            owner: configuration.defaultOwner,
            app: appName,
            count: configuration.dashboardSyncSettings.maxDashboards
        )
        
        // Process dashboards in batches
        let batchSize = configuration.dashboardSyncSettings.batchSize
        let dashboards = dashboardList.entry
        
        for batchStart in stride(from: 0, to: dashboards.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, dashboards.count)
            let batch = Array(dashboards[batchStart..<batchEnd])
            
            for dashboard in batch {
                do {
                    // Get full dashboard XML
                    let dashboardXML = try await dashboardService.getDashboardXML(
                        name: dashboard.name,
                        owner: configuration.defaultOwner,
                        app: appName
                    )
                    
                    // Create a temporary XML file to load into Core Data
                    let tempURL = try createTemporaryXMLFile(
                        dashboardId: dashboard.name,  // Use just the dashboard name, not app_dashboard
                        xmlContent: dashboardXML
                    )
                    
                    // Load into Core Data using existing loader with separate app and dashboard names
                    try await coreDataLoader.loadDashboard(
                        from: tempURL.path,
                        dashboardId: dashboard.name,
                        appName: appName
                    )
                    
                    // Clean up temporary file
                    try FileManager.default.removeItem(at: tempURL)
                    
                    syncResult.successCount += 1
                    
                } catch {
                    syncResult.failureCount += 1
                    syncResult.errors.append("Failed to sync dashboard '\(dashboard.name)': \(error.localizedDescription)")
                }
            }
        }
        
        return syncResult
    }
    
    /// Create temporary XML file for Core Data loading
    private func createTemporaryXMLFile(dashboardId: String, xmlContent: String) throws -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempFile = tempDirectory.appendingPathComponent("\(dashboardId).xml")
        
        try xmlContent.write(to: tempFile, atomically: true, encoding: .utf8)
        return tempFile
    }
}

// MARK: - Supporting Types for Authentication and Sync

public struct SplunkAuthResponse: Codable {
    public let sessionKey: String
    
    enum CodingKeys: String, CodingKey {
        case sessionKey
    }
}

public struct SplunkUser: Codable {
    public let username: String
    public let roles: [String]
    public let capabilities: [String]
    
    enum CodingKeys: String, CodingKey {
        case username, roles, capabilities
    }
}

public struct SplunkCurrentUserResponse: Codable {
    public let entry: [SplunkCurrentUserEntry]
    
    public struct SplunkCurrentUserEntry: Codable {
        public let content: SplunkUser
    }
}

/// Protocol for Core Data dashboard loading to allow dependency injection
public protocol DashboardLoaderProtocol {
    func loadDashboard(from path: String, dashboardId: String, appName: String?) async throws
}

/// Result of dashboard sync operation
public struct SyncResult {
    public var successCount: Int = 0
    public var failureCount: Int = 0
    public var errors: [String] = []
    public var duration: TimeInterval = 0
    
    public var totalCount: Int {
        return successCount + failureCount
    }
    
    public mutating func merge(with other: SyncResult) {
        self.successCount += other.successCount
        self.failureCount += other.failureCount
        self.errors.append(contentsOf: other.errors)
    }
    
    public var summary: String {
        return """
        Sync completed in \(String(format: "%.2f", duration))s
        ✅ Success: \(successCount)
        ❌ Failures: \(failureCount)
        📊 Total: \(totalCount)
        """
    }
}

// MARK: - Supporting Types


/// Wrapper for form-encoded request body
public struct FormEncodedBody: Codable {
    private let parameters: [String: Any]
    
    public init(_ parameters: [String: Any]) {
        self.parameters = parameters
    }
    
    public init(from decoder: Decoder) throws {
        // Not used for encoding to server
        self.parameters = [:]
    }
    
    public func encode(to encoder: Encoder) throws {
        // This will be handled specially in the request building
        // Just provide a placeholder implementation
        var container = encoder.singleValueContainer()
        try container.encode("")
    }
    
    internal func formEncodedString() -> String {
        return parameters.compactMap { key, value in
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let encodedValue = String(describing: value).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? String(describing: value)
            return "\(encodedKey)=\(encodedValue)"
        }.joined(separator: "&")
    }
}

public enum SplunkCredentials: Sendable {
    case token(String)
    case basic(username: String, password: String)
    case sessionKey(String)
}

public enum SplunkError: Error, LocalizedError {
    case invalidURL(String)
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case serverError(Int)
    case httpError(Int)
    case decodingError(Error)
    case dashboardNotFound(String)
    case searchJobNotFound(String)
    case searchFailed(String)
    case searchTimeout(String)
    case unknownSearchState(String)
    case configurationNotFound
    case configurationLoadFailed(String)
    case authenticationFailed(String)
    case appNotFound(String)
    case coreDataSyncFailed(String)
    case networkError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Unauthorized - check credentials"
        case .forbidden:
            return "Forbidden - insufficient permissions"
        case .notFound:
            return "Resource not found"
        case .serverError(let code):
            return "Server error: \(code)"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .dashboardNotFound(let name):
            return "Dashboard not found: \(name)"
        case .searchJobNotFound(let sid):
            return "Search job not found: \(sid)"
        case .searchFailed(let sid):
            return "Search failed: \(sid)"
        case .searchTimeout(let sid):
            return "Search timed out: \(sid)"
        case .unknownSearchState(let state):
            return "Unknown search state: \(state)"
        case .configurationNotFound:
            return "SplunkConfiguration.plist not found in app bundle"
        case .configurationLoadFailed(let details):
            return "Failed to load configuration: \(details)"
        case .authenticationFailed(let details):
            return "Authentication failed: \(details)"
        case .appNotFound(let appName):
            return "Application not found: \(appName)"
        case .coreDataSyncFailed(let details):
            return "Core Data sync failed: \(details)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Data Models

public struct SplunkApp: Codable {
    public let name: String
    public let label: String
    public let author: String
    public let version: String
    public let visible: Bool
    public let disabled: Bool
    
    // Raw response structure from Splunk
    private struct Content: Codable {
        let label: String
        let version: String?  // Made optional since some apps don't have version
        let visible: Bool
        let disabled: Bool
        let description: String?
        let core: Bool?
        let configured: Bool?
        let showInNav: Bool?
        
        enum CodingKeys: String, CodingKey {
            case label, version, visible, disabled, description, core, configured
            case showInNav = "show_in_nav"
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case name
        case author
        case content
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        
        let content = try container.decode(Content.self, forKey: .content)
        
        // Use top-level author if available, otherwise default to "unknown"
        let topLevelAuthor = try container.decodeIfPresent(String.self, forKey: .author)
        self.author = topLevelAuthor ?? "unknown"
        
        self.label = content.label
        self.version = content.version ?? "unknown"
        self.visible = content.visible
        self.disabled = content.disabled
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(author, forKey: .author)
        
        let content = Content(
            label: label,
            version: version == "unknown" ? nil : version,
            visible: visible,
            disabled: disabled,
            description: nil,
            core: nil,
            configured: nil,
            showInNav: nil
        )
        try container.encode(content, forKey: .content)
    }
}

public struct SplunkAppList: Codable {
    public let entry: [SplunkApp]
}

public struct SplunkDashboardList: Codable {
    public let entry: [SplunkDashboard]
    public let paging: SplunkPaging
}

public struct SplunkDashboard: Codable {
    public let name: String
    public let author: String
    public let published: String
    public let updated: String
    public let content: SplunkDashboardContent
    
    enum CodingKeys: String, CodingKey {
        case name, author, updated, content
        case published
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.name = try container.decode(String.self, forKey: .name)
        self.author = try container.decode(String.self, forKey: .author)
        self.updated = try container.decode(String.self, forKey: .updated)
        // Use published if available, otherwise fall back to updated
        self.published = try container.decodeIfPresent(String.self, forKey: .published) ?? self.updated
        self.content = try container.decode(SplunkDashboardContent.self, forKey: .content)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(author, forKey: .author)
        try container.encode(updated, forKey: .updated)
        try container.encode(published, forKey: .published)
        try container.encode(content, forKey: .content)
    }
    
    // Convenience initializer for search results
    public init(name: String, author: String, published: String, updated: String, content: SplunkDashboardContent) {
        self.name = name
        self.author = author
        self.published = published
        self.updated = updated
        self.content = content
    }
    
    public struct SplunkDashboardContent: Codable {
        public let eaiData: String
        public let eaiType: String
        public let rootNode: String?
        public let isDashboard: Bool
        
        enum CodingKeys: String, CodingKey {
            case eaiData = "eai:data"
            case eaiType = "eai:type"
            case rootNode
            case isDashboard
        }
        
        public init(eaiData: String, eaiType: String, rootNode: String?, isDashboard: Bool) {
            self.eaiData = eaiData
            self.eaiType = eaiType
            self.rootNode = rootNode
            self.isDashboard = isDashboard
        }
    }
}

public struct SplunkDashboardResponse: Codable {
    public let entry: [SplunkDashboard]
}

public struct SplunkPaging: Codable {
    public let total: Int
    public let perPage: Int
    public let offset: Int
}

public struct SplunkSearchJob: Codable {
    public let sid: String
}

/// Monitorable search job that can track progress and status
public class MonitorableSearchJob {
    public let sid: String
    private let restClient: SplunkRestClient
    private var _isDone: Bool = false
    private var _status: SplunkSearchJobStatus?
    
    internal init(sid: String, restClient: SplunkRestClient) {
        self.sid = sid
        self.restClient = restClient
    }
    
    /// Check if search job is done
    public var isDone: Bool {
        get async throws {
            if _isDone { return true }
            let status = try await getStatus()
            _isDone = status.isDone
            return _isDone
        }
    }
    
    /// Get current search job status
    public func getStatus() async throws -> SplunkSearchJobStatus {
        let endpoint = "services/search/jobs/\(sid)"
        let parameters = ["output_mode": "json"]
        
        let response = try await restClient.get(endpoint,
                                              parameters: parameters,
                                              responseType: SplunkSearchJobStatusResponse.self)
        
        guard let entry = response.entry.first else {
            throw SplunkError.searchJobNotFound(sid)
        }
        
        _status = entry.content
        return entry.content
    }
    
    /// Get search results
    public func getResults(
        offset: Int = 0,
        count: Int = 100,
        outputMode: String = "json"
    ) async throws -> SplunkSearchResults {
        let endpoint = "services/search/jobs/\(sid)/results"
        let parameters = [
            "output_mode": outputMode,
            "offset": String(offset),
            "count": String(count)
        ]
        
        return try await restClient.get(endpoint,
                                      parameters: parameters,
                                      responseType: SplunkSearchResults.self)
    }
    
    /// Cancel the search job
    public func cancel() async throws {
        let endpoint = "services/search/jobs/\(sid)/control"
        let parameters = ["action": "cancel"]
        
        try await restClient.post(endpoint, 
                                 parameters: parameters,
                                 responseType: EmptyResponse.self)
    }
}

public struct SplunkSearchJobResponse: Codable {
    public let sid: String
}

public struct SplunkSearchJobStatus: Codable {
    public let dispatchState: String
    public let doneProgress: Double
    public let scanCount: Int?
    public let eventCount: Int?
    public let resultCount: Int?
    public let runDuration: Double?
    public let isDone: Bool
    public let isFailed: Bool
    public let messages: [SplunkSearchMessage]?
    
    enum CodingKeys: String, CodingKey {
        case dispatchState
        case doneProgress
        case scanCount
        case eventCount
        case resultCount
        case runDuration
        case isDone
        case isFailed
        case messages
    }
}

public struct SplunkSearchMessage: Codable {
    public let type: String
    public let text: String
}

public struct EmptyResponse: Codable {
    // Empty struct for operations that don't return data
}

public struct SplunkSearchJobStatusResponse: Codable {
    public let entry: [SplunkSearchJobStatusEntry]
    
    public struct SplunkSearchJobStatusEntry: Codable {
        public let content: SplunkSearchJobStatus
    }
}

public struct SplunkSearchResults: Codable, Sendable {
    public let results: [[String: AnyCodable]]
    public let fields: [FieldInfo]?
    public let metadata: [String: AnyCodable]?
    public let preview: Bool
    public let offset: Int
    public let lastRow: Bool
    
    public struct FieldInfo: Codable, Sendable {
        public let name: String
        public let type: String?
        public let groupbyRank: String?  // Splunk's groupby_rank field for identifying key columns
        
        enum CodingKeys: String, CodingKey {
            case name
            case type
            case groupbyRank = "groupby_rank"
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case results, fields, preview, offset, lastRow
    }
    
    public init(results: [[String: AnyCodable]], fields: [FieldInfo]? = nil, metadata: [String: AnyCodable]? = nil) {
        self.results = results
        self.fields = fields
        self.metadata = metadata
        self.preview = false
        self.offset = 0
        self.lastRow = true
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle the results array manually
        let rawResults = try container.decode([[String: RawValue]].self, forKey: .results)
        self.results = rawResults.map { dict in
            dict.mapValues { rawValue in
                AnyCodable(rawValue.value)
            }
        }
        
        self.fields = try container.decodeIfPresent([FieldInfo].self, forKey: .fields)
        self.metadata = nil // Will be set separately when needed
        self.preview = try container.decode(Bool.self, forKey: .preview)
        self.offset = try container.decodeIfPresent(Int.self, forKey: .offset) ?? 0
        self.lastRow = try container.decodeIfPresent(Bool.self, forKey: .lastRow) ?? false
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // Convert results for encoding  
        let encodableResults = results.map { dict in
            dict.mapValues { anyCodable in
                RawValue(anyCodable.value)
            }
        }
        
        try container.encode(encodableResults, forKey: .results)
        try container.encodeIfPresent(fields, forKey: .fields)
        try container.encode(preview, forKey: .preview)
        try container.encode(offset, forKey: .offset)
        try container.encode(lastRow, forKey: .lastRow)
    }
    
    /// Convenience property to get just the field names
    public var fieldNames: [String] {
        return fields?.map { $0.name } ?? []
    }
    
    // Helper struct for decoding raw JSON values
    private struct RawValue: Codable {
        let value: Any
        
        init(_ value: Any) {
            self.value = value
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            
            if let intValue = try? container.decode(Int.self) {
                value = intValue
            } else if let doubleValue = try? container.decode(Double.self) {
                value = doubleValue
            } else if let stringValue = try? container.decode(String.self) {
                value = stringValue
            } else if let boolValue = try? container.decode(Bool.self) {
                value = boolValue
            } else if container.decodeNil() {
                value = ""
            } else {
                value = ""
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            
            switch value {
            case let intValue as Int:
                try container.encode(intValue)
            case let doubleValue as Double:
                try container.encode(doubleValue)
            case let stringValue as String:
                try container.encode(stringValue)
            case let boolValue as Bool:
                try container.encode(boolValue)
            default:
                try container.encodeNil()
            }
        }
    }
    
    public struct AnyCodable: Codable, @unchecked Sendable {
        public let value: Any
        
        public init<T>(_ value: T?) {
            self.value = value ?? ()
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            
            if let intValue = try? container.decode(Int.self) {
                value = intValue
            } else if let doubleValue = try? container.decode(Double.self) {
                value = doubleValue
            } else if let stringValue = try? container.decode(String.self) {
                value = stringValue
            } else if let boolValue = try? container.decode(Bool.self) {
                value = boolValue
            } else {
                value = ()
            }
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            
            switch value {
            case let intValue as Int:
                try container.encode(intValue)
            case let doubleValue as Double:
                try container.encode(doubleValue)
            case let stringValue as String:
                try container.encode(stringValue)
            case let boolValue as Bool:
                try container.encode(boolValue)
            default:
                try container.encodeNil()
            }
        }
    }
}

