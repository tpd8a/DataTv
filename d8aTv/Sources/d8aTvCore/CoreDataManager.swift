import Foundation
import CoreData

// MARK: - Notification Extensions

public extension Notification.Name {
    static let searchExecutionStarted = Notification.Name("searchExecutionStarted")
    static let searchExecutionProgressUpdated = Notification.Name("searchExecutionProgressUpdated")
    static let searchExecutionCompleted = Notification.Name("searchExecutionCompleted")
    static let searchExecutionCancelled = Notification.Name("searchExecutionCancelled")
    static let searchJobCreated = Notification.Name("searchJobCreated")
}

/// Core Data manager for Splunk dashboard persistence
@MainActor
public class CoreDataManager {
    
    // MARK: - Singleton
    public static var shared = CoreDataManager()
    
    public init() {}
    
    // MARK: - Core Data Stack
    
    public lazy var persistentContainer: NSPersistentContainer = {
        // Try to load from .xcdatamodeld file first
        let container = NSPersistentContainer(name: "tmpDashboardModel")
        
        // If model file doesn't exist, use programmatic model
        if container.managedObjectModel.entities.isEmpty {
            print("⚠️ .xcdatamodeld file not found, using programmatic Core Data model")
            let programmaticModel = CoreDataModelConfiguration.createModel()
            let programmaticContainer = NSPersistentContainer(name: "tmpDashboardModel", managedObjectModel: programmaticModel)
            
            programmaticContainer.loadPersistentStores { storeDescription, error in
                if let error = error as NSError? {
                    fatalError("Unresolved error \(error), \(error.userInfo)")
                }
            }
            return programmaticContainer
        }
        
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        return container
    }()
    
    public var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    /// Creates a new background context for performing Core Data operations off the main thread
    public func newBackgroundContext() -> NSManagedObjectContext {
        return persistentContainer.newBackgroundContext()
    }
    
    // MARK: - Core Data Operations
    
    public func saveContext() {
        let context = persistentContainer.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
                print("✅ Core Data context saved successfully")
            } catch {
                let nsError = error as NSError
                print("❌ Failed to save Core Data context: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    public func clearAllData() throws {
        let entityNames = [
            "DashboardEntity",
            "RowEntity", 
            "PanelEntity",
            "FieldsetEntity",
            "TokenEntity",
            "TokenChoiceEntity",
            "TokenConditionEntity", 
            "TokenActionEntity",
            "SearchEntity",
            "VisualizationEntity",
            "GlobalTokenOpEntity",
            "CustomContentEntity",
            "NamespaceEntity",
            "SearchExecutionEntity",
            "SearchResultEntity"
        ]
        
        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try context.execute(deleteRequest)
            } catch {
                throw CoreDataError.deleteFailed(entityName: entityName, error: error)
            }
        }
        
        saveContext()
        print("✅ All Core Data cleared")
    }
    
    // MARK: - Dashboard Operations
    
    public func findDashboard(by id: String) -> DashboardEntity? {
        let request: NSFetchRequest<DashboardEntity> = DashboardEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        
        do {
            if let dashboard = try context.fetch(request).first {
                return dashboard
            }
        } catch {
            print("❌ Error fetching dashboard by ID: \(error)")
        }
        
        // If not found by ID, try to find by dashboard name
        return findDashboard(byName: id)
    }
    
    public func findDashboard(byAppAndName appName: String, dashboardName: String) -> DashboardEntity? {
        let request: NSFetchRequest<DashboardEntity> = DashboardEntity.fetchRequest()
        request.predicate = NSPredicate(format: "appName == %@ AND dashboardName == %@", appName, dashboardName)
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            print("❌ Error fetching dashboard: \(error)")
            return nil
        }
    }
    
    public func findDashboard(byName dashboardName: String) -> DashboardEntity? {
        // First try to find by dashboardName field
        let request: NSFetchRequest<DashboardEntity> = DashboardEntity.fetchRequest()
        request.predicate = NSPredicate(format: "dashboardName == %@", dashboardName)
        request.fetchLimit = 1
        
        do {
            if let dashboard = try context.fetch(request).first {
                return dashboard
            }
        } catch {
            print("❌ Error fetching dashboard by dashboardName: \(error)")
        }
        
        // If not found, try to find by ID suffix (for composite IDs like "app§dashboard")
        let allRequest: NSFetchRequest<DashboardEntity> = DashboardEntity.fetchRequest()
        do {
            let allDashboards = try context.fetch(allRequest)
            for dashboard in allDashboards {
                // Extract dashboard name from composite ID
                let parts = dashboard.id.components(separatedBy: "§")
                let extractedDashboard = parts.count == 2 ? parts[1] : dashboard.id
                if extractedDashboard == dashboardName {
                    return dashboard
                }
            }
        } catch {
            print("❌ Error fetching all dashboards: \(error)")
        }
        
        return nil
    }
    
    public func dashboardsInApp(_ appName: String) -> [DashboardEntity] {
        let request: NSFetchRequest<DashboardEntity> = DashboardEntity.fetchRequest()
        request.predicate = NSPredicate(format: "appName == %@", appName)
        request.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("❌ Error fetching dashboards for app \(appName): \(error)")
            return []
        }
    }
    
    public func allDashboards() -> [DashboardEntity] {
        let request: NSFetchRequest<DashboardEntity> = DashboardEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("❌ Error fetching dashboards: \(error)")
            return []
        }
    }
    
    // MARK: - Convenience Aliases
    
    /// Convenience alias for findDashboard(by:)
    public func getDashboard(id: String) -> DashboardEntity? {
        return findDashboard(by: id)
    }
    
    /// Convenience alias for allDashboards()
    public func fetchAllDashboards() -> [DashboardEntity] {
        return allDashboards()
    }
    
    // MARK: - Dashboard Deletion
    
    public func deleteDashboard(id: String) throws {
        guard let dashboard = findDashboard(by: id) else {
            throw CoreDataError.dashboardNotFound(id: id)
        }
        
        context.delete(dashboard)
        saveContext()
        print("✅ Dashboard '\(id)' deleted")
    }
    
    // MARK: - Search Discovery & Execution
    
    /// Find all searches in a dashboard by type and location
    public func findSearches(in dashboardId: String) -> SearchDiscoveryResult {
        guard let dashboard = findDashboard(by: dashboardId) else {
            return SearchDiscoveryResult(
                dashboardId: dashboardId,
                panelSearches: [],
                visualizationSearches: [],
                globalSearches: [],
                error: .dashboardNotFound(id: dashboardId)
            )
        }
        
        var panelSearches: [SearchInfo] = []
        var visualizationSearches: [SearchInfo] = []
        var globalSearches: [SearchInfo] = []
        var seenSearchIds = Set<String>()
        
        // Collect visualization searches first (they are more specific)
        // This prioritizes visualization context over panel context for searches that appear in both
        for row in dashboard.rowsArray {
            for panel in row.panelsArray {
                for viz in panel.visualizationsArray {
                    if let search = viz.search {
                        // Only add if we haven't seen this search ID before
                        if !seenSearchIds.contains(search.id) {
                            let searchInfo = SearchInfo(
                                id: search.id,
                                query: search.query,
                                searchType: .visualization,
                                location: SearchLocation.visualization(vizId: viz.id, panelId: panel.id, rowId: row.id),
                                searchEntity: search
                            )
                            visualizationSearches.append(searchInfo)
                            seenSearchIds.insert(search.id)
                        }
                    }
                }
            }
        }
        
        // Collect panel searches (skip if already collected as visualization search)
        for row in dashboard.rowsArray {
            for panel in row.panelsArray {
                for search in panel.searchesArray {
                    // Only add if we haven't seen this search ID before
                    if !seenSearchIds.contains(search.id) {
                        let searchInfo = SearchInfo(
                            id: search.id,
                            query: search.query,
                            searchType: .panel,
                            location: SearchLocation.panel(panelId: panel.id, rowId: row.id),
                            searchEntity: search
                        )
                        panelSearches.append(searchInfo)
                        seenSearchIds.insert(search.id)
                    }
                }
            }
        }
        
        // Collect global searches
        for search in dashboard.globalSearchesArray {
            // Only add if we haven't seen this search ID before
            if !seenSearchIds.contains(search.id) {
                let searchInfo = SearchInfo(
                    id: search.id,
                    query: search.query,
                    searchType: .global,
                    location: SearchLocation.global,
                    searchEntity: search
                )
                globalSearches.append(searchInfo)
                seenSearchIds.insert(search.id)
            }
        }
        
        return SearchDiscoveryResult(
            dashboardId: dashboardId,
            panelSearches: panelSearches,
            visualizationSearches: visualizationSearches,
            globalSearches: globalSearches,
            error: nil
        )
    }
    
    /// Find a specific search by ID across all locations in a dashboard
    public func findSearch(searchId: String, in dashboardId: String) -> SearchInfo? {
        let discovery = findSearches(in: dashboardId)
        
        // Search in all collections
        let allSearches = discovery.panelSearches + discovery.visualizationSearches + discovery.globalSearches
        return allSearches.first { $0.id == searchId }
    }
    
    /// Validate a search and check its dependencies
    public func validateSearch(_ searchInfo: SearchInfo, in dashboardId: String) -> SearchValidationResult {
        guard let dashboard = findDashboard(by: dashboardId) else {
            return SearchValidationResult(
                searchInfo: searchInfo,
                isValid: false,
                issues: [.dashboardNotFound],
                tokenReferences: [],
                timeRange: nil
            )
        }
        
        var issues: [SearchValidationIssue] = []
        var tokenReferences: [String] = []
        var timeRange: SearchTimeRange? = nil
        
        // Check if search has a query
        guard let query = searchInfo.query, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            issues.append(.emptyQuery)
            return SearchValidationResult(
                searchInfo: searchInfo,
                isValid: false,
                issues: issues,
                tokenReferences: tokenReferences,
                timeRange: timeRange
            )
        }
        
        // Extract token references from query
        let extractedTokens = TokenValidator.extractTokenReferences(from: query)
        tokenReferences = Array(extractedTokens)
        
        // Validate tokens exist in dashboard
        let allTokens = dashboard.allTokens
        let availableTokenNames = Set(allTokens.map { $0.name })
        
        for tokenRef in tokenReferences {
            if !availableTokenNames.contains(tokenRef) {
                issues.append(.undefinedToken(tokenRef))
            }
        }
        
        // Extract time range from search entity
        if let search = searchInfo.searchEntity {
            let earliest = search.earliestTime
            let latest = search.latestTime
            if earliest != nil || latest != nil {
                timeRange = SearchTimeRange(earliest: earliest, latest: latest)
            }
        }
        
        // Check for search references (both 'base' and 'ref' attributes)
        if let search = searchInfo.searchEntity {
            let baseRef = search.base ?? search.ref
            if let ref = baseRef, !ref.isEmpty {
                // This search references another search - validate the reference exists
                let referencedSearch = findSearch(searchId: ref, in: dashboardId)
                if referencedSearch == nil {
                    issues.append(.invalidSearchReference(ref))
                }
            }
        }
        
        return SearchValidationResult(
            searchInfo: searchInfo,
            isValid: issues.isEmpty,
            issues: issues,
            tokenReferences: tokenReferences,
            timeRange: timeRange
        )
    }
    
    /// Get all available token definitions for a dashboard
    public func getTokenDefinitions(for dashboardId: String) -> [SearchTokenDefinition] {
        guard let dashboard = findDashboard(by: dashboardId) else {
            return []
        }
        
        return dashboard.allTokens.map { token in
            SearchTokenDefinition(
                name: token.name,
                type: token.type,
                label: token.label,
                defaultValue: token.defaultValue,
                required: token.required,
                choices: token.choicesArray.map { choice in
                    SearchTokenChoice(value: choice.value, label: choice.label, isDefault: choice.isDefault)
                }
            )
        }
    }
    
    // MARK: - Token Resolution
    
    /// Resolve token values for a search using provided values and defaults
    public func resolveTokens(
        for searchInfo: SearchInfo, 
        in dashboardId: String,
        userProvidedValues: [String: String] = [:],
        timeRange: (earliest: String?, latest: String?)? = nil
    ) -> TokenResolutionResult {
        
        let validation = validateSearch(searchInfo, in: dashboardId)
        guard validation.isValid else {
            return TokenResolutionResult(
                searchInfo: searchInfo,
                resolvedValues: [:],
                unresolvedTokens: validation.tokenReferences,
                resolvedQuery: nil,
                issues: validation.issues.map { TokenResolutionIssue.validationError($0.description) }
            )
        }
        
        let tokenDefinitions = getTokenDefinitions(for: dashboardId)
        let tokenMap = Dictionary(uniqueKeysWithValues: tokenDefinitions.map { ($0.name, $0) })
        
        var resolvedValues: [String: String] = [:]
        var unresolvedTokens: [String] = []
        var issues: [TokenResolutionIssue] = []
        
        // Resolve each token reference
        for tokenName in validation.tokenReferences {
            if let resolvedValue = resolveIndividualToken(
                name: tokenName,
                definition: tokenMap[tokenName],
                userProvidedValues: userProvidedValues,
                timeRange: timeRange
            ) {
                resolvedValues[tokenName] = resolvedValue.value
                if let issue = resolvedValue.issue {
                    issues.append(issue)
                }
            } else {
                unresolvedTokens.append(tokenName)
                issues.append(.cannotResolveToken(tokenName))
            }
        }
        
        // Apply token substitution to query
        var resolvedQuery: String? = nil
        if let originalQuery = searchInfo.query, unresolvedTokens.isEmpty {
            resolvedQuery = substituteTokensInQuery(originalQuery, resolvedValues: resolvedValues, tokenMap: tokenMap)
        }
        
        return TokenResolutionResult(
            searchInfo: searchInfo,
            resolvedValues: resolvedValues,
            unresolvedTokens: unresolvedTokens,
            resolvedQuery: resolvedQuery,
            issues: issues
        )
    }
    
    /// Resolve an individual token value using multiple resolution strategies
    private func resolveIndividualToken(
        name: String,
        definition: SearchTokenDefinition?,
        userProvidedValues: [String: String],
        timeRange: (earliest: String?, latest: String?)?
    ) -> (value: String, issue: TokenResolutionIssue?)? {
        
        // Strategy 1: User-provided values
        if let userValue = userProvidedValues[name] {
            return (userValue, nil)
        }
        
        // Strategy 2: Special time tokens
        if let timeRange = timeRange {
            if name.hasSuffix(".earliest") || name == "earliest" {
                if let earliest = timeRange.earliest {
                    return (earliest, nil)
                }
            }
            if name.hasSuffix(".latest") || name == "latest" {
                if let latest = timeRange.latest {
                    return (latest, nil)
                }
            }
        }
        
        // Strategy 3: Token definition defaults
        guard let definition = definition else {
            return nil
        }
        
        if let defaultValue = definition.defaultValue {
            return (defaultValue, nil)
        }
        
        // Strategy 4: Choice defaults
        if definition.hasChoices {
            if let defaultChoice = definition.choices.first(where: { $0.isDefault }) {
                return (defaultChoice.value, .usedDefaultChoice(name))
            }
            if let firstChoice = definition.choices.first {
                return (firstChoice.value, .usedFirstChoice(name))
            }
        }
        
        // Strategy 5: Type-specific defaults
        switch definition.type.lowercased() {
        case "text", "input":
            return ("*", .usedWildcardDefault(name))
        case "time":
            return ("-24h@h", .usedTimeDefault(name, "24 hours ago"))
        case "dropdown", "multiselect":
            return ("*", .usedWildcardDefault(name))
        case "radio", "checkbox":
            return ("true", .usedBooleanDefault(name))
        default:
            return nil
        }
    }
    
    /// Substitute resolved token values into search query
    private func substituteTokensInQuery(
        _ query: String, 
        resolvedValues: [String: String],
        tokenMap: [String: SearchTokenDefinition]
    ) -> String {
        
        var substitutedQuery = query
        
        for (tokenName, tokenValue) in resolvedValues {
            // Handle both $token$ and $$token$$ patterns
            let singleDollarPattern = "$\(tokenName)$"
            let doubleDollarPattern = "$$\(tokenName)$$"
            
            substitutedQuery = substitutedQuery.replacingOccurrences(
                of: doubleDollarPattern, 
                with: tokenValue
            )
            
            substitutedQuery = substitutedQuery.replacingOccurrences(
                of: singleDollarPattern, 
                with: tokenValue
            )
        }
        
        return substitutedQuery
    }
    
    // MARK: - Search Parameters & Configuration  
    
    /// Build complete search parameters from resolved tokens and dashboard settings
    public func buildSearchParameters(
        from tokenResolution: TokenResolutionResult,
        in dashboardId: String,
        userOverrides: SearchParameterOverrides = SearchParameterOverrides()
    ) -> SearchParametersResult {
        
        guard tokenResolution.isFullyResolved, 
              let resolvedQuery = tokenResolution.resolvedQuery else {
            return SearchParametersResult(
                parameters: nil,
                issues: [.tokenResolutionIncomplete]
            )
        }
        
        guard let dashboard = findDashboard(by: dashboardId) else {
            return SearchParametersResult(
                parameters: nil,
                issues: [.dashboardNotFound]
            )
        }
        
        let searchInfo = tokenResolution.searchInfo
        var issues: [SearchParameterIssue] = []
        
        // Build base parameters
        var parameters = SearchParameters(
            query: resolvedQuery,
            searchId: searchInfo.id,
            dashboardId: dashboardId,
            location: searchInfo.location
        )
        
        // Apply settings with priority order
        applyTimeRange(to: &parameters, from: searchInfo, dashboard: dashboard, userOverrides: userOverrides)
        applyExecutionSettings(to: &parameters, from: searchInfo, dashboard: dashboard, userOverrides: userOverrides)
        applyResultSettings(to: &parameters, userOverrides: userOverrides, issues: &issues)
        applyDashboardContext(to: &parameters, from: dashboard, userOverrides: userOverrides)
        
        return SearchParametersResult(
            parameters: parameters,
            issues: issues.isEmpty ? nil : issues
        )
    }
    
    /// Convert search parameters to Splunk API format
    /// Note: Does NOT include the 'search' query itself - that's passed separately and formatted
    public nonisolated func convertToSplunkAPIParameters(_ parameters: SearchParameters) -> [String: Any] {
        var apiParams: [String: Any] = [:]
        
        // Do NOT include the search query here - it's passed separately to ensure proper formatting
        apiParams["output_mode"] = parameters.outputMode ?? "json"
        
        if let earliest = parameters.earliestTime {
            apiParams["earliest_time"] = earliest
        }
        if let latest = parameters.latestTime {
            apiParams["latest_time"] = latest
        }
        
        if let maxCount = parameters.maxCount {
            apiParams["max_count"] = maxCount
        }
        if let app = parameters.app {
            apiParams["namespace"] = app
        }
        
        return apiParams
    }
    
    // MARK: - Search Execution with Core Data State Management
    
    /// Start a search execution and track its progress in Core Data
    /// Returns immediately with an execution ID that can be monitored
    public func startSearchExecution(
        searchId: String,
        in dashboardId: String,
        userTokenValues: [String: String] = [:],
        timeRange: (earliest: String?, latest: String?)? = nil,
        parameterOverrides: SearchParameterOverrides = SearchParameterOverrides(),
        splunkCredentials: SplunkCredentials? = nil
    ) -> String {
        print("🔧 DEBUG: startSearchExecution CALLED for search: \(searchId)")
        
        let executionId = UUID().uuidString
        print("🔧 DEBUG: Generated execution ID: \(executionId)")
        
        // Create initial execution record in Core Data
        let execution = NSEntityDescription.insertNewObject(forEntityName: "SearchExecutionEntity", into: context) as! SearchExecutionEntity
        execution.id = executionId
        execution.searchId = searchId
        execution.dashboardId = dashboardId
        execution.status = SearchExecutionStatus.pending.rawValue
        execution.startTime = Date()
        execution.progress = 0.0
        
        saveContext()
        print("🔧 DEBUG: Created execution record in Core Data")
        
        // Post notification that execution started
        NotificationCenter.default.post(
            name: .searchExecutionStarted,
            object: nil,
            userInfo: ["executionId": executionId, "searchId": searchId, "dashboardId": dashboardId]
        )
        
        // Start async execution
        print("🔧 DEBUG: About to create Task.detached")
        Task.detached { [weak self] in
            print("🔧 DEBUG: Inside Task.detached for \(executionId)")
            await self?.executeSearchAsync(
                executionId: executionId,
                searchId: searchId,
                dashboardId: dashboardId,
                userTokenValues: userTokenValues,
                timeRange: timeRange,
                parameterOverrides: parameterOverrides,
                splunkCredentials: splunkCredentials
            )
            print("🔧 DEBUG: Task.detached finished for \(executionId)")
        }
        
        print("🔧 DEBUG: Returning execution ID: \(executionId)")
        return executionId
    }
    
    /// Get current execution status from Core Data
    public func getSearchExecutionStatus(executionId: String) -> SearchExecutionEntity? {
        let request: NSFetchRequest<SearchExecutionEntity> = SearchExecutionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", executionId)
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            print("❌ Error fetching search execution: \(error)")
            return nil
        }
    }
    
    /// Cancel a running search execution
    public func cancelSearchExecution(executionId: String) {
        guard let execution = getSearchExecutionStatus(executionId: executionId) else { return }
        
        execution.status = SearchExecutionStatus.cancelled.rawValue
        execution.endTime = Date()
        execution.errorMessage = "Cancelled by user"
        
        saveContext()
        
        // Post cancellation notification
        NotificationCenter.default.post(
            name: .searchExecutionCancelled,
            object: nil,
            userInfo: ["executionId": executionId]
        )
    }
    
    /// Get all search executions for monitoring
    public func getAllSearchExecutions() -> [SearchExecutionEntity] {
        let request: NSFetchRequest<SearchExecutionEntity> = SearchExecutionEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("❌ Error fetching search executions: \(error)")
            return []
        }
    }
    
    /// Get active (running/pending) search executions
    public func getActiveSearchExecutions() -> [SearchExecutionEntity] {
        let request: NSFetchRequest<SearchExecutionEntity> = SearchExecutionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "status == %@ OR status == %@", 
                                       SearchExecutionStatus.pending.rawValue,
                                       SearchExecutionStatus.running.rawValue)
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("❌ Error fetching active search executions: \(error)")
            return []
        }
    }
    
    /// Get search results from Core Data for a specific execution
    public func getSearchResults(executionId: String) -> SplunkSearchResults? {
        guard let execution = getSearchExecutionStatus(executionId: executionId) else { return nil }
        return execution.results
    }
    
    /// Get individual result records for an execution (useful for streaming large result sets)
    public func getSearchResultRecords(executionId: String, offset: Int = 0, limit: Int = 1000) -> [[String: Any]] {
        let request: NSFetchRequest<SearchResultEntity> = SearchResultEntity.fetchRequest()
        request.predicate = NSPredicate(format: "executionId == %@", executionId)
        request.sortDescriptors = [NSSortDescriptor(key: "resultIndex", ascending: true)]
        request.fetchOffset = offset
        request.fetchLimit = limit
        
        do {
            let results = try context.fetch(request)
            return results.compactMap { $0.resultDictionary }
        } catch {
            print("❌ Error fetching search result records: \(error)")
            return []
        }
    }
    
    /// Watch for search execution updates (for CLI monitoring)
    public func watchSearchExecution(executionId: String, callback: @escaping (SearchExecutionSummary) -> Void) -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(
            forName: .searchExecutionProgressUpdated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let notificationExecutionId = userInfo["executionId"] as? String,
                  notificationExecutionId == executionId else { return }
            
            // Use Task to properly call the main actor method
            Task { @MainActor in
                guard let summary = self?.getExecutionSummary(executionId: executionId) else { return }
                callback(summary)
            }
        }
    }
    
    /// Get execution status as a simple sendable struct (for CLI use)
    public func getExecutionSummary(executionId: String) -> SearchExecutionSummary? {
        guard let execution = getSearchExecutionStatus(executionId: executionId) else { return nil }
        
        return SearchExecutionSummary(
            id: execution.id,
            searchId: execution.searchId,
            dashboardId: execution.dashboardId,
            status: execution.executionStatus,
            progress: execution.progress,
            message: execution.statusMessage,
            startTime: execution.startTime,
            endTime: execution.endTime,
            resultCount: Int(execution.resultCount),
            jobId: execution.jobId,
            errorMessage: execution.errorMessage
        )
    }
    
    /// Clean up old completed search executions (older than specified days)
    public func cleanupOldSearchExecutions(days: Int = 7) throws {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        let request: NSFetchRequest<SearchExecutionEntity> = SearchExecutionEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "(status == %@ OR status == %@ OR status == %@) AND startTime < %@",
            SearchExecutionStatus.completed.rawValue,
            SearchExecutionStatus.failed.rawValue,
            SearchExecutionStatus.cancelled.rawValue,
            cutoffDate as NSDate
        )
        
        do {
            let oldExecutions = try context.fetch(request)
            
            for execution in oldExecutions {
                // Also clean up associated result entities
                let resultRequest: NSFetchRequest<SearchResultEntity> = SearchResultEntity.fetchRequest()
                resultRequest.predicate = NSPredicate(format: "executionId == %@", execution.id)
                
                let results = try context.fetch(resultRequest)
                for result in results {
                    context.delete(result)
                }
                
                context.delete(execution)
            }
            
            if !oldExecutions.isEmpty {
                saveContext()
                print("✅ Cleaned up \(oldExecutions.count) old search executions")
            }
            
        } catch {
            throw CoreDataError.deleteFailed(entityName: "SearchExecutionEntity", error: error)
        }
    }
    
    // MARK: - Base Search Resolution
    
    /// Get the most recent SID for a completed search by search ID
    /// This is used to resolve base search references (e.g., base="my_base_search")
    public func getSearchSID(searchId: String, in dashboardId: String) -> String? {
        let request: NSFetchRequest<SearchExecutionEntity> = SearchExecutionEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "searchId == %@ AND dashboardId == %@ AND status == %@ AND jobId != nil",
            searchId,
            dashboardId,
            SearchExecutionStatus.completed.rawValue
        )
        request.sortDescriptors = [NSSortDescriptor(key: "endTime", ascending: false)]
        request.fetchLimit = 1
        
        do {
            let result = try context.fetch(request).first?.jobId
            if let sid = result {
                print("✅ Found SID '\(sid)' for base search '\(searchId)'")
            }
            return result
        } catch {
            print("❌ Error fetching search SID for '\(searchId)': \(error)")
            return nil
        }
    }
    
    // MARK: - Search Execution Implementation
    
    /// Execute search asynchronously and update Core Data with progress
    private func executeSearchAsync(
        executionId: String,
        searchId: String,
        dashboardId: String,
        userTokenValues: [String: String],
        timeRange: (earliest: String?, latest: String?)?,
        parameterOverrides: SearchParameterOverrides,
        splunkCredentials: SplunkCredentials?
    ) async {
        print("🔧 DEBUG: executeSearchAsync STARTED for execution \(executionId)")
        fflush(stdout)  // Force flush stdout in case of buffering issues
        
        await MainActor.run {
            updateExecutionProgress(executionId: executionId, status: .running, progress: 0.1, message: "Starting search execution...")
        }
        
        do {
            // Stage 1: Discovery & Validation (10%)
            guard let searchInfo = await MainActor.run(body: { findSearch(searchId: searchId, in: dashboardId) }) else {
                await MainActor.run {
                    updateExecutionProgress(executionId: executionId, status: .failed, progress: 0.0, message: "Search not found: \(searchId)")
                }
                return
            }
            
            // Check if this search has a base search reference
            // Check both 'base' and 'ref' properties (base is more common in Splunk dashboards)
            var baseSearchSID: String?
            var effectiveTimeRange = timeRange
            
            let baseRef = searchInfo.searchEntity?.base ?? searchInfo.searchEntity?.ref
            
            if let baseRef = baseRef, !baseRef.isEmpty {
                await MainActor.run {
                    updateExecutionProgress(executionId: executionId, status: .running, progress: 0.15, message: "Resolving base search reference: \(baseRef)...")
                }
                
                // Try to get the SID for the base search
                if let sid = await MainActor.run(body: { getSearchSID(searchId: baseRef, in: dashboardId) }) {
                    baseSearchSID = sid
                    // When using base search, typically no time range is needed
                    effectiveTimeRange = nil
                    print("✅ Resolved base search '\(baseRef)' to SID: \(sid)")
                } else {
                    await MainActor.run {
                        updateExecutionProgress(
                            executionId: executionId,
                            status: .failed,
                            progress: 0.0,
                            message: "Base search '\(baseRef)' not found or not yet executed. Please run the base search first."
                        )
                    }
                    return
                }
            }
            
            await MainActor.run {
                updateExecutionProgress(executionId: executionId, status: .running, progress: 0.2, message: "Resolving tokens...")
            }
            
            // Stage 2: Token Resolution (20%)
            // Use effectiveTimeRange instead of timeRange
            let tokenResolution = await MainActor.run {
                resolveTokens(for: searchInfo, in: dashboardId, userProvidedValues: userTokenValues, timeRange: effectiveTimeRange)
            }
            
            guard tokenResolution.isFullyResolved else {
                await MainActor.run {
                    updateExecutionProgress(
                        executionId: executionId,
                        status: .failed,
                        progress: 0.0,
                        message: "Token resolution failed: \(tokenResolution.unresolvedTokens.joined(separator: ", "))"
                    )
                }
                return
            }
            
            await MainActor.run {
                updateExecutionProgress(executionId: executionId, status: .running, progress: 0.3, message: "Building search parameters...")
            }
            
            // Stage 3: Parameters & Configuration (30%)
            let parametersResult = await MainActor.run {
                buildSearchParameters(from: tokenResolution, in: dashboardId, userOverrides: parameterOverrides)
            }
            
            guard parametersResult.isValid, var searchParameters = parametersResult.parameters else {
                let issues = parametersResult.issues?.map { $0.description } ?? ["Unknown parameter building error"]
                await MainActor.run {
                    updateExecutionProgress(
                        executionId: executionId,
                        status: .failed,
                        progress: 0.0,
                        message: "Parameter building failed: \(issues.joined(separator: ", "))"
                    )
                }
                return
            }
            
            // If we have a base search SID, prepend the query with | loadjob
            if let sid = baseSearchSID {
                // First, strip any "search " prefix from the original query since we're making it a pipe command
                var cleanQuery = searchParameters.query
                if cleanQuery.lowercased().hasPrefix("search ") {
                    cleanQuery = String(cleanQuery.dropFirst(7)).trimmingCharacters(in: .whitespaces)
                }
                
                // If the cleaned query starts with |, remove it (we'll add | loadjob)
                if cleanQuery.hasPrefix("|") {
                    cleanQuery = cleanQuery.dropFirst().trimmingCharacters(in: .whitespaces)
                }
                
                // Now prepend with | loadjob
                searchParameters.query = "| loadjob \(sid) | \(cleanQuery)"
                
                // Remove time range parameters when using base search
                searchParameters.earliestTime = nil
                searchParameters.latestTime = nil
                print("🔗 Modified query for base search: \(searchParameters.query)")
            }
            
            await MainActor.run {
                updateExecutionProgress(executionId: executionId, status: .running, progress: 0.4, message: "Connecting to Splunk...")
            }
            
            // Stage 4: Splunk Execution (40% - 100%)
            await executeSplunkSearchWithProgress(
                executionId: executionId,
                searchParameters: searchParameters,
                credentials: splunkCredentials
            )
            
        } catch {
            await MainActor.run {
                updateExecutionProgress(
                    executionId: executionId,
                    status: .failed,
                    progress: 0.0,
                    message: "Unexpected error: \(error.localizedDescription)"
                )
            }
        }
    }
    
    /// Execute Splunk search with progress updates and Core Data storage
    private func executeSplunkSearchWithProgress(
        executionId: String,
        searchParameters: SearchParameters,
        credentials: SplunkCredentials?
    ) async {
        
        do {
            // Create Splunk service configuration
            let splunkService = try await createSplunkService(
                app: searchParameters.app ?? "search",
                credentials: credentials
            )
            
            await MainActor.run {
                updateExecutionProgress(executionId: executionId, status: .running, progress: 0.5, message: "Submitting search to Splunk...")
            }
            
            // Format query for Splunk
            let formattedQuery = formatQueryForSplunk(searchParameters.query)
            print("🔧 DEBUG: Original query: \(searchParameters.query)")
            print("🔧 DEBUG: Formatted query: \(formattedQuery)")
            
            await MainActor.run {
                updateSearchQuery(executionId: executionId, query: formattedQuery)
                updateExecutionProgress(executionId: executionId, status: .running, progress: 0.6, message: "Search submitted, waiting for results...")
            }
            
            // Execute search with progress monitoring
            let searchJob = try await splunkService.submitSearch(
                query: formattedQuery,
                earliest: searchParameters.earliestTime,
                latest: searchParameters.latestTime,
                app: searchParameters.app,
                parameters: convertToSplunkAPIParameters(searchParameters)
            )
            
            // Store the search job ID (SID)
            await MainActor.run {
                updateSearchJobId(executionId: executionId, jobId: searchJob.sid)
                updateExecutionProgress(executionId: executionId, status: .running, progress: 0.7, message: "Monitoring search job: \(searchJob.sid)")
            }
            
            // Monitor search progress and get final status
            var lastProgress: Double = 0.7
            var finalJobStatus: SplunkSearchJobStatus
            while true {
                let jobStatus = try await splunkService.getSearchJobStatus(sid: searchJob.sid)
                finalJobStatus = jobStatus
                
                if jobStatus.isDone {
                    break
                }
                
                // Calculate progress based on Splunk job status
                let searchProgress = calculateSearchProgress(from: jobStatus)
                let overallProgress = 0.7 + (searchProgress * 0.25) // 70-95% range for execution
                
                if overallProgress > lastProgress {
                    lastProgress = overallProgress
                    await MainActor.run {
                        updateExecutionProgress(
                            executionId: executionId, 
                            status: .running, 
                            progress: overallProgress, 
                            message: "Executing search... \(Int(searchProgress * 100))% complete"
                        )
                    }
                }
                
                // Wait before next status check
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            }
            
            await MainActor.run {
                updateExecutionProgress(executionId: executionId, status: .running, progress: 0.95, message: "Retrieving search results...")
            }
            
            // Get final results
            let results = try await splunkService.getSearchResults(sid: searchJob.sid)
            
            // Store results in Core Data with full metadata
            await MainActor.run {
                storeSearchResultsWithMetadata(executionId: executionId, results: results, jobStatus: finalJobStatus)
                updateExecutionProgress(
                    executionId: executionId,
                    status: .completed,
                    progress: 1.0,
                    message: "Search completed successfully with \(results.results.count) results"
                )
            }
            
        } catch {
            await MainActor.run {
                updateExecutionProgress(
                    executionId: executionId,
                    status: .failed,
                    progress: 0.0,
                    message: "Splunk execution error: \(error.localizedDescription)"
                )
            }
        }
    }
    
    /// Calculate search progress from Splunk job status
    private nonisolated func calculateSearchProgress(from jobStatus: SplunkSearchJobStatus) -> Double {
        // Use doneProgress directly from Splunk, which is a value between 0.0 and 1.0
        return min(1.0, max(0.0, jobStatus.doneProgress))
    }
    
    /// Update execution progress in Core Data and emit notifications
    private func updateExecutionProgress(
        executionId: String,
        status: SearchExecutionStatus,
        progress: Double,
        message: String
    ) {
        guard let execution = getSearchExecutionStatus(executionId: executionId) else { return }
        
        execution.status = status.rawValue
        execution.progress = progress
        execution.statusMessage = message
        
        if status == .completed || status == .failed || status == .cancelled {
            execution.endTime = Date()
        }
        
        saveContext()
        
        // Emit progress notification for real-time monitoring
        NotificationCenter.default.post(
            name: .searchExecutionProgressUpdated,
            object: nil,
            userInfo: [
                "executionId": executionId,
                "status": status.rawValue,
                "progress": progress,
                "message": message,
                "timestamp": Date()
            ]
        )
        
        print("🔄 Search \(executionId): \(status.rawValue.capitalized) - \(Int(progress * 100))% - \(message)")
    }
    
    /// Update the resolved search query in Core Data
    private func updateSearchQuery(executionId: String, query: String) {
        guard let execution = getSearchExecutionStatus(executionId: executionId) else { return }
        execution.resolvedQuery = query
        saveContext()
    }
    
    /// Update search job ID (SID) in Core Data
    private func updateSearchJobId(executionId: String, jobId: String) {
        guard let execution = getSearchExecutionStatus(executionId: executionId) else { return }
        execution.jobId = jobId
        saveContext()
        
        // Emit SID notification for external monitoring
        NotificationCenter.default.post(
            name: .searchJobCreated,
            object: nil,
            userInfo: [
                "executionId": executionId,
                "jobId": jobId,
                "timestamp": Date()
            ]
        )
    }
    
    /// Store search results with complete metadata in Core Data  
    private func storeSearchResultsWithMetadata(executionId: String, results: SplunkSearchResults, jobStatus: SplunkSearchJobStatus) {
        guard let execution = getSearchExecutionStatus(executionId: executionId) else { return }
        
        // Store basic result metadata
        execution.resultCount = Int32(results.results.count)
        
        // Create comprehensive metadata
        var enhancedMetadata: [String: SplunkSearchResults.AnyCodable] = results.metadata ?? [:]
        enhancedMetadata["scan_count"] = SplunkSearchResults.AnyCodable(jobStatus.scanCount ?? 0)
        enhancedMetadata["event_count"] = SplunkSearchResults.AnyCodable(jobStatus.eventCount ?? 0)
        enhancedMetadata["done_progress"] = SplunkSearchResults.AnyCodable(jobStatus.doneProgress)
        enhancedMetadata["result_count"] = SplunkSearchResults.AnyCodable(results.results.count)
        enhancedMetadata["execution_time"] = SplunkSearchResults.AnyCodable(execution.executionDuration ?? 0)
        enhancedMetadata["dispatch_state"] = SplunkSearchResults.AnyCodable(jobStatus.dispatchState)
        enhancedMetadata["is_done"] = SplunkSearchResults.AnyCodable(jobStatus.isDone)
        enhancedMetadata["is_failed"] = SplunkSearchResults.AnyCodable(jobStatus.isFailed)
        
        // Store enhanced results
        let enhancedResults = SplunkSearchResults(
            results: results.results,
            fields: results.fields,
            metadata: enhancedMetadata
        )
        
        // Store the complete JSON payload
        if let jsonData = try? JSONEncoder().encode(enhancedResults) {
            execution.resultsJsonData = jsonData
        }
        
        // Store individual result records for efficient querying
        for (index, result) in results.results.enumerated() {
            let resultEntity = NSEntityDescription.insertNewObject(forEntityName: "SearchResultEntity", into: context) as! SearchResultEntity
            resultEntity.executionId = executionId
            resultEntity.resultIndex = Int32(index)
            
            // Convert AnyCodable to a serializable dictionary
            var serializedResult: [String: Any] = [:]
            for (key, value) in result {
                serializedResult[key] = value.value
            }
            
            if let jsonData = try? JSONSerialization.data(withJSONObject: serializedResult) {
                resultEntity.jsonData = jsonData
            }
        }
        
        saveContext()
        
        // Emit completion notification with rich metadata
        NotificationCenter.default.post(
            name: .searchExecutionCompleted,
            object: nil,
            userInfo: [
                "executionId": executionId,
                "searchId": execution.searchId,
                "dashboardId": execution.dashboardId,
                "resultCount": results.results.count,
                "scanCount": jobStatus.scanCount ?? 0,
                "executionDuration": execution.executionDuration ?? 0,
                "timestamp": Date(),
                "dispatchState": jobStatus.dispatchState
            ]
        )
        
        print("✅ Search \(executionId) completed: \(results.results.count) results (scan: \(jobStatus.scanCount ?? 0), progress: \(Int(jobStatus.doneProgress * 100))%)")
    }
    
    /// Format search query with proper prefix requirements
    private nonisolated func formatQueryForSplunk(_ query: String) -> String {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Rule 1: If query starts with |, don't add search prefix
        if trimmedQuery.hasPrefix("|") {
            return trimmedQuery
        }
        
        // Rule 2: If query already starts with "search", don't add another prefix
        if trimmedQuery.lowercased().hasPrefix("search ") {
            return trimmedQuery
        }
        
        // Rule 3: Otherwise, prepend "search "
        return "search \(trimmedQuery)"
    }
    
    /// Create and configure SplunkSearchService
    private nonisolated func createSplunkService(app: String, credentials: SplunkCredentials?) async throws -> SplunkSearchService {
        let configTemplate = try SplunkConfiguration.loadFromPlist()
        
        let finalCredentials: SplunkCredentials
        if let credentials = credentials {
            finalCredentials = credentials
        } else {
            let serverHost = configTemplate.baseURL.host ?? configTemplate.baseURL.absoluteString
            finalCredentials = try getStoredCredentials(serverHost: serverHost)
        }
        
        let configuration = configTemplate.withCredentials(finalCredentials)
        let restClient = SplunkRestClient(configuration: configuration)
        return SplunkSearchService(restClient: restClient)
    }
    
    /// Get stored credentials from keychain with fallback priority
    private nonisolated func getStoredCredentials(serverHost: String) throws -> SplunkCredentials {
        let credentialManager = SplunkCredentialManager()
        
        // Priority 1: Try to get a stored token
        if let storedToken = try? credentialManager.retrieveToken(server: serverHost) {
            return .token(storedToken)
        }
        
        // Priority 2: Try to find any stored username/password credentials
        let storedCredentials = try? credentialManager.listStoredCredentials()
        let matchingCredentials = storedCredentials?.filter { !$0.isToken && $0.server == serverHost }
        
        if let firstCredential = matchingCredentials?.first {
            let username = firstCredential.account
            let password = try credentialManager.retrieveCredentials(server: serverHost, username: username)
            return .basic(username: username, password: password)
        }
        
        // No stored credentials found
        throw SplunkError.authenticationFailed("""
        No stored credentials found for server: \(serverHost)
        
        Please either:
        1. Use splunk-dashboard command-line tool to store credentials securely, or  
        2. Provide credentials via the executeSearch method parameters
        """)
    }
    
    // MARK: - Private Helper Methods
    
    private func applyTimeRange(
        to parameters: inout SearchParameters,
        from searchInfo: SearchInfo,
        dashboard: DashboardEntity,
        userOverrides: SearchParameterOverrides
    ) {
        parameters.earliestTime = userOverrides.earliestTime ?? searchInfo.searchEntity?.earliestTime ?? dashboard.globalEarliestTime ?? "-24h@h"
        parameters.latestTime = userOverrides.latestTime ?? searchInfo.searchEntity?.latestTime ?? dashboard.globalLatestTime ?? "now"
    }
    
    private func applyExecutionSettings(
        to parameters: inout SearchParameters,
        from searchInfo: SearchInfo,
        dashboard: DashboardEntity,
        userOverrides: SearchParameterOverrides
    ) {
        parameters.searchMode = userOverrides.searchMode ?? "normal"
        parameters.autostart = userOverrides.autostart ?? searchInfo.searchEntity?.autostart ?? true
        parameters.timeout = userOverrides.timeout ?? 300
    }
    
    private func applyResultSettings(
        to parameters: inout SearchParameters,
        userOverrides: SearchParameterOverrides,
        issues: inout [SearchParameterIssue]
    ) {
        parameters.outputMode = userOverrides.outputMode ?? "json"
        parameters.maxCount = userOverrides.maxCount ?? 1000
        parameters.offset = userOverrides.offset ?? 0
        
        if parameters.maxCount! > 50000 {
            issues.append(.maxCountTooHigh(parameters.maxCount!))
            parameters.maxCount = 50000
        }
    }
    
    private func applyDashboardContext(
        to parameters: inout SearchParameters,
        from dashboard: DashboardEntity,
        userOverrides: SearchParameterOverrides
    ) {
        parameters.app = userOverrides.app ?? dashboard.appName ?? "search"
        parameters.owner = userOverrides.owner ?? "admin"
        parameters.dashboardTitle = dashboard.title
    }
    
    // MARK: - Search Refresh Parsing
    
    /// Parse refresh interval string (format: "1+m" or "1m" where denominator is s,m,h,d,w,MON)
    /// - Parameter refreshString: The refresh string from the search entity
    /// - Returns: The refresh interval in seconds, or nil if invalid/not set
    public func parseSearchRefreshInterval(_ refreshString: String?) -> TimeInterval? {
        guard let refreshString = refreshString, !refreshString.isEmpty else {
            return nil
        }
        
        let trimmed = refreshString.trimmingCharacters(in: .whitespaces)
        
        // Try format with + separator first: "number+denominator" (e.g., "30+s", "5+m", "1+h")
        if trimmed.contains("+") {
            let components = trimmed.components(separatedBy: "+")
            guard components.count == 2,
                  let number = Double(components[0]) else {
                print("⚠️ Invalid refresh format: \(refreshString)")
                return nil
            }
            
            let denominator = components[1].lowercased()
            return intervalMultiplier(for: denominator, number: number, original: refreshString)
        }
        
        // Try Splunk format: "1m", "30s", "2h", etc.
        var numericPart = ""
        var unitPart = ""
        
        for char in trimmed {
            if char.isNumber || char == "." || char == "-" {
                numericPart.append(char)
            } else {
                unitPart.append(char)
            }
        }
        
        guard let number = Double(numericPart), number > 0 else {
            print("⚠️ Invalid refresh format: \(refreshString)")
            return nil
        }
        
        let denominator = unitPart.lowercased()
        return intervalMultiplier(for: denominator, number: number, original: refreshString)
    }
    
    /// Calculate the interval multiplier for a given time unit
    private func intervalMultiplier(for denominator: String, number: Double, original: String) -> TimeInterval? {
        let multiplier: TimeInterval
        
        switch denominator {
        case "s":
            multiplier = 1.0 // seconds
        case "m":
            multiplier = 60.0 // minutes
        case "h":
            multiplier = 3600.0 // hours
        case "d":
            multiplier = 86400.0 // days
        case "w":
            multiplier = 604800.0 // weeks
        case "mon":
            multiplier = 2592000.0 // months (30 days)
        default:
            print("⚠️ Unknown refresh denominator: \(denominator) in \(original)")
            return nil
        }
        
        return number * multiplier
    }
    
    /// Get all searches in a dashboard that have refresh intervals
    /// - Parameter dashboardId: The dashboard ID
    /// - Returns: Array of tuples containing (searchId, refreshInterval in seconds)
    public func getSearchesWithRefresh(in dashboardId: String) -> [(searchId: String, refreshInterval: TimeInterval)] {
        guard let dashboard = getDashboard(id: dashboardId) else {
            print("⚠️ Dashboard not found: \(dashboardId)")
            return []
        }
        
        var searchesWithRefresh: [(String, TimeInterval)] = []
        
        // Check searches in rows/panels
        if let rows = dashboard.rows?.allObjects as? [RowEntity] {
            for row in rows {
                if let panels = row.panels?.allObjects as? [PanelEntity] {
                    for panel in panels {
                        if let searches = panel.searches?.allObjects as? [SearchEntity] {
                            for search in searches {
                                if let refreshString = search.refresh,
                                   let interval = parseSearchRefreshInterval(refreshString) {
                                    searchesWithRefresh.append((search.id, interval))
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // Also check global searches
        if let globalSearches = dashboard.globalSearches?.allObjects as? [SearchEntity] {
            for search in globalSearches {
                if let refreshString = search.refresh,
                   let interval = parseSearchRefreshInterval(refreshString) {
                    searchesWithRefresh.append((search.id, interval))
                }
            }
        }
        
        return searchesWithRefresh
    }
}

// MARK: - Core Data Errors

public enum CoreDataError: Error, LocalizedError, Sendable {
    case deleteFailed(entityName: String, error: Error)
    case dashboardNotFound(id: String)
    case saveFailed(error: Error)
    case fetchFailed(error: Error)
    
    public var errorDescription: String? {
        switch self {
        case .deleteFailed(let entityName, let error):
            return "Failed to delete \(entityName): \(error.localizedDescription)"
        case .dashboardNotFound(let id):
            return "Dashboard not found: \(id)"
        case .saveFailed(let error):
            return "Failed to save: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch: \(error.localizedDescription)"
        }
    }
}

// MARK: - Search Discovery Types

/// Represents a search found in a dashboard with its context
public struct SearchInfo: @unchecked Sendable {
    public let id: String
    public let query: String?
    public let searchType: SearchType
    public let location: SearchLocation
    public let searchEntity: SearchEntity?
    
    public enum SearchType: Sendable {
        case panel
        case visualization 
        case global
    }
}

/// Location context for where a search was found
public enum SearchLocation: Sendable {
    case panel(panelId: String, rowId: String)
    case visualization(vizId: String, panelId: String, rowId: String)
    case global
    
    public var description: String {
        switch self {
        case .panel(let panelId, let rowId):
            return "Panel '\(panelId)' in row '\(rowId)'"
        case .visualization(let vizId, let panelId, let rowId):
            return "Visualization '\(vizId)' in panel '\(panelId)' in row '\(rowId)'"
        case .global:
            return "Global search"
        }
    }
}

/// Result of search discovery in a dashboard
public struct SearchDiscoveryResult: Sendable {
    public let dashboardId: String
    public let panelSearches: [SearchInfo]
    public let visualizationSearches: [SearchInfo]
    public let globalSearches: [SearchInfo]
    public let error: CoreDataError?
    
    public var allSearches: [SearchInfo] {
        return panelSearches + visualizationSearches + globalSearches
    }
    
    public var totalCount: Int {
        return allSearches.count
    }
}

/// Issues that can be found during search validation
public enum SearchValidationIssue: Sendable {
    case emptyQuery
    case undefinedToken(String)
    case invalidSearchReference(String)
    case dashboardNotFound
    
    public var description: String {
        switch self {
        case .emptyQuery:
            return "Search has no query"
        case .undefinedToken(let token):
            return "Token '\(token)' is not defined in dashboard"
        case .invalidSearchReference(let ref):
            return "Search reference '\(ref)' not found"
        case .dashboardNotFound:
            return "Dashboard not found"
        }
    }
}

/// Time range for search execution
public struct SearchTimeRange: Sendable {
    public let earliest: String?
    public let latest: String?
    
    public var hasTimeRange: Bool {
        return earliest != nil || latest != nil
    }
}

/// Result of search validation
public struct SearchValidationResult: Sendable {
    public let searchInfo: SearchInfo
    public let isValid: Bool
    public let issues: [SearchValidationIssue]
    public let tokenReferences: [String]
    public let timeRange: SearchTimeRange?
    
    public var issueDescriptions: [String] {
        return issues.map { $0.description }
    }
}

/// Token definition for search resolution  
public struct SearchTokenDefinition: Sendable {
    public let name: String
    public let type: String
    public let label: String?
    public let defaultValue: String?
    public let required: Bool
    public let choices: [SearchTokenChoice]
    
    public var hasChoices: Bool {
        return !choices.isEmpty
    }
}

/// Token choice option
public struct SearchTokenChoice: Sendable {
    public let value: String
    public let label: String
    public let isDefault: Bool
}

// MARK: - Token Resolution Types

/// Issues that can occur during token resolution
public enum TokenResolutionIssue: Sendable {
    case validationError(String)
    case cannotResolveToken(String)
    case usedDefaultChoice(String)
    case usedFirstChoice(String)
    case usedWildcardDefault(String)
    case usedTimeDefault(String, String)
    case usedBooleanDefault(String)
    
    public var description: String {
        switch self {
        case .validationError(let message):
            return "Validation error: \(message)"
        case .cannotResolveToken(let token):
            return "Cannot resolve token: \(token)"
        case .usedDefaultChoice(let token):
            return "Used default choice for token: \(token)"
        case .usedFirstChoice(let token):
            return "Used first available choice for token: \(token)"
        case .usedWildcardDefault(let token):
            return "Used wildcard (*) default for token: \(token)"
        case .usedTimeDefault(let token, let description):
            return "Used time default (\(description)) for token: \(token)"
        case .usedBooleanDefault(let token):
            return "Used boolean default (true) for token: \(token)"
        }
    }
    
    public var isWarning: Bool {
        switch self {
        case .validationError, .cannotResolveToken:
            return false
        default:
            return true
        }
    }
}

/// Result of token resolution process
public struct TokenResolutionResult: Sendable {
    public let searchInfo: SearchInfo
    public let resolvedValues: [String: String]
    public let unresolvedTokens: [String]
    public let resolvedQuery: String?
    public let issues: [TokenResolutionIssue]
    
    public var isFullyResolved: Bool {
        return unresolvedTokens.isEmpty && resolvedQuery != nil
    }
    
    public var hasErrors: Bool {
        return issues.contains { !$0.isWarning }
    }
    
    public var warnings: [TokenResolutionIssue] {
        return issues.filter { $0.isWarning }
    }
    
    public var errors: [TokenResolutionIssue] {
        return issues.filter { !$0.isWarning }
    }
}

// MARK: - Search Parameters Types

/// Complete search parameters ready for Splunk execution
public struct SearchParameters: Sendable {
    public var query: String
    public let searchId: String
    public let dashboardId: String
    public let location: SearchLocation
    
    public var earliestTime: String?
    public var latestTime: String?
    public var searchMode: String?
    public var autostart: Bool?
    public var timeout: Int?
    public var outputMode: String?
    public var maxCount: Int?
    public var offset: Int?
    public var app: String?
    public var owner: String?
    public var dashboardTitle: String?
    
    public init(query: String, searchId: String, dashboardId: String, location: SearchLocation) {
        self.query = query
        self.searchId = searchId
        self.dashboardId = dashboardId
        self.location = location
    }
}

/// User overrides for search parameters
public struct SearchParameterOverrides: Sendable {
    public var earliestTime: String?
    public var latestTime: String?
    public var searchMode: String?
    public var autostart: Bool?
    public var timeout: Int?
    public var outputMode: String?
    public var maxCount: Int?
    public var offset: Int?
    public var app: String?
    public var owner: String?
    
    public init() {}
}

/// Issues that can occur during search parameter building
public enum SearchParameterIssue: Sendable {
    case tokenResolutionIncomplete
    case dashboardNotFound
    case maxCountTooHigh(Int)
    case timeoutTooHigh(Int)
    case invalidBaseSearchReference(String)
    
    public var description: String {
        switch self {
        case .tokenResolutionIncomplete:
            return "Token resolution is not complete"
        case .dashboardNotFound:
            return "Dashboard not found"
        case .maxCountTooHigh(let count):
            return "Max count too high (\(count)), reduced to 50000"
        case .timeoutTooHigh(let timeout):
            return "Timeout too high (\(timeout)), reduced to 3600 seconds"
        case .invalidBaseSearchReference(let ref):
            return "Invalid base search reference: \(ref)"
        }
    }
}

/// Result of search parameter building
public struct SearchParametersResult: Sendable {
    public let parameters: SearchParameters?
    public let issues: [SearchParameterIssue]?
    
    public var isValid: Bool {
        return parameters != nil
    }
    
    public var hasIssues: Bool {
        return issues != nil && !issues!.isEmpty
    }
}

// MARK: - Search Execution Types

/// Status of search execution
public enum SearchExecutionStatus: String, Sendable, CaseIterable {
    case pending = "pending"
    case running = "running" 
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
}

/// Simple sendable summary of search execution status (for CLI use)
public struct SearchExecutionSummary: Sendable {
    public let id: String
    public let searchId: String
    public let dashboardId: String
    public let status: SearchExecutionStatus
    public let progress: Double
    public let message: String?
    public let startTime: Date
    public let endTime: Date?
    public let resultCount: Int
    public let jobId: String?
    public let errorMessage: String?
    
    public var isComplete: Bool {
        return status == .completed || status == .failed || status == .cancelled
    }
    
    public var duration: TimeInterval? {
        guard let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }
}

/// Errors that can occur during search execution
public enum SearchExecutionError: Error, LocalizedError, Sendable {
    case searchNotFound(String)
    case validationFailed([String])
    case tokenResolutionFailed([String])
    case parameterBuildingFailed([String])
    case splunkError(SplunkError)
    case unexpectedError(Error)
    case baseSearchNotFound(String)
    case baseSearchUnresolved(String)
    case baseSearchSidNotFound(String)
    
    public var errorDescription: String? {
        switch self {
        case .searchNotFound(let id):
            return "Search not found: \(id)"
        case .validationFailed(let issues):
            return "Validation failed: \(issues.joined(separator: ", "))"
        case .tokenResolutionFailed(let tokens):
            return "Token resolution failed for: \(tokens.joined(separator: ", "))"
        case .parameterBuildingFailed(let issues):
            return "Parameter building failed: \(issues.joined(separator: ", "))"
        case .splunkError(let error):
            return "Splunk error: \(error.localizedDescription)"
        case .unexpectedError(let error):
            return "Unexpected error: \(error.localizedDescription)"
        case .baseSearchNotFound(let message):
            return "Base search not found: \(message)"
        case .baseSearchUnresolved(let message):
            return "Base search unresolved: \(message)"
        case .baseSearchSidNotFound(let message):
            return "Base search SID not found: \(message)"
        }
    }
}

/// Complete result of search execution
public struct SearchExecutionResult: Sendable {
    public let searchInfo: SearchInfo?
    public let executionStatus: SearchExecutionStatus
    public let error: SearchExecutionError?
    public let jobId: String?
    public let results: SplunkSearchResults?
    public let metadata: SearchExecutionMetadata?
    
    /// Public initializer for creating SearchExecutionResult instances
    public init(
        searchInfo: SearchInfo?,
        executionStatus: SearchExecutionStatus,
        error: SearchExecutionError?,
        jobId: String?,
        results: SplunkSearchResults?,
        metadata: SearchExecutionMetadata?
    ) {
        self.searchInfo = searchInfo
        self.executionStatus = executionStatus
        self.error = error
        self.jobId = jobId
        self.results = results
        self.metadata = metadata
    }
    
    public var isSuccessful: Bool {
        return executionStatus == .completed && error == nil
    }
    
    public var resultCount: Int {
        return results?.results.count ?? 0
    }
}

/// Execution metadata for completed searches
public struct SearchExecutionMetadata: Sendable {
    public let searchParameters: SearchParameters
    public let jobId: String
    public let startTime: Date
    public let endTime: Date
    public let resultCount: Int
    public let executionTime: TimeInterval
    public let warnings: [String]
    
    /// Public initializer for creating SearchExecutionMetadata instances
    public init(
        searchParameters: SearchParameters,
        jobId: String,
        startTime: Date,
        endTime: Date,
        resultCount: Int,
        executionTime: TimeInterval,
        warnings: [String]
    ) {
        self.searchParameters = searchParameters
        self.jobId = jobId
        self.startTime = startTime
        self.endTime = endTime
        self.resultCount = resultCount
        self.executionTime = executionTime
        self.warnings = warnings
    }
    
    public var duration: TimeInterval {
        return endTime.timeIntervalSince(startTime)
    }
}

// MARK: - Search Execution Core Data Entities

@objc(SearchExecutionEntity)
public class SearchExecutionEntity: NSManagedObject, @unchecked Sendable {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<SearchExecutionEntity> {
        return NSFetchRequest<SearchExecutionEntity>(entityName: "SearchExecutionEntity")
    }
    
    @NSManaged public var id: String
    @NSManaged public var searchId: String
    @NSManaged public var dashboardId: String
    @NSManaged public var status: String
    @NSManaged public var progress: Double
    @NSManaged public var statusMessage: String?
    @NSManaged public var startTime: Date
    @NSManaged public var endTime: Date?
    @NSManaged public var jobId: String?
    @NSManaged public var resolvedQuery: String?
    @NSManaged public var resultCount: Int32
    @NSManaged public var resultsJsonData: Data?
    @NSManaged public var errorMessage: String?
    
    public var executionStatus: SearchExecutionStatus {
        get { SearchExecutionStatus(rawValue: status) ?? .pending }
        set { status = newValue.rawValue }
    }
    
    public var results: SplunkSearchResults? {
        guard let data = resultsJsonData else { return nil }
        return try? JSONDecoder().decode(SplunkSearchResults.self, from: data)
    }
    
    public var executionDuration: TimeInterval? {
        guard let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }
}

@objc(SearchResultEntity)
public class SearchResultEntity: NSManagedObject, @unchecked Sendable {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<SearchResultEntity> {
        return NSFetchRequest<SearchResultEntity>(entityName: "SearchResultEntity")
    }
    
    @NSManaged public var executionId: String
    @NSManaged public var resultIndex: Int32
    @NSManaged public var jsonData: Data?
    
    public var resultDictionary: [String: Any]? {
        guard let data = jsonData else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
