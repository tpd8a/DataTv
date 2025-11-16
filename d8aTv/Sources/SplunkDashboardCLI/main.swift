/// CLI tool for loading and querying Splunk SimpleXML dashboards in Core Data

import ArgumentParser
import Foundation
import d8aTvCore

@available(macOS 26,tvOS 26,*)

struct SplunkDashboardCLI: AsyncParsableCommand {
    


    static let configuration = CommandConfiguration(
        commandName: "splunk-dashboard",
        abstract: "Load and query Splunk SimpleXML dashboards in Core Data",
        discussion: """
        This CLI tool allows you to:
        • Configure Splunk server connection and credentials
        • Connect to Splunk and authenticate (credentials stored securely)
        • Browse available applications and dashboards
        • Sync dashboard data from Splunk to Core Data
        • Load SimpleXML dashboard files into Core Data
        • Query dashboard structure and token information
        • Search for specific tokens and their usage
        • Export dashboard statistics
        
        Getting Started:
        1. Run 'splunk-dashboard splunk config set-url <url>' to set your Splunk server URL
        2. Run 'splunk-dashboard splunk config set-creds' to set up and verify credentials
        3. Run 'splunk-dashboard splunk apps' to see available applications
        4. Run 'splunk-dashboard splunk sync --all' to sync all dashboards
        5. Run 'splunk-dashboard query list' to see loaded dashboards
        
        Credentials are stored securely in the macOS Keychain and reused automatically.
        Use 'login' command to get fresh session keys when needed.
        """,
        version: "1.0.0",
        subcommands: [
            SplunkCommand.self,
            LoadCommand.self, 
            QueryCommand.self, 
            ClearCommand.self
        ],
        defaultSubcommand: SplunkCommand.self
    )
    
    func run() async throws {
        // This should never be called since we have a defaultSubcommand
        print("Use 'splunk-dashboard --help' for usage information")
    }
}

// MARK: - Splunk Command Group

struct SplunkCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "splunk",
        abstract: "Connect to Splunk and sync dashboard data",
        subcommands: [
            LoginCommand.self,
            ListAppsCommand.self,
            ListDashboardsCommandREST.self,
            SyncCommand.self,
            RunCommand.self,
            ConfigCommand.self,
            TestNetworkCommand.self
        ]
    )
    
    func run() async throws {
        print("🔗 Connect to Splunk and sync dashboard data")
        print("\nAvailable subcommands:")
        print("  config         - Manage Splunk configuration and credentials")
        print("  login          - Authenticate and create session keys")
        print("  apps           - List available applications")
        print("  dashboards     - List dashboards in an application")
        print("  sync           - Sync dashboards from Splunk to Core Data")
        print("  run            - Execute searches found in dashboards")
        print("  test-network   - Test network connectivity to Splunk server")
        print("\n💡 Getting started:")
        print("   1. Run 'config set-url <url>' to set your Splunk server URL")
        print("   2. Run 'config set-creds' to set up and verify credentials")
        print("   3. Run 'login' to get session keys if needed")
        print("   4. Run 'sync --all' to sync all dashboards")
        print("   5. Run 'run <dashboard-id>' to execute searches in a dashboard")
        print("\nUse 'splunk-dashboard splunk <subcommand> --help' for more information")
    }
}

// MARK: - Splunk Subcommands


struct LoginCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "login",
        abstract: "Authenticate with Splunk server and create/store session key"
    )
    
    @Option(name: .shortAndLong, help: "Splunk username")
    var username: String?

    @Option(name: .shortAndLong, help: "Splunk password")
    var password: String?
    
    @Flag(name: .shortAndLong, help: "Verbose output")
    var verbose = false
    
    func run() async throws {
        print("🔐 Logging in to Splunk server...")
        
        do {
            // Load configuration template from plist
            let configTemplate = try SplunkConfiguration.loadFromPlist()
            print("✅ Configuration loaded successfully")
            
            //let credentialManager = SplunkCredentialManager()
            
            let serverHost = configTemplate.baseURL.host ?? configTemplate.baseURL.absoluteString
            
            // Get stored credentials or use command line provided ones
            let credentials: SplunkCredentials
            
            if let username = username, let password = password {
                credentials = .basic(username: username, password: password)
            } else {
                // Try to get stored credentials
                do {
                    credentials = try AuthenticationHelper.getCredentials(serverHost: serverHost)
                } catch {
                    print("❌ No stored credentials found and no username/password provided")
                    print("💡 Use 'splunk-dashboard splunk config set-creds' to set up credentials")
                    print("   Or provide credentials: --username <user> --password <pass>")
                    throw ExitCode.failure
                }
            }
            
            // Create configuration and authenticate
            let configuration = configTemplate.withCredentials(credentials)
            let restClient = SplunkRestClient(configuration: configuration)
            let authService = SplunkAuthenticationService(restClient: restClient)
            
            // For basic credentials, authenticate to get a session key
            switch credentials {
            case .basic(let username, let password):
                print("🔑 Authenticating with username/password to get session key...")
                let sessionKey = try await authService.authenticate(username: username, password: password)
                
                // Store the session key
                let sessionCredentials = SplunkCredentials.sessionKey(sessionKey)
                let sessionConfig = configTemplate.withCredentials(sessionCredentials)
                let sessionRestClient = SplunkRestClient(configuration: sessionConfig)
                let sessionAuthService = SplunkAuthenticationService(restClient: sessionRestClient)
                
                let isValid = try await sessionAuthService.verifyCredentials()
                if isValid {
                    print("✅ Session key obtained and verified successfully!")
                    
                    // Optionally store session key (they are typically short-lived)
                    print("🔐 Session key: \(sessionKey)")
                    print("ℹ️  Session keys are temporary - use for this session only")
                    
                    if verbose {
                        let user = try await sessionAuthService.getCurrentUser()
                        print("👤 User: \(user.username)")
                        print("🏷️  Roles: \(user.roles.joined(separator: ", "))")
                    }
                } else {
                    print("❌ Session key verification failed")
                    throw ExitCode.failure
                }
                
            case .token(_):
                // For tokens, just verify they work
                print("🔍 Verifying API token...")
                let isValid = try await authService.verifyCredentials()
                if isValid {
                    print("✅ API token verified successfully!")
                    
                    if verbose {
                        let user = try await authService.getCurrentUser()
                        print("👤 User: \(user.username)")
                        print("🏷️  Roles: \(user.roles.joined(separator: ", "))")
                    }
                } else {
                    print("❌ API token verification failed")
                    throw ExitCode.failure
                }
                
            case .sessionKey(_):
                // For session keys, just verify they work
                print("🔍 Verifying session key...")
                let isValid = try await authService.verifyCredentials()
                if isValid {
                    print("✅ Session key verified successfully!")
                    
                    if verbose {
                        let user = try await authService.getCurrentUser()
                        print("👤 User: \(user.username)")
                        print("🏷️  Roles: \(user.roles.joined(separator: ", "))")
                    }
                } else {
                    print("❌ Session key verification failed")
                    throw ExitCode.failure
                }
            }
            
        } catch {
            print("❌ Login failed: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}

struct ListAppsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "apps", 
        abstract: "List available Splunk applications"
    )
    
    @Option(name: .shortAndLong, help: "Username for authentication (overrides stored credentials)")
    var username: String?
    
    @Option(name: .shortAndLong, help: "Password for authentication (overrides stored credentials)")
    var password: String?
    
    @Option(name: .shortAndLong, help: "API token for authentication (overrides stored credentials)")
    var token: String?
    
    //@Option(name: .shortAndLong, help: "Path to configuration file")
    //var config: String?
    
    //
    // @Flag(name: .longOnly, help: "Include disabled applications")
    // var includeDisabled: Bool = false
    
    // Flag(name: .longOnly, help: "Include invisible applications")
    // ar includeInvisible: Bool = false
    
    func run() async throws {
        print("📱 Listing Splunk applications...")
        
        do {
            let (dashboardService, configuration) = try await createDashboardService()
            let apps = try await dashboardService.getAvailableApps()
            
            let filteredApps = apps.filter { app in
                let includeApp = (app.visible)
                
                // Apply configuration filters
                if configuration.appFilters.includeOnlyEnabled && app.disabled {
                    return false
                }
                if configuration.appFilters.includeOnlyVisible && !app.visible {
                    return false
                }
                
                // Check exclude patterns
                for pattern in configuration.appFilters.excludePatterns {
                    if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                        let range = NSRange(app.name.startIndex..<app.name.endIndex, in: app.name)
                        if regex.firstMatch(in: app.name, options: [], range: range) != nil {
                            return false
                        }
                    }
                }
                
                return includeApp
            }
            
            if filteredApps.isEmpty {
                print("No applications found matching the criteria.")
                return
            }
            
            print("\n📋 Available Applications (\(filteredApps.count)):")

            
            for app in filteredApps.sorted(by: { $0.name.lowercased() < $1.name.lowercased() }) {
                let status = app.disabled ? "🔴 DISABLED" : (app.visible ? "🟢 VISIBLE" : "🟡 HIDDEN")
                print("📱 \(app.name)")
                print("   Label: \(app.label)")
                print("   Version: \(app.version)")
                print("   Author: \(app.author)")
                print("   Status: \(status)")
                print("")
            }
            
        } catch {
            print("❌ Failed to list applications: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
    
    private func createDashboardService() async throws -> (SplunkDashboardService, SplunkConfiguration) {
        let configuration = try AuthenticationHelper.createConfigurationWithStoredCredentials()
        
        // Override with command line credentials if provided
        let finalConfiguration: SplunkConfiguration
        if username != nil || password != nil || token != nil {
            let serverHost = configuration.baseURL.host ?? configuration.baseURL.absoluteString
            let credentials = try AuthenticationHelper.getCredentials(
                username: username,
                password: password,
                token: token,
                serverHost: serverHost
            )
            let configTemplate = try SplunkConfiguration.loadFromPlist()
            finalConfiguration = configTemplate.withCredentials(credentials)
        } else {
            finalConfiguration = configuration
        }
        
        let restClient = SplunkRestClient(configuration: finalConfiguration)
        return (SplunkDashboardService(restClient: restClient), finalConfiguration)
    }
}

struct ListDashboardsCommandREST: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dashboards",
        abstract: "List dashboards in a Splunk application"
    )
    
    @Option(name: .shortAndLong, help: "Application name")
    var apps: String
    
    @Option(name: .shortAndLong, help: "Username for authentication (overrides stored credentials)") 
    var username: String?
    
    @Option(name: .shortAndLong, help: "Password for authentication (overrides stored credentials)")
    var password: String?
    
    @Option(name: .shortAndLong, help: "API token for authentication (overrides stored credentials)")
    var token: String?
    
    @Option(name: .shortAndLong, help: "Maximum number of dashboards to list")
    var count: Int = 100
    
    func run() async throws {
        print("📊 Listing dashboards in app '\(apps)'...")
        
        do {
            let (dashboardService, _) = try await createDashboardService()
            let dashboardList = try await dashboardService.listDashboards(
                owner: nil,
                app: apps,
                count: count
            )
            
            let dashboards = dashboardList.entry
            
            if dashboards.isEmpty {
                print("No dashboards found in app '\(apps)'.")
                return
            }
            
            print("\n📋 Dashboards in '\(apps)' (\(dashboards.count)):")
 
            
            for dashboard in dashboards.sorted(by: { $0.name.lowercased() < $1.name.lowercased() }) {
                print("📊 \(dashboard.name)")
                print("   Author: \(dashboard.author)")
                print("   Updated: \(dashboard.updated)")
                print("   Type: \(dashboard.content.eaiType)")
                print("")
            }
            
        } catch {
            print("❌ Failed to list dashboards: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
    
    private func createDashboardService() async throws -> (SplunkDashboardService, SplunkConfiguration) {
        let configuration = try AuthenticationHelper.createConfigurationWithStoredCredentials()
        
        // Override with command line credentials if provided
        let finalConfiguration: SplunkConfiguration
        if username != nil || password != nil || token != nil {
            let serverHost = configuration.baseURL.host ?? configuration.baseURL.absoluteString
            let credentials = try AuthenticationHelper.getCredentials(
                username: username,
                password: password,
                token: token,
                serverHost: serverHost
            )
            let configTemplate = try SplunkConfiguration.loadFromPlist()
            finalConfiguration = configTemplate.withCredentials(credentials)
        } else {
            finalConfiguration = configuration
        }
        
        let restClient = SplunkRestClient(configuration: finalConfiguration)
        return (SplunkDashboardService(restClient: restClient), finalConfiguration)
    }
}

struct SyncCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sync",
        abstract: "Sync dashboards from Splunk to Core Data"
    )
    
    @Option(name: .shortAndLong, help: "Username for authentication (overrides stored credentials)")
    var username: String?
    
    @Option(name: .shortAndLong, help: "Password for authentication (overrides stored credentials)") 
    var password: String?
    
    @Option(name: .shortAndLong, help: "API token for authentication (overrides stored credentials)")
    var token: String?
    
    //@Option(name: .shortAndLong, help: "Path to configuration file")
    //var config: String?
    
    @Option(name: .shortAndLong, help: "Specific applications to sync (comma-separated)")
    var apps: String?
    
    @Flag(name: [.customShort("l"), .long], help: "Sync all available applications")
    var all = false
    
    @Flag(name: .shortAndLong, help: "Verbose output")
    var verbose = false
    
    func run() async throws {
        print("🔄 Starting dashboard sync from Splunk to Core Data...")
        
        do {
            let configuration = try AuthenticationHelper.createConfigurationWithStoredCredentials()
            
            // Override with command line credentials if provided
            let finalConfiguration: SplunkConfiguration
            if username != nil || password != nil || token != nil {
                let serverHost = configuration.baseURL.host ?? configuration.baseURL.absoluteString
                let credentials = try AuthenticationHelper.getCredentials(
                    username: username,
                    password: password,
                    token: token,
                    serverHost: serverHost
                )
                let configTemplate = try SplunkConfiguration.loadFromPlist()
                finalConfiguration = configTemplate.withCredentials(credentials)
            } else {
                finalConfiguration = configuration
            }
            
            let restClient = SplunkRestClient(configuration: finalConfiguration)
            let dashboardService = SplunkDashboardService(restClient: restClient)
            let syncService = SplunkDashboardSyncService(
                dashboardService: dashboardService,
                configuration: finalConfiguration
            )
            
            // Create Core Data loader adapter
            let coreDataLoader = await CoreDataLoaderAdapter()
            
            // Determine which apps to sync
            let appsToSync: [String]?
            if all {
                // Get all available apps
                let allApps = try await dashboardService.getAvailableApps()
                appsToSync = allApps.filter { !$0.disabled && $0.visible }.map { $0.name }
                print("📱 Syncing all \(appsToSync?.count ?? 0) available applications")
            } else if let appsString = apps {
                appsToSync = appsString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                print("📱 Syncing specific applications: \(appsToSync?.joined(separator: ", ") ?? "")")
            } else {
                appsToSync = nil
                print("📱 Syncing default applications from configuration")
            }
            
            // Perform sync
            let result = try await syncService.syncDashboards(
                fromApps: appsToSync,
                toCoreData: coreDataLoader
            )
            
            // Display results
            print("\n" + result.summary)
            
            if verbose && !result.errors.isEmpty {
                print("\n⚠️ Errors encountered:")
                for error in result.errors {
                    print("   • \(error)")
                }
            }
            
        } catch {
            print("❌ Sync failed: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}

struct RunCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Execute searches found in dashboards"
    )
    
    @Argument(help: "Dashboard ID to run searches from")
    var dashboardId: String
    
    @Option(name: .shortAndLong, help: "Username for authentication (overrides stored credentials)")
    var username: String?
    
    @Option(name: .shortAndLong, help: "Password for authentication (overrides stored credentials)")
    var password: String?
    
    @Option(name: .long, help: "API token for authentication (overrides stored credentials)")
    var token: String?
    
    @Option(name: [.customShort("s"), .long], help: "Specific search ID to run (runs all if not specified)")
    var searchId: String?
    
    @Option(name: [.customShort("t"), .long], help: "Search type to run (panel, visualization, global, or all)")
    var type: String = "all"
    
    @Option(name: [.customShort("m"), .long], help: "Maximum number of results per search")
    var maxCount: Int?
    
    @Option(name: .long, help: "Search timeout in seconds")
    var timeout: Int?
    
    @Option(name: [.customShort("e"), .long], help: "Earliest time for search (e.g., '-1h@h', '-24h@h')")
    var earliest: String?
    
    @Option(name: [.customShort("l"), .long], help: "Latest time for search (e.g., 'now', '@d')")
    var latest: String?
    
    @Option(name: .long, help: "Token values in 'name=value' format (can be used multiple times)", transform: parseTokenValue)
    var tokens: [TokenValue] = []
    
    @Flag(name: [.customShort("c"), .long], help: "Run searches concurrently")
    var concurrent = false
    
    @Flag(name: .long, help: "Validate searches before running")
    var validate = false
    
    @Flag(name: [.customShort("v"), .long], help: "Show detailed output including search queries")
    var verbose = false
    
    @Flag(name: [.customShort("d"), .long], help: "Dry run - validate and show what would be executed without running")
    var dryRun = false
    
    func run() async throws {
        print("🚀 Executing searches in dashboard: \(dashboardId)")
        
        // Step 1: Discover searches
        let discovery = await MainActor.run {
            return CoreDataManager.shared.findSearches(in: dashboardId)
        }
        
        if let error = discovery.error {
            print("❌ Error discovering searches: \(error)")
            throw ExitCode.failure
        }
        
        // Filter searches by type
        let searchesToRun = filterSearches(discovery)
        
        if searchesToRun.isEmpty {
            print("❌ No searches found matching the criteria")
            return
        }
        
        print("📊 Found \(searchesToRun.count) search(es) to execute")
        
        // Step 2: Validation (if enabled)
        if validate {
            print("🔍 Validating searches...")
            let validationResults = await validateSearches(searchesToRun, in: dashboardId)
            
            let invalidSearches = validationResults.filter { !$0.result.isValid }
            if !invalidSearches.isEmpty {
                print("❌ Found \(invalidSearches.count) invalid search(es):")
                for validation in invalidSearches {
                    print("   • \(validation.searchInfo.id): \(validation.result.issues.map { $0.description }.joined(separator: ", "))")
                }
                
                if !dryRun {
                    print("Use --no-validate to skip validation and run anyway")
                    throw ExitCode.failure
                }
            }
        }
        
        // Step 3: Show what would be executed (for dry run or verbose)
        if dryRun || verbose {
            await showExecutionPlan(searchesToRun, in: dashboardId)
        }
        
        if dryRun {
            print("✅ Dry run completed - no searches were executed")
            return
        }
        
        // Step 4: Execute searches
        print("⚡ Executing searches...")
        
        let startTime = Date()
        let results: [SearchExecutionResult]
        
        if concurrent {
            results = await executeSearchesConcurrently(searchesToRun, in: dashboardId)
        } else {
            results = await executeSearchesSequentially(searchesToRun, in: dashboardId)
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        
        // Step 5: Display results
        await displayResults(results, totalExecutionTime: totalTime)
    }
    
    private func filterSearches(_ discovery: SearchDiscoveryResult) -> [SearchInfo] {
        var searchesToRun: [SearchInfo] = []
        
        if let specificSearchId = searchId {
            // Run only the specified search
            if let searchInfo = discovery.allSearches.first(where: { $0.id == specificSearchId }) {
                searchesToRun = [searchInfo]
            }
        } else {
            // Filter by type
            switch type.lowercased() {
            case "panel":
                searchesToRun = discovery.panelSearches
            case "visualization", "viz":
                searchesToRun = discovery.visualizationSearches
            case "global":
                searchesToRun = discovery.globalSearches
            case "all":
                searchesToRun = discovery.allSearches
            default:
                print("⚠️  Unknown search type '\(type)', using 'all'")
                searchesToRun = discovery.allSearches
            }
        }
        
        return searchesToRun
    }
    
    private func validateSearches(_ searches: [SearchInfo], in dashboardId: String) async -> [SearchValidationWrapper] {
        var results: [SearchValidationWrapper] = []
        
        for searchInfo in searches {
            let validationResult = await MainActor.run {
                return CoreDataManager.shared.validateSearch(searchInfo, in: dashboardId)
            }
            results.append(SearchValidationWrapper(searchInfo: searchInfo, result: validationResult))
        }
        
        return results
    }
    
    private func showExecutionPlan(_ searches: [SearchInfo], in dashboardId: String) async {
        print("\n📋 Execution Plan:")
        print("================")
        
        for (index, searchInfo) in searches.enumerated() {
            print("\n\(index + 1). Search: \(searchInfo.id)")
            print("   Location: \(searchInfo.location.description)")
            print("   Type: \(searchInfo.searchType)")
            
            if let query = searchInfo.query {
                if verbose {
                    print("   Query: \(query)")
                }
                
                // Show token resolution
                let tokenResolution = await MainActor.run {
                    return CoreDataManager.shared.resolveTokens(
                        for: searchInfo,
                        in: dashboardId,
                        userProvidedValues: createTokenValuesDictionary(),
                        timeRange: createTimeRange()
                    )
                }
                
                if !tokenResolution.resolvedValues.isEmpty {
                    print("   Tokens: \(tokenResolution.resolvedValues)")
                }
                
                if !tokenResolution.unresolvedTokens.isEmpty {
                    print("   ⚠️  Unresolved tokens: \(tokenResolution.unresolvedTokens)")
                }
                
                if let resolvedQuery = tokenResolution.resolvedQuery, verbose {
                    print("   Resolved query: \(resolvedQuery)")
                }
            }
        }
        
        print("\nExecution settings:")
        if let maxCount = maxCount { print("   Max results: \(maxCount)") }
        if let timeout = timeout { print("   Timeout: \(timeout)s") }
        if let earliest = earliest { print("   Earliest: \(earliest)") }
        if let latest = latest { print("   Latest: \(latest)") }
        if concurrent { print("   Mode: Concurrent") }
        print("")
    }
    
    private func executeSearchesConcurrently(_ searches: [SearchInfo], in dashboardId: String) async -> [SearchExecutionResult] {
        return await withTaskGroup(of: SearchExecutionResult.self) { group in
            for searchInfo in searches {
                group.addTask {
                    return await self.executeIndividualSearch(searchInfo, in: dashboardId)
                }
            }
            
            var results: [SearchExecutionResult] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
    }
    
    private func executeSearchesSequentially(_ searches: [SearchInfo], in dashboardId: String) async -> [SearchExecutionResult] {
        var results: [SearchExecutionResult] = []
        
        for (index, searchInfo) in searches.enumerated() {
            print("   [\(index + 1)/\(searches.count)] Executing: \(searchInfo.id)")
            let result = await executeIndividualSearch(searchInfo, in: dashboardId)
            results.append(result)
            
            // Brief status update
            if result.isSuccessful {
                print("     ✅ Completed (\(result.resultCount) results)")
            } else {
                print("     ❌ Failed")
            }
        }
        
        return results
    }
    
    private func executeIndividualSearch(_ searchInfo: SearchInfo, in dashboardId: String) async -> SearchExecutionResult {
        // Create parameter overrides
        var overrides = SearchParameterOverrides()
        overrides.maxCount = maxCount
        overrides.timeout = timeout
        overrides.earliestTime = earliest
        overrides.latestTime = latest
        
        do {
            // Get credentials if provided
            var credentials: SplunkCredentials?
            if username != nil || password != nil || token != nil {
                let configTemplate = try SplunkConfiguration.loadFromPlist()
                let serverHost = configTemplate.baseURL.host ?? configTemplate.baseURL.absoluteString
                credentials = try AuthenticationHelper.getCredentials(
                    username: username,
                    password: password,
                    token: token,
                    serverHost: serverHost
                )
            }
            
            // Start the search execution and get execution ID
            let executionId = await MainActor.run {
                return CoreDataManager.shared.startSearchExecution(
                    searchId: searchInfo.id,
                    in: dashboardId,
                    userTokenValues: createTokenValuesDictionary(),
                    timeRange: createTimeRange(),
                    parameterOverrides: overrides,
                    splunkCredentials: credentials
                )
            }
            
            // Monitor the execution until completion
            return await monitorSearchExecution(executionId: executionId, searchInfo: searchInfo)
            
        } catch {
            // Return a failed SearchExecutionResult
            return SearchExecutionResult(
                searchInfo: searchInfo,
                executionStatus: .failed,
                error: .unexpectedError(error),
                jobId: nil,
                results: nil,
                metadata: nil
            )
        }
    }
    
    private func monitorSearchExecution(executionId: String, searchInfo: SearchInfo) async -> SearchExecutionResult {
        let startTime = Date()
        
        // Poll the execution status until completion
        while true {
            let execution = await MainActor.run {
                return CoreDataManager.shared.getSearchExecutionStatus(executionId: executionId)
            }
            
            guard let execution = execution else {
                return SearchExecutionResult(
                    searchInfo: searchInfo,
                    executionStatus: .failed,
                    error: .searchNotFound(executionId),
                    jobId: nil,
                    results: nil,
                    metadata: nil
                )
            }
            
            let status = SearchExecutionStatus(rawValue: execution.status) ?? .pending
            
            switch status {
            case .completed:
                let results = await MainActor.run {
                    return CoreDataManager.shared.getSearchResults(executionId: executionId)
                }
                
                // Create metadata if we have results - for now, just use nil since we'd need more info
                let metadata: SearchExecutionMetadata? = nil
                
                return SearchExecutionResult(
                    searchInfo: searchInfo,
                    executionStatus: .completed,
                    error: nil,
                    jobId: execution.jobId,
                    results: results,
                    metadata: metadata
                )
                
            case .failed:
                let error: SearchExecutionError = execution.errorMessage != nil ?
                    .unexpectedError(NSError(domain: "SearchExecutionDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: execution.errorMessage!])) :
                    .unexpectedError(NSError(domain: "SearchExecutionDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"]))
                
                return SearchExecutionResult(
                    searchInfo: searchInfo,
                    executionStatus: .failed,
                    error: error,
                    jobId: execution.jobId,
                    results: nil,
                    metadata: nil
                )
                
            case .cancelled:
                return SearchExecutionResult(
                    searchInfo: searchInfo,
                    executionStatus: .cancelled,
                    error: .unexpectedError(NSError(domain: "SearchExecutionDomain", code: 2, userInfo: [NSLocalizedDescriptionKey: "Search was cancelled"])),
                    jobId: execution.jobId,
                    results: nil,
                    metadata: nil
                )
                
            case .pending, .running:
                // Wait a bit before checking again
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                continue
            }
        }
    }
    
    private func displayResults(_ results: [SearchExecutionResult], totalExecutionTime: TimeInterval) async {
        print("\n📊 Execution Results:")
        print("=====================")
        
        let successful = results.filter { $0.isSuccessful }
        let failed = results.filter { !$0.isSuccessful }
        
        print("✅ Successful: \(successful.count)")
        print("❌ Failed: \(failed.count)")
        print("⏱️ Total time: \(String(format: "%.2f", totalExecutionTime))s")
        
        if verbose {
            print("\nDetailed Results:")
            for (index, result) in results.enumerated() {
                print("\n\(index + 1). Search: \(result.searchInfo?.id ?? "Unknown")")
                print("   Status: \(result.isSuccessful ? "✅ SUCCESS" : "❌ FAILED")")
                
                if result.isSuccessful {
                    print("   Results: \(result.resultCount) rows")
                    if let results = result.results, !results.results.isEmpty {
                        print("   Sample data (first row):")
                        let firstRow = results.results[0]
                        for (key, value) in firstRow.prefix(3) {
                            print("     \(key): \(value)")
                        }
                        if firstRow.count > 3 {
                            print("     ... (\(firstRow.count - 3) more fields)")
                        }
                    }
                } else {
                    if let error = result.error {
                        print("   Error: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        let totalResults = successful.reduce(0) { $0 + $1.resultCount }
        print("\n📈 Total results retrieved: \(totalResults)")
    }
    
    private func createTokenValuesDictionary() -> [String: String] {
        return Dictionary(uniqueKeysWithValues: tokens.map { ($0.name, $0.value) })
    }
    
    private func createTimeRange() -> (earliest: String?, latest: String?)? {
        if earliest != nil || latest != nil {
            return (earliest: earliest, latest: latest)
        }
        return nil
    }
}

// MARK: - Token Value Parsing

struct TokenValue {
    let name: String
    let value: String
}

func parseTokenValue(_ string: String) throws -> TokenValue {
    let components = string.components(separatedBy: "=")
    guard components.count == 2 else {
        throw ValidationError("Token value must be in 'name=value' format")
    }
    
    return TokenValue(
        name: components[0].trimmingCharacters(in: .whitespaces),
        value: components[1].trimmingCharacters(in: .whitespaces)
    )
}

struct SearchValidationWrapper {
    let searchInfo: SearchInfo
    let result: SearchValidationResult
}

struct TestNetworkCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "test-network",
        abstract: "Test network connectivity to Splunk server"
    )
    
    @Flag(name: .shortAndLong, help: "Enable debug output")
    var debug = false
    
    func run() async throws {
        print("🌐 Testing network connectivity to Splunk server...")
        
        if debug {
            print("🔍 Debug mode enabled")
        }
        
        do {
            let configTemplate = try SplunkConfiguration.loadFromPlist()
            
            // Create a dummy credential for testing (we just need to test connectivity)
            let testCredentials = SplunkCredentials.basic(username: "admin", password: "helloworld")
            let configuration = configTemplate.withCredentials(testCredentials)
            
            // Enable debug if requested
            if debug {
                print("📋 Target URL: \(configuration.baseURL)")
                print("📋 Timeout: \(configuration.timeout)s")
                print("📋 Allow Insecure: \(configuration.allowInsecureConnections)")
                print("📋 Validate SSL: \(configuration.validateSSLCertificate)")
            }
            
            let restClient = SplunkRestClient(configuration: configuration)
            
            if debug {
                print("🔗 Attempting connection to: \(configuration.baseURL)")
            }
            
            // Test basic connectivity (without authentication)
            try await restClient.testConnectivity()
            
            print("✅ Network connectivity test successful!")
            print("🔗 Successfully connected to: \(configuration.baseURL)")
            
        } catch {
            print("❌ Network connectivity test failed!")
            print("📋 Error: \(error.localizedDescription)")
            
            if debug {
                print("🔍 Debug details:")
                if let nsError = error as NSError? {
                    print("   Domain: \(nsError.domain)")
                    print("   Code: \(nsError.code)")
                    print("   UserInfo: \(nsError.userInfo)")
                }
            }
            
            print("\n💡 Troubleshooting tips:")
            print("   1. Check your network connection")
            print("   2. Verify the baseURL in your SplunkConfiguration.plist")
            print("   3. If using HTTPS, check SSL certificate issues")
            print("   4. Try using 'config set-ssl --allow-insecure' for testing")
            print("   5. Check if firewall is blocking the connection")
            
            throw ExitCode.failure
        }
    }
}

struct ConfigCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "Manage Splunk configuration",
        subcommands: [
            ShowConfigCommand.self,
            SetBaseURLCommand.self,
            SetCredentialsCommand.self,
            SetAppCommand.self,
            SetTimeoutCommand.self,
            SetSSLCommand.self,
            ValidateConfigCommand.self,
            ListCredentialsCommand.self,
            ClearCredentialsCommand.self
        ]
    )
    
    func run() throws {
        print("🔧 Manage Splunk configuration and credentials")
        print("\nConfiguration commands:")
        print("  show          - Show current configuration")
        print("  set-url       - Set Splunk base URL")
        print("  set-creds     - Set and store credentials interactively")
        print("  set-app       - Set default app")
        print("  set-timeout   - Set connection timeout")
        print("  set-ssl       - Configure SSL settings")
        print("  validate      - Validate configuration file")
        print("\nCredential commands:")
        print("  credentials   - List stored credentials")
        print("  clear-creds   - Clear stored credentials")
        print("\nUse 'splunk-dashboard splunk config <subcommand> --help' for more information")
    }
}

struct SetBaseURLCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "set-url",
        abstract: "Set Splunk base URL"
    )
    
    @Argument(help: "Splunk base URL (e.g., https://splunk.example.com:8089)")
    var baseURL: String
    
    func run() throws {
        // Note: In a real implementation, you'd modify the configuration file or create a user config overlay
        // For now, we'll show what would be set and inform the user to update the plist manually
        
        guard let url = URL(string: baseURL) else {
            print("❌ Invalid URL format: \(baseURL)")
            throw ExitCode.failure
        }
        
        print("🌐 Base URL would be set to: \(url)")
        print("📝 Note: Currently you need to manually update SplunkConfiguration.plist")
        print("   Set the 'baseURL' key to: \(baseURL)")
    }
}

struct SetCredentialsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "set-creds",
        abstract: "Set and store credentials interactively"
    )
    
    @Option(name: .shortAndLong, help: "Splunk base URL (overrides configuration)")
    var baseURL: String?
    
    @Flag(name: .shortAndLong, help: "Force overwrite existing credentials")
    var force = false
    
    func run() async throws {
        print("🔐 Setting up Splunk credentials...")
        
        // Load configuration to get baseURL if not provided
        let configTemplate = try SplunkConfiguration.loadFromPlist()
        let serverURL: URL
        
        if let urlString = baseURL, let url = URL(string: urlString) {
            serverURL = url
        } else {
            serverURL = configTemplate.baseURL
        }
        
        let serverHost = serverURL.host ?? serverURL.absoluteString
        let credentialManager = SplunkCredentialManager()
        
        // Check if credentials already exist
        if !force {
            let existingCredentials = try? credentialManager.listStoredCredentials()
            let hasExisting = existingCredentials?.contains { $0.server == serverHost } ?? false
            
            if hasExisting {
                print("⚠️ Credentials already exist for server: \(serverHost)")
                print("Use --force to overwrite, or use 'clear-creds' first")
                return
            }
        }
        
        // Get credentials interactively
        let credentials = try getCredentialsInteractively()
        
        // Test credentials by creating services and verifying
        let configuration = configTemplate.withCredentials(credentials)
        let restClient = SplunkRestClient(configuration: configuration)
        let authService = SplunkAuthenticationService(restClient: restClient)
        
        // Verify credentials
        let isValid = try await authService.verifyCredentials()
        
        if isValid {
            print("✅ Credentials verified successfully!")
            
            // Store credentials securely for future use
            try storeCredentials(credentials, serverHost: serverHost, credentialManager: credentialManager)
            
            let user = try await authService.getCurrentUser()
            print("👤 User: \(user.username)")
            print("🏷️  Roles: \(user.roles.joined(separator: ", "))")
        } else {
            print("❌ Credential verification failed - please check your credentials")
            throw ExitCode.failure
        }
    }
    
    private func storeCredentials(_ credentials: SplunkCredentials, serverHost: String, credentialManager: SplunkCredentialManager) throws {
        switch credentials {
        case .token(let token):
            try credentialManager.storeToken(server: serverHost, token: token)
            print("🔐 API token stored securely in keychain")
            
        case .basic(let username, let password):
            try credentialManager.storeCredentials(server: serverHost, username: username, password: password)
            print("🔐 Username/password stored securely in keychain")
            
        case .sessionKey(_):
            // Session keys are temporary, don't store them
            print("ℹ️  Session key is temporary and will not be stored")
        }
    }
    
    private func getCredentialsInteractively() throws -> SplunkCredentials {
        print("Choose authentication method:")
        print("1. Username/Password")
        print("2. API Token")
        print("Enter choice (1 or 2): ", terminator: "")
        
        let choice = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "1"
        
        switch choice {
        case "1":
            print("Enter username: ", terminator: "")
            let username = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let password = getPasswordFromUser()
            return .basic(username: username, password: password)
            
        case "2":
            print("Enter API token: ", terminator: "")
            let token = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return .token(token)
            
        default:
            throw SplunkError.authenticationFailed("Invalid choice")
        }
    }
    
    private func getPasswordFromUser() -> String {
        print("Enter password: ", terminator: "")
        // Note: In a real implementation, you'd want to use secure input
        return readLine(strippingNewline: true) ?? ""
    }
}

struct SetAppCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "set-app",
        abstract: "Set default Splunk app"
    )
    
    @Argument(help: "Default app name")
    var appName: String
    
    func run() throws {
        print("📱 Default app would be set to: \(appName)")
        print("📝 Note: Currently you need to manually update SplunkConfiguration.plist")
        print("   Set the 'defaultApp' key to: \(appName)")
    }
}

struct SetTimeoutCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "set-timeout",
        abstract: "Set connection timeout"
    )
    
    @Argument(help: "Timeout in seconds")
    var timeout: Double
    
    func run() throws {
        guard timeout > 0 else {
            print("❌ Timeout must be greater than 0")
            throw ExitCode.failure
        }
        
        print("⏱️ Timeout would be set to: \(timeout) seconds")
        print("📝 Note: Currently you need to manually update SplunkConfiguration.plist")
        print("   Set the 'timeout' key to: \(timeout)")
    }
}

struct SetSSLCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "set-ssl",
        abstract: "Configure SSL settings"
    )
    
    @Flag(name: .long, help: "Allow insecure connections")
    var allowInsecure = false
    
    @Flag(name: .long, help: "Skip SSL certificate validation")
    var skipValidation = false
    
    func run() throws {
        print("🛡️ SSL Settings:")
        print("   Allow Insecure Connections: \(allowInsecure)")
        print("   Validate SSL Certificates: \(!skipValidation)")
        print()
        print("📝 Note: Currently you need to manually update SplunkConfiguration.plist")
        print("   Set 'allowInsecureConnections' to: \(allowInsecure)")
        print("   Set 'validateSSLCertificate' to: \(!skipValidation)")
    }
}

struct ShowConfigCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "show",
        abstract: "Show current configuration"
    )
    
    func run() throws {
        showConfiguration()
    }
    
    private func showConfiguration() {
        do {
            let configTemplate = try SplunkConfiguration.loadFromPlist()
            
            print("📝 Current Splunk Configuration:")

            print("🌐 Base URL: \(configTemplate.baseURL)")
            print("📱 Default App: \(configTemplate.defaultApp)")
            print("👤 Default Owner: \(configTemplate.defaultOwner)")
            print("⏱️ Timeout: \(configTemplate.timeout)s")
            print("🔄 Max Retries: \(configTemplate.maxRetries)")
            print("🛡️ SSL Validation: \(configTemplate.validateSSLCertificate ? "Enabled" : "Disabled")")
            print("🔒 Insecure Connections: \(configTemplate.allowInsecureConnections ? "Allowed" : "Blocked")")
            
            print("\n📊 Dashboard Sync Settings:")
            print("   Batch Size: \(configTemplate.dashboardSyncSettings.batchSize)")
            print("   Max Dashboards: \(configTemplate.dashboardSyncSettings.maxDashboards)")
            print("   Include Private: \(configTemplate.dashboardSyncSettings.includePrivate)")
            print("   Default Apps: \(configTemplate.dashboardSyncSettings.defaultAppsToSync.joined(separator: ", "))")
            
        } catch {
            print("❌ Failed to load configuration: \(error.localizedDescription)")
        }
    }
}

struct ValidateConfigCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "validate",
        abstract: "Validate configuration file"
    )
    
    func run() throws {
        validateConfiguration()
    }
    
    private func validateConfiguration() {
        do {
            let _ = try SplunkConfiguration.loadFromPlist()
            print("✅ Configuration file is valid")
        } catch {
            print("❌ Configuration validation failed: \(error.localizedDescription)")
        }
    }
}

struct ListCredentialsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "credentials",
        abstract: "List stored credentials"
    )
    
    func run() throws {
        let credentialManager = SplunkCredentialManager()
        
        do {
            let storedCredentials = try credentialManager.listStoredCredentials()
            
            if storedCredentials.isEmpty {
                print("📝 No stored credentials found")
                print("\nUse 'splunk-dashboard splunk login' to store credentials")
                return
            }
            
            print("🔐 Stored Credentials:")
            print("")
            
            for credential in storedCredentials {
                print("• \(credential.displayString)")
            }
            
        } catch {
            print("❌ Failed to list stored credentials: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}

struct ClearCredentialsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clear-creds",
        abstract: "Clear stored credentials"
    )
    
    @Flag(name: .shortAndLong, help: "Force clear without confirmation")
    var force = false
    
    func run() throws {
        if !force {
            print("⚠️ This will delete all stored Splunk credentials.")
            print("Are you sure? (y/N): ", terminator: "")
            
            let input = readLine()?.lowercased()
            guard input == "y" || input == "yes" else {
                print("❌ Clear operation cancelled")
                return
            }
        }
        
        let credentialManager = SplunkCredentialManager()
        
        do {
            let storedCredentials = try credentialManager.listStoredCredentials()
            
            for credential in storedCredentials {
                if credential.isToken {
                    try credentialManager.deleteToken(server: credential.server)
                } else {
                    try credentialManager.deleteCredentials(server: credential.server, username: credential.account)
                }
            }
            
            print("✅ All stored credentials have been cleared")
            
        } catch {
            print("❌ Failed to clear credentials: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}

// MARK: - Shared Authentication Helper

/// Helper to get credentials from various sources with fallback priority
struct AuthenticationHelper {
    static func getCredentials(
        username: String? = nil,
        password: String? = nil,
        token: String? = nil,
        serverHost: String
    ) throws -> SplunkCredentials {
        let credentialManager = SplunkCredentialManager()
        
        // Priority 1: Command line arguments
        if let token = token {
            return .token(token)
        }
        
        if let username = username, let password = password {
            return .basic(username: username, password: password)
        }
        
        // Priority 2: Stored credentials
        // First try to get a stored token
        if let storedToken = try? credentialManager.retrieveToken(server: serverHost) {
            return .token(storedToken)
        }
        
        // Then try to find any stored username/password credentials
        let storedCredentials = try? credentialManager.listStoredCredentials()
        let matchingCredentials = storedCredentials?.filter { !$0.isToken && $0.server == serverHost }
        
        if let firstCredential = matchingCredentials?.first {
            let username = firstCredential.account
            let password = try credentialManager.retrieveCredentials(server: serverHost, username: username)
            return .basic(username: username, password: password)
        }
        
        // Priority 3: Interactive input
        throw SplunkError.authenticationFailed("""
        No stored credentials found and no command line credentials provided.
        
        Please either:
        1. Run 'splunk-dashboard splunk login' to store credentials securely, or
        2. Provide credentials via command line: --username <user> --password <pass> or --token <token>
        
        Use 'splunk-dashboard splunk config credentials' to see what's currently stored.
        """)
    }
    
    static func createConfigurationWithStoredCredentials() throws -> SplunkConfiguration {
        let configTemplate = try SplunkConfiguration.loadFromPlist()
        let serverHost = configTemplate.baseURL.host ?? configTemplate.baseURL.absoluteString
        
        let credentials = try getCredentials(serverHost: serverHost)
        return configTemplate.withCredentials(credentials)
    }
}

// MARK: - Core Data Loader Adapter

/// Adapter to make existing DashboardLoader conform to DashboardLoaderProtocol
class CoreDataLoaderAdapter: DashboardLoaderProtocol {
    public let loader: DashboardLoader
    
    init() async {
        self.loader = await DashboardLoader()
    }
    
    func loadDashboard(from path: String, dashboardId: String, appName: String? = nil) async throws {
        try await loader.loadDashboard(from: path, dashboardId: dashboardId, appName: appName)
    }
}

// MARK: - Load Command

struct LoadCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "load",
        abstract: "Load SimpleXML dashboard file(s) into Core Data"
    )
    
    @Argument(help: "Path to SimpleXML dashboard file or directory")
    var path: String
    
    @Option(name: .shortAndLong, help: "Dashboard ID (defaults to filename)")
    var id: String?
    
    @Option(name: .shortAndLong, help: "App name for this dashboard")
    var app: String?
    
    @Flag(name: .shortAndLong, help: "Recursively load all .xml files in directory")
    var recursive = false
    
    @Flag(name: .shortAndLong, help: "Verbose output")
    var verbose = false
    
    func run() async throws {
        let loader = await DashboardLoader()
        let fileManager = FileManager.default
        
        print("🚀 Starting dashboard load process...")
        
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            throw LoadError.pathNotFound(path: path)
        }
        
        if isDirectory.boolValue {
            try await loadFromDirectory(at: path, recursive: recursive, appName: app, loader: loader)
        } else {
            try await loadSingleFile(at: path, withId: id, appName: app, loader: loader)
        }
        
        print("✅ Load process completed")
    }

    
    private func loadFromDirectory(at directoryPath: String, recursive: Bool, appName: String?, loader: DashboardLoader) async throws {
        let fileManager = FileManager.default
        
        let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .nameKey]
        let directoryURL = URL(fileURLWithPath: directoryPath)
        
        let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: resourceKeys,
            options: recursive ? [] : [.skipsSubdirectoryDescendants]
        )
        
        guard let enumerator = enumerator else {
            throw LoadError.directoryEnumerationFailed(path: directoryPath)
        }
        
        var loadedCount = 0
        
        // Convert enumerator to array to avoid async iterator issues
        let allURLs = enumerator.allObjects.compactMap { $0 as? URL }
        
        for fileURL in allURLs {
            let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
            
            guard resourceValues.isRegularFile == true else { continue }
            guard fileURL.pathExtension.lowercased() == "xml" else { continue }
            
            let dashboardId = fileURL.deletingPathExtension().lastPathComponent
            
            do {
                if verbose {
                    print("📁 Loading: \(fileURL.lastPathComponent)")
                }
                try await MainActor.run {
                    try loader.loadDashboard(from: fileURL.path, dashboardId: dashboardId, appName: app)
                }
                loadedCount += 1
            } catch {
                print("⚠️ Failed to load \(fileURL.lastPathComponent): \(error.localizedDescription)")
                if verbose {
                    print("   Error details: \(error)")
                }
            }
        }
        print("📊 Loaded \(loadedCount) dashboard(s) from directory")
    }
    
    private func loadSingleFile(at filePath: String, withId dashboardId: String?, appName: String?, loader: DashboardLoader) async throws {
        let finalId = dashboardId ?? URL(fileURLWithPath: filePath).deletingPathExtension().lastPathComponent
        
        do {
            try await MainActor.run {
                try loader.loadDashboard(from: filePath, dashboardId: finalId, appName: appName)
            }
        } catch {
            throw LoadError.loadFailed(path: filePath, error: error)
        }
    }

}
// MARK: - Query Command

struct QueryCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "query",
        abstract: "Query dashboard data from Core Data",
        subcommands: [
            ListDashboardsCommand.self,
            ShowDashboardCommand.self,
            DebugDashboardCommand.self,
            ExportJSONCommand.self,
            ListTokensCommand.self,
            FindTokensCommand.self,
            ShowTokenCommand.self,
            ListSearchesCommand.self,
            FindSearchesCommand.self,
            StatsCommand.self,
            ListRefreshCommand.self
        ]
    )
    
    func run() throws {
        // Default behavior when no subcommand is provided
        print("🔍 Query dashboard data from Core Data")
        print("\nAvailable subcommands:")
        print("  list           - List all loaded dashboards")
        print("  show           - Show detailed dashboard information")
        print("  debug          - Show complete debug information for a dashboard")
        print("  export-json    - Export complete dashboard as JSON")
        print("  tokens         - List all tokens")
        print("  find-tokens    - Find tokens matching a pattern")
        print("  token          - Show detailed token information")
        print("  searches       - List all searches")
        print("  find-searches  - Find searches using a specific token")
        print("  stats          - Show dashboard statistics")
        print("  list-refresh   - List searches with refresh intervals")
        print("\nUse 'splunk-dashboard query <subcommand> --help' for more information")
    }
}


// MARK: - Query Subcommands

struct ListDashboardsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all loaded dashboards"
    )
    
    @Option(name: .shortAndLong, help: "Filter by specific app name")
    var app: String?
    
    func run() async {
        let queryEngine = await DashboardQueryEngine()
        await queryEngine.listDashboards(appName: app)
    }
}

struct ShowDashboardCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "show",
        abstract: "Show detailed information about a dashboard"
    )
    
    @Argument(help: "Dashboard ID")
    var dashboardId: String
    
    func run() async {
        let queryEngine = await DashboardQueryEngine()
        await queryEngine.showDashboard(dashboardId)
    }
}

struct DebugDashboardCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "debug",
        abstract: "Show complete debug information for a dashboard"
    )
    
    @Argument(help: "Dashboard ID")
    var dashboardId: String
    
    func run() async {
        let loader = await DashboardLoader()
        await loader.debugDashboard(dashboardId)
    }
}

struct ExportJSONCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "export-json",
        abstract: "Export complete dashboard CoreData object graph as JSON"
    )
    
    @Argument(help: "Dashboard ID")
    var dashboardId: String
    
    func run() async {
        let loader = await DashboardLoader()
        await loader.exportDashboardAsJSON(dashboardId)
    }
}

struct ListTokensCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tokens",
        abstract: "List all tokens"
    )
    
    @Option(name: .shortAndLong, help: "Filter by specific app name")
    var app: String?
    
    func run() async {
        let queryEngine = await DashboardQueryEngine()
        await queryEngine.listAllTokens(inApp: app)
    }
}

struct FindTokensCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "find-tokens",
        abstract: "Find tokens matching a pattern"
    )
    
    @Argument(help: "Search pattern")
    var pattern: String
    
    @Option(name: .shortAndLong, help: "Filter by specific app name")
    var app: String?
    
    func run() async {
        let queryEngine = await DashboardQueryEngine()
        await queryEngine.findTokens(matching: pattern, inApp: app)
    }
}

struct ShowTokenCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "token",
        abstract: "Show detailed token information"
    )
    
    @Argument(help: "Token name")
    var tokenName: String
    
    @Option(name: .shortAndLong, help: "Dashboard ID to limit search")
    var dashboard: String?
    
    func run() async {
        let queryEngine = await DashboardQueryEngine()
        await queryEngine.showToken(tokenName, in: dashboard)
    }
}

struct ListSearchesCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "searches",
        abstract: "List all searches"
    )
    
    @Option(name: .shortAndLong, help: "Dashboard ID to limit search")
    var dashboard: String?
    
    func run() async {
        let queryEngine = await DashboardQueryEngine()
        await queryEngine.listSearches(in: dashboard)
    }
}

struct FindSearchesCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "find-searches",
        abstract: "Find searches using a specific token"
    )
    
    @Argument(help: "Token name")
    var token: String
    
    func run() async {
        let queryEngine = await DashboardQueryEngine()
        await queryEngine.findSearchesUsing(token: token)
    }
}

struct StatsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "stats",
        abstract: "Show dashboard statistics"
    )
    
    func run() async {
        let queryEngine = await DashboardQueryEngine()
        await queryEngine.showStatistics()
    }
}

struct ListRefreshCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list-refresh",
        abstract: "List searches with refresh intervals"
    )
    
    @Option(name: .shortAndLong, help: "Dashboard ID to limit search")
    var dashboard: String?
    
    func run() async {
        print("🔄 Listing searches with refresh intervals...\n")
        
        if let dashboardId = dashboard {
            // List refresh for specific dashboard
            await listRefreshForDashboard(dashboardId)
        } else {
            // List refresh for all dashboards
            await listRefreshForAllDashboards()
        }
    }
    
    private func listRefreshForDashboard(_ dashboardId: String) async {
        let searchesWithRefresh = await MainActor.run {
            CoreDataManager.shared.getSearchesWithRefresh(in: dashboardId)
        }
        
        if searchesWithRefresh.isEmpty {
            print("No searches with refresh intervals found in dashboard: \(dashboardId)")
            return
        }
        
        print("Dashboard: \(dashboardId)")
        print("Found \(searchesWithRefresh.count) search(es) with refresh intervals:\n")
        
        for (searchId, interval) in searchesWithRefresh.sorted(by: { $0.refreshInterval < $1.refreshInterval }) {
            print("  🔍 \(searchId)")
            print("     Refresh: every \(formatInterval(interval))")
            print()
        }
    }
    
    private func listRefreshForAllDashboards() async {
        let dashboards = await MainActor.run {
            CoreDataManager.shared.fetchAllDashboards()
        }
        
        var totalSearches = 0
        
        for dashboard in dashboards {
            let searchesWithRefresh = await MainActor.run {
                CoreDataManager.shared.getSearchesWithRefresh(in: dashboard.id)
            }
            
            if !searchesWithRefresh.isEmpty {
                print("📊 Dashboard: \(dashboard.id)")
                if let title = dashboard.title {
                    print("   Title: \(title)")
                }
                print("   Searches with refresh: \(searchesWithRefresh.count)")
                
                for (searchId, interval) in searchesWithRefresh {
                    print("     • \(searchId) - every \(formatInterval(interval))")
                }
                print()
                
                totalSearches += searchesWithRefresh.count
            }
        }
        
        if totalSearches == 0 {
            print("No searches with refresh intervals found in any dashboard.")
        } else {
            print("📈 Total: \(totalSearches) search(es) with refresh intervals across \(dashboards.count) dashboard(s)")
        }
    }
    
    private func formatInterval(_ interval: TimeInterval) -> String {
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

// MARK: - Clear Command

struct ClearCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clear",
        abstract: "Clear all data from Core Data"
    )
    
    @Flag(name: .shortAndLong, help: "Force clear without confirmation")
    var force = false
    
    func run() async throws {
        if !force {
            print("⚠️ This will delete all dashboard data from Core Data.")
            print("Are you sure? (y/N): ", terminator: "")
            
            let input = readLine()?.lowercased()
            guard input == "y" || input == "yes" else {
                print("❌ Clear operation cancelled")
                return
            }
        }
        
        do {
            try await MainActor.run {
                try CoreDataManager.shared.clearAllData()
            }
            print("✅ All dashboard data has been cleared from Core Data")
        } catch {
            throw ClearError.clearFailed(error: error)
        }
    }
}

// MARK: - Error Types

enum LoadError: Error, LocalizedError {
    case pathNotFound(path: String)
    case directoryEnumerationFailed(path: String)
    case loadFailed(path: String, error: Error)

    var errorDescription: String? {
        switch self {
        case .pathNotFound(let path):
            return "Path not found: \(path)"
        case .directoryEnumerationFailed(let path):
            return "Failed to enumerate directory: \(path)"
        case .loadFailed(let path, let error):
            return "Failed to load \(path): \(error.localizedDescription)"
        }
    }
}

enum ClearError: Error, LocalizedError {
    case clearFailed(error: Error)

    var errorDescription: String? {
        switch self {
        case .clearFailed(let error):
            return "Failed to clear data: \(error.localizedDescription)"
        }
    }
}

// MARK: - Main Entry Point

func main() async {
   await SplunkDashboardCLI.main()
}
await main()
