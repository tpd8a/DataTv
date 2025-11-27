import Foundation
import CoreData

/// Background worker that manages CoreData persistence and search execution tracking
public actor CoreDataManager {
    public static let shared = CoreDataManager()

    public let persistentContainer: NSPersistentContainer
    private var dataSources: [String: any DataSourceProtocol] = [:]

    // MARK: - Initialization

    private init() {
        // Load the model from the bundle
        guard let modelURL = Bundle.module.url(forResource: "DashboardModel", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Failed to load CoreData model")
        }

        persistentContainer = NSPersistentContainer(name: "DashboardModel", managedObjectModel: model)
        persistentContainer.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Failed to load persistent stores: \(error)")
            }
        }

        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
        persistentContainer.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    }

    public var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    // MARK: - Data Source Management

    /// Register a data source for use
    public func registerDataSource(_ dataSource: any DataSourceProtocol, withId id: String) {
        dataSources[id] = dataSource
    }

    /// Get a registered data source
    public func getDataSource(withId id: String) -> (any DataSourceProtocol)? {
        dataSources[id]
    }

    /// Get the data source config ID for a search execution
    public func getDataSourceConfigId(forExecutionId executionId: UUID) async throws -> UUID? {
        return try await viewContext.perform {
            let fetchRequest: NSFetchRequest<SearchExecution> = SearchExecution.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", executionId as CVarArg)

            guard let execution = try self.viewContext.fetch(fetchRequest).first,
                  let configId = execution.dataSourceConfig?.id else {
                return nil
            }

            return configId
        }
    }

    // MARK: - Dashboard Persistence

    /// Save a Dashboard Studio configuration to CoreData
    public func saveDashboard(
        _ config: DashboardStudioConfiguration,
        dataSourceConfigId: UUID? = nil,
        rawJSON: String? = nil
    ) async throws -> UUID {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump

        let dashboardId = try await context.perform {
            let dashboard = Dashboard(context: context)
            dashboard.id = UUID()
            dashboard.title = config.title
            dashboard.dashboardDescription = config.description
            dashboard.formatType = "dashboardStudio"
            dashboard.createdAt = Date()
            dashboard.updatedAt = Date()

            // Store raw JSON (prefer original from Splunk if provided)
            let encoder = JSONEncoder()
            if let rawJSON = rawJSON {
                dashboard.rawJSON = rawJSON
            } else {
                // Fallback: encode the config
                if let jsonData = try? encoder.encode(config),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    dashboard.rawJSON = jsonString
                }
            }

            // Store defaults
            if let defaults = config.defaults {
                if let defaultsData = try? encoder.encode(defaults),
                   let defaultsString = String(data: defaultsData, encoding: .utf8) {
                    dashboard.defaultsJSON = defaultsString
                }
            }

            // Save data sources
            for (sourceId, sourceDef) in config.dataSources {
                let dataSource = DataSource(context: context)
                dataSource.id = UUID()
                dataSource.sourceId = sourceId
                dataSource.name = sourceDef.name
                dataSource.type = sourceDef.type
                dataSource.query = sourceDef.options?.query
                dataSource.refresh = sourceDef.options?.refresh
                dataSource.refreshType = sourceDef.options?.refreshType
                dataSource.extendsId = sourceDef.options?.extend ?? sourceDef.extends
                dataSource.owner = sourceDef.options?.owner
                dataSource.app = sourceDef.options?.app

                if let options = sourceDef.options,
                   let optionsData = try? encoder.encode(options),
                   let optionsString = String(data: optionsData, encoding: .utf8) {
                    dataSource.optionsJSON = optionsString
                }

                dataSource.dashboard = dashboard
            }

            // Save visualizations
            for (vizId, vizDef) in config.visualizations {
                let viz = Visualization(context: context)
                viz.id = UUID()
                viz.vizId = vizId
                viz.type = vizDef.type
                viz.title = vizDef.title

                if let options = vizDef.options,
                   let optionsData = try? JSONSerialization.data(withJSONObject: options.mapValues { $0.value }),
                   let optionsString = String(data: optionsData, encoding: .utf8) {
                    viz.optionsJSON = optionsString
                }

                if let context = vizDef.context,
                   let contextData = try? JSONSerialization.data(withJSONObject: context.mapValues { $0.value }),
                   let contextString = String(data: contextData, encoding: .utf8) {
                    viz.contextJSON = contextString
                }

                // Link to primary data source
                if let primaryDS = vizDef.dataSources?.primary {
                    let fetchRequest: NSFetchRequest<DataSource> = DataSource.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "sourceId == %@ AND dashboard == %@", primaryDS, dashboard)
                    if let dataSource = try? context.fetch(fetchRequest).first {
                        viz.dataSource = dataSource
                    }
                }

                viz.dashboard = dashboard
            }

            // Save layout
            let layout = DashboardLayout(context: context)
            layout.id = UUID()
            layout.type = config.layout.type?.rawValue ?? "absolute"

            if let options = config.layout.options,
               let optionsData = try? JSONSerialization.data(withJSONObject: options.mapValues { $0.value }),
               let optionsString = String(data: optionsData, encoding: .utf8) {
                layout.optionsJSON = optionsString
            }

            layout.dashboard = dashboard

            // Save layout items (if structure exists - for converted SimpleXML)
            if let structure = config.layout.structure {
                for structureItem in structure {
                let layoutItem = LayoutItem(context: context)
                layoutItem.id = UUID()
                layoutItem.type = structureItem.type.rawValue
                layoutItem.x = Int32(structureItem.position.x ?? 0)
                layoutItem.y = Int32(structureItem.position.y ?? 0)
                layoutItem.width = Int32(structureItem.position.w ?? 0)
                layoutItem.height = Int32(structureItem.position.h ?? 0)
                layoutItem.bootstrapWidth = structureItem.position.width?.rawValue

                layoutItem.layout = layout

                // Link to visualization or input
                if structureItem.type == .block {
                    let fetchRequest: NSFetchRequest<Visualization> = Visualization.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "vizId == %@ AND dashboard == %@", structureItem.item, dashboard)
                    if let viz = try? context.fetch(fetchRequest).first {
                        layoutItem.visualization = viz
                    }
                }
            }
            }

            // Save inputs
            if let inputs = config.inputs {
                for (inputId, inputDef) in inputs {
                    let input = DashboardInput(context: context)
                    input.id = UUID()
                    input.inputId = inputId
                    input.type = inputDef.type
                    input.title = inputDef.title

                    // Extract token - check both top-level and options.token
                    if let token = inputDef.token {
                        input.token = token
                    } else if let options = inputDef.options,
                              let tokenValue = options["token"]?.value as? String {
                        input.token = tokenValue
                    }

                    // Extract defaultValue - check both top-level and options.defaultValue
                    if let defaultValue = inputDef.defaultValue {
                        input.defaultValue = defaultValue
                    } else if let options = inputDef.options,
                              let defaultValue = options["defaultValue"]?.value as? String {
                        input.defaultValue = defaultValue
                    }

                    if let options = inputDef.options,
                       let optionsData = try? JSONSerialization.data(withJSONObject: options.mapValues { $0.value }),
                       let optionsString = String(data: optionsData, encoding: .utf8) {
                        input.optionsJSON = optionsString
                    }

                    input.dashboard = dashboard
                }
            }

            try context.save()
            return dashboard.id!
        }

        // Populate saved search metadata after dashboard is saved
        if let configId = dataSourceConfigId {
            try await populateSavedSearchMetadata(dashboardId: dashboardId, dataSourceConfigId: configId)
        }

        return dashboardId
    }

    /// Save a SimpleXML configuration to CoreData
    public func saveDashboard(
        _ config: SimpleXMLConfiguration,
        dataSourceConfigId: UUID? = nil,
        rawXML: String? = nil
    ) async throws -> UUID {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump

        let dashboardId = try await context.perform { [config, rawXML] in
            return try self.saveSimpleXMLDashboardSync(
                config: config,
                rawXML: rawXML,
                context: context
            )
        }

        // Populate saved search metadata after dashboard is saved
        if let configId = dataSourceConfigId {
            try await populateSavedSearchMetadata(dashboardId: dashboardId, dataSourceConfigId: configId)
        }

        return dashboardId
    }

    // MARK: - SimpleXML Save Helper

    /// Synchronous helper to save SimpleXML dashboard entities
    private nonisolated func saveSimpleXMLDashboardSync(
        config: SimpleXMLConfiguration,
        rawXML: String?,
        context: NSManagedObjectContext
    ) throws -> UUID {
        let dashboard = Dashboard(context: context)
        dashboard.id = UUID()
        dashboard.title = config.label
        dashboard.dashboardDescription = config.description
        dashboard.formatType = "simpleXML"
        dashboard.createdAt = Date()
        dashboard.updatedAt = Date()
        dashboard.rawXML = rawXML

        // Create layout (bootstrap style)
        let layout = DashboardLayout(context: context)
        layout.id = UUID()
        layout.type = "bootstrap"
        layout.dashboard = dashboard

        var position = 0

        // Process rows and panels - delegate to existing code
        position = try processRowsAndPanels(
            config.rows,
            dashboard: dashboard,
            layout: layout,
            startPosition: position,
            context: context
        )

        // Process fieldsets
        position = try processFieldsets(
            config.fieldsets,
            dashboard: dashboard,
            layout: layout,
            startPosition: position,
            context: context
        )

        try context.save()
        return dashboard.id!
    }

    /// Process all rows and panels
    private nonisolated func processRowsAndPanels(
        _ rows: [SimpleXMLRow],
        dashboard: Dashboard,
        layout: DashboardLayout,
        startPosition: Int,
        context: NSManagedObjectContext
    ) throws -> Int {
        var position = startPosition

        for row in rows {
            // Calculate bootstrap width for panels in this row
            let panelsInRow = row.panels.count
            let bootstrapWidth = String(12 / max(panelsInRow, 1))

            for panel in row.panels {
                // Create data source if search exists
                if let search = panel.search {
                    position = try createPanelVisualization(
                        panel: panel,
                        search: search,
                        dashboard: dashboard,
                        layout: layout,
                        bootstrapWidth: bootstrapWidth,
                        position: position,
                        context: context
                    )
                }

                // Process panel-level inputs
                position = try processPanelInputs(
                    panel.inputs,
                    dashboard: dashboard,
                    layout: layout,
                    bootstrapWidth: bootstrapWidth,
                    startPosition: position,
                    context: context
                )
            }
        }

        return position
    }

    /// Create visualization for a panel
    private nonisolated func createPanelVisualization(
        panel: SimpleXMLPanel,
        search: SimpleXMLSearch,
        dashboard: Dashboard,
        layout: DashboardLayout,
        bootstrapWidth: String,
        position: Int,
        context: NSManagedObjectContext
    ) throws -> Int {
        let dataSource = DataSource(context: context)
        dataSource.id = UUID()
        dataSource.sourceId = search.id ?? "search_\(UUID().uuidString)"
        dataSource.type = "ds.search"
        dataSource.query = search.query
        dataSource.refresh = search.refresh
        dataSource.refreshType = search.refreshType
        dataSource.extendsId = search.base
        dataSource.dashboard = dashboard

        // Store earliest, latest, ref in optionsJSON
        var searchOptions: [String: Any] = [:]
        if let earliest = search.earliest {
            searchOptions["earliest"] = earliest
        }
        if let latest = search.latest {
            searchOptions["latest"] = latest
        }
        if let ref = search.ref {
            searchOptions["ref"] = ref
        }

        if !searchOptions.isEmpty,
           let optionsData = try? JSONSerialization.data(withJSONObject: searchOptions),
           let optionsString = String(data: optionsData, encoding: .utf8) {
            dataSource.optionsJSON = optionsString
        }

        // Create visualization
        let viz = Visualization(context: context)
        viz.id = UUID()
        viz.vizId = "viz_\(UUID().uuidString)"
        viz.type = "splunk.\(panel.visualization.type.rawValue)"
        viz.title = panel.title
        viz.dataSource = dataSource
        viz.dashboard = dashboard

        // Store visualization options and formats
        var vizOptions: [String: Any] = [:]

        // Add regular options
        if !panel.visualization.options.isEmpty {
            vizOptions["options"] = panel.visualization.options
        }

        // Add formats array
        if !panel.visualization.formats.isEmpty {
            print("💾 Storing \(panel.visualization.formats.count) format(s) for visualization")
            let formatsArray = panel.visualization.formats.map { format -> [String: Any] in
                var dict: [String: Any] = [:]
                for (key, value) in format {
                    dict[key] = unwrapAnyCodable(value)
                }
                return dict
            }
            vizOptions["formats"] = formatsArray
        }

        // Serialize to JSON and store
        if !vizOptions.isEmpty,
           let optionsData = try? JSONSerialization.data(withJSONObject: vizOptions),
           let optionsString = String(data: optionsData, encoding: .utf8) {
            viz.optionsJSON = optionsString
            print("💾 Stored optionsJSON: \(optionsString.prefix(200))...")
        }

        // Create layout item
        let layoutItem = LayoutItem(context: context)
        layoutItem.id = UUID()
        layoutItem.type = "block"
        layoutItem.bootstrapWidth = bootstrapWidth
        layoutItem.position = Int32(position)
        layoutItem.layout = layout
        layoutItem.visualization = viz

        return position + 1
    }

    /// Process panel inputs
    private nonisolated func processPanelInputs(
        _ inputs: [SimpleXMLInput],
        dashboard: Dashboard,
        layout: DashboardLayout,
        bootstrapWidth: String,
        startPosition: Int,
        context: NSManagedObjectContext
    ) throws -> Int {
        var position = startPosition

        for simpleInput in inputs {
            position = try createInputEntity(
                simpleInput: simpleInput,
                dashboard: dashboard,
                layout: layout,
                bootstrapWidth: bootstrapWidth,
                position: position,
                context: context,
                debugPrefix: "panel"
            )
        }

        return position
    }

    /// Process fieldsets
    private nonisolated func processFieldsets(
        _ fieldsets: [SimpleXMLFieldset]?,
        dashboard: Dashboard,
        layout: DashboardLayout,
        startPosition: Int,
        context: NSManagedObjectContext
    ) throws -> Int {
        guard let fieldsets = fieldsets else { return startPosition }

        var position = startPosition

        for fieldset in fieldsets {
            for simpleInput in fieldset.inputs {
                position = try createInputEntity(
                    simpleInput: simpleInput,
                    dashboard: dashboard,
                    layout: layout,
                    bootstrapWidth: "12",
                    position: position,
                    context: context,
                    debugPrefix: "fieldset"
                )
            }
        }

        return position
    }

    /// Create input entity with all options
    private nonisolated func createInputEntity(
        simpleInput: SimpleXMLInput,
        dashboard: Dashboard,
        layout: DashboardLayout,
        bootstrapWidth: String,
        position: Int,
        context: NSManagedObjectContext,
        debugPrefix: String
    ) throws -> Int {
        let input = DashboardInput(context: context)
        input.id = UUID()
        input.inputId = "input_\(UUID().uuidString)"
        input.type = "input.\(simpleInput.type.rawValue)"
        input.title = simpleInput.label
        input.token = simpleInput.token
        input.defaultValue = simpleInput.defaultValue
        input.dashboard = dashboard

        print("💾 Saving \(debugPrefix) input: \(simpleInput.token)")

        // Store choices and change handler in optionsJSON
        var inputOptions: [String: Any] = [:]

        if !simpleInput.choices.isEmpty {
            let choicesData = simpleInput.choices.map { choice -> [String: Any] in
                return [
                    "value": choice.value,
                    "label": choice.label
                ]
            }
            inputOptions["choices"] = choicesData
        }

        // Add change handler if present
        if let changeHandler = simpleInput.changeHandler {
            if let handlerData = try? JSONEncoder().encode(changeHandler),
               let handlerDict = try? JSONSerialization.jsonObject(with: handlerData) as? [String: Any] {
                inputOptions["changeHandler"] = handlerDict
                print("💾 Storing change handler for \(debugPrefix) input: \(simpleInput.token)")
            }
        }

        // Add formatting options if present
        if simpleInput.prefix != nil || simpleInput.suffix != nil || simpleInput.valuePrefix != nil ||
           simpleInput.valueSuffix != nil || simpleInput.delimiter != nil {
            print("💾 Storing formatting options for \(debugPrefix) input: \(simpleInput.token)")
            if let prefix = simpleInput.prefix {
                inputOptions["prefix"] = prefix
            }
            if let suffix = simpleInput.suffix {
                inputOptions["suffix"] = suffix
            }
            if let valuePrefix = simpleInput.valuePrefix {
                inputOptions["valuePrefix"] = valuePrefix
            }
            if let valueSuffix = simpleInput.valueSuffix {
                inputOptions["valueSuffix"] = valueSuffix
            }
            if let delimiter = simpleInput.delimiter {
                inputOptions["delimiter"] = delimiter
            }
        }

        // Create DataSource for input search if present
        if let inputSearch = simpleInput.search {
            let searchSourceId = "input_search_\(simpleInput.token)"
            let dataSource = DataSource(context: context)
            dataSource.id = UUID()
            dataSource.sourceId = searchSourceId
            dataSource.type = "ds.search"
            dataSource.query = inputSearch.query
            dataSource.refresh = inputSearch.refresh
            dataSource.refreshType = inputSearch.refreshType
            dataSource.dashboard = dashboard

            // Store earliest/latest in optionsJSON
            var searchOptions: [String: Any] = [:]
            if let earliest = inputSearch.earliest {
                searchOptions["earliest"] = earliest
            }
            if let latest = inputSearch.latest {
                searchOptions["latest"] = latest
            }
            if !searchOptions.isEmpty,
               let optionsData = try? JSONSerialization.data(withJSONObject: searchOptions),
               let optionsString = String(data: optionsData, encoding: .utf8) {
                dataSource.optionsJSON = optionsString
            }

            // Add search metadata to input options
            inputOptions["choiceSearch"] = [
                "sourceId": searchSourceId,
                "fieldForLabel": simpleInput.fieldForLabel ?? simpleInput.fieldForValue ?? "value",
                "fieldForValue": simpleInput.fieldForValue ?? "value"
            ]

            print("💾 Created DataSource for \(debugPrefix) input search: \(searchSourceId)")
        }

        if !inputOptions.isEmpty,
           let optionsData = try? JSONSerialization.data(withJSONObject: inputOptions),
           let optionsString = String(data: optionsData, encoding: .utf8) {
            input.optionsJSON = optionsString
        }

        // Create layout item for input
        let layoutItem = LayoutItem(context: context)
        layoutItem.id = UUID()
        layoutItem.type = "input"
        layoutItem.bootstrapWidth = bootstrapWidth
        layoutItem.position = Int32(position)
        layoutItem.layout = layout
        layoutItem.input = input

        return position + 1
    }

    // MARK: - Helper Functions

    /// Recursively unwrap AnyCodable to JSON-compatible types
    private nonisolated func unwrapAnyCodable(_ value: AnyCodable) -> Any {
        let unwrapped = value.value

        // Handle nested dictionaries
        if let dict = unwrapped as? [String: AnyCodable] {
            var result: [String: Any] = [:]
            for (key, val) in dict {
                result[key] = unwrapAnyCodable(val)
            }
            return result
        }

        // Handle arrays
        if let array = unwrapped as? [AnyCodable] {
            return array.map { unwrapAnyCodable($0) }
        }

        // Handle nested [String: Any] (already unwrapped one level)
        if let dict = unwrapped as? [String: Any] {
            var result: [String: Any] = [:]
            for (key, val) in dict {
                if let codable = val as? AnyCodable {
                    result[key] = unwrapAnyCodable(codable)
                } else {
                    result[key] = val
                }
            }
            return result
        }

        // Handle arrays of Any
        if let array = unwrapped as? [Any] {
            return array.map { item in
                if let codable = item as? AnyCodable {
                    return unwrapAnyCodable(codable)
                } else {
                    return item
                }
            }
        }

        // Return primitives as-is
        return unwrapped
    }

    // MARK: - Search Execution

    /// Execute a search and track its execution
    public func executeSearch(
        dataSourceId: UUID,
        query: String,
        parameters: SearchParameters,
        dataSourceConfigId: UUID
    ) async throws -> UUID {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump

        // Get the data source configuration (may be nil if using fallback config)
        let config = try await fetchDataSourceConfig(id: dataSourceConfigId)

        let configIdString = config?.id?.uuidString ?? dataSourceConfigId.uuidString

        // Get the registered data source
        guard let dataSource = dataSources[configIdString] else {
            print("❌ No data source registered for ID: \(configIdString)")
            print("   Available data sources: \(dataSources.keys.joined(separator: ", "))")
            throw CoreDataManagerError.dataSourceNotRegistered
        }

        // Execute the search
        let result = try await dataSource.executeSearch(query: query, parameters: parameters)

        // Track the execution
        return try await context.perform {
            let execution = SearchExecution(context: context)
            execution.id = UUID()
            execution.executionId = result.executionId
            execution.searchId = result.searchId
            execution.query = query
            execution.startTime = result.startTime
            execution.status = result.status.rawValue

            // Link to data source
            let fetchRequest: NSFetchRequest<DataSource> = DataSource.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", dataSourceId as CVarArg)
            if let ds = try? context.fetch(fetchRequest).first {
                execution.dataSource = ds
            }

            // Link to data source config
            let configFetchRequest: NSFetchRequest<DataSourceConfig> = DataSourceConfig.fetchRequest()
            configFetchRequest.predicate = NSPredicate(format: "id == %@", dataSourceConfigId as CVarArg)
            if let dsConfig = try? context.fetch(configFetchRequest).first {
                execution.dataSourceConfig = dsConfig
            }

            try context.save()
            return execution.id!
        }
    }

    /// Update search execution status and save results
    public func updateSearchExecution(
        executionId: UUID,
        status: SearchStatus,
        results: [SearchResultRow]? = nil,
        errorMessage: String? = nil
    ) async throws {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump

        try await context.perform {
            let fetchRequest: NSFetchRequest<SearchExecution> = SearchExecution.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", executionId as CVarArg)

            guard let execution = try context.fetch(fetchRequest).first else {
                throw CoreDataManagerError.executionNotFound
            }

            execution.status = status.rawValue
            execution.errorMessage = errorMessage

            if status == .completed || status == .failed {
                execution.endTime = Date()
            }

            // Save results if provided
            if let results = results {
                execution.resultCount = results.count

                for (index, row) in results.enumerated() {
                    let result = SearchResult(context: context)
                    result.id = UUID()
                    result.timestamp = row.timestamp
                    result.rowIndex = Int32(index)

                    if let jsonData = try? row.toJSON(),
                       let jsonString = String(data: jsonData, encoding: .utf8) {
                        result.resultJSON = jsonString
                    }

                    result.execution = execution
                }
            }

            try context.save()
        }
    }

    /// Fetch historical search results for a data source
    public func fetchSearchHistory(
        dataSourceId: UUID,
        limit: Int = 100
    ) async throws -> [SearchExecution] {
        let context = persistentContainer.viewContext

        let fetchRequest: NSFetchRequest<SearchExecution> = SearchExecution.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "dataSource.id == %@", dataSourceId as CVarArg)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]
        fetchRequest.fetchLimit = limit

        return try context.fetch(fetchRequest)
    }

    // MARK: - Data Source Configuration

    /// Save data source configuration
    public func saveDataSourceConfig(
        name: String,
        type: DataSourceType,
        host: String,
        port: Int,
        authToken: String? = nil,
        isDefault: Bool = false
    ) async throws -> UUID {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump

        return try await context.perform {
            let config = DataSourceConfig(context: context)
            config.id = UUID()
            config.name = name
            config.type = type.rawValue
            config.host = host
            config.port = Int32(port)
            config.authToken = authToken
            config.isDefault = isDefault
            config.createdAt = Date()

            try context.save()
            return config.id!
        }
    }

    private func fetchDataSourceConfig(id: UUID) async throws -> DataSourceConfig? {
        let context = persistentContainer.viewContext

        let fetchRequest: NSFetchRequest<DataSourceConfig> = DataSourceConfig.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        return try context.fetch(fetchRequest).first
    }

    // MARK: - Dashboard Refresh Support

    /// Fetch all dashboards
    public func fetchAllDashboards() async throws -> [Dashboard] {
        return try await viewContext.perform {
            let fetchRequest: NSFetchRequest<Dashboard> = Dashboard.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
            return try self.viewContext.fetch(fetchRequest)
        }
    }

    /// Get dashboard ID for a search execution
    public func getDashboardId(forExecutionId executionId: UUID) async throws -> UUID? {
        return try await viewContext.perform {
            let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "SearchExecution")
            fetchRequest.predicate = NSPredicate(format: "id == %@", executionId as CVarArg)
            fetchRequest.fetchLimit = 1

            guard let execution = try self.viewContext.fetch(fetchRequest).first,
                  let dataSource = execution.value(forKey: "dataSource") as? NSManagedObject,
                  let dashboard = dataSource.value(forKey: "dashboard") as? NSManagedObject,
                  let dashboardId = dashboard.value(forKey: "id") as? UUID else {
                return nil
            }

            return dashboardId
        }
    }

    /// Get chained searches that depend on a base search
    public func getChainedSearches(forBaseSearchId baseSearchId: String, in dashboardId: UUID) async throws -> [String] {
        return try await viewContext.perform {
            let fetchRequest: NSFetchRequest<DataSource> = DataSource.fetchRequest()
            fetchRequest.predicate = NSPredicate(
                format: "dashboard.id == %@ AND extendsId == %@",
                dashboardId as CVarArg,
                baseSearchId
            )

            let dataSources = try self.viewContext.fetch(fetchRequest)
            return dataSources.compactMap { $0.sourceId }
        }
    }

    /// Get searches with refresh intervals for a dashboard
    public func getSearchesWithRefresh(in dashboardId: UUID) async throws -> [(searchId: String, interval: TimeInterval)] {
        return try await viewContext.perform {
            let fetchRequest: NSFetchRequest<DataSource> = DataSource.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "dashboard.id == %@", dashboardId as CVarArg)

            let dataSources = try self.viewContext.fetch(fetchRequest)

            return dataSources.compactMap { ds -> (String, TimeInterval)? in
                // Skip chained searches - they should only execute when their base search completes
                guard ds.extendsId == nil else {
                    return nil
                }

                guard let sourceId = ds.sourceId,
                      let refreshString = ds.refresh,
                      let interval = self.parseRefreshInterval(refreshString) else {
                    return nil
                }
                return (sourceId, interval)
            }
        }
    }

    /// Populate saved search metadata (owner, app) for a dashboard's data sources
    /// This should be called once after syncing a dashboard to fetch metadata from Splunk
    public func populateSavedSearchMetadata(dashboardId: UUID, dataSourceConfigId: UUID) async throws {
        // First, fetch data sources that need metadata population
        let dataSourcesNeedingMetadata: [(objectID: NSManagedObjectID, ref: String)] = try await viewContext.perform {
            let dashboardFetch: NSFetchRequest<Dashboard> = Dashboard.fetchRequest()
            dashboardFetch.predicate = NSPredicate(format: "id == %@", dashboardId as CVarArg)
            guard let dashboard = try? self.viewContext.fetch(dashboardFetch).first else {
                print("⚠️ Dashboard not found for metadata population")
                return []
            }

            guard let dataSources = dashboard.dataSources?.allObjects as? [DataSource] else {
                return []
            }

            var result: [(NSManagedObjectID, String)] = []
            for dataSource in dataSources {
                guard let optionsJSON = dataSource.optionsJSON,
                      let data = optionsJSON.data(using: .utf8),
                      let options = try? JSONDecoder().decode(DataSourceOptions.self, from: data),
                      let ref = options.ref,
                      dataSource.owner == nil || dataSource.app == nil else {
                    continue
                }
                result.append((dataSource.objectID, ref))
            }
            return result
        }

        guard !dataSourcesNeedingMetadata.isEmpty else {
            print("ℹ️ No saved searches need metadata population")
            return
        }

        // Get Splunk data source for fetching metadata
        guard let splunkDataSource = await getDataSource(withId: dataSourceConfigId.uuidString) as? SplunkDataSource else {
            print("⚠️ No SplunkDataSource available for metadata fetch")
            return
        }

        // Fetch metadata for each saved search
        var updates: [(objectID: NSManagedObjectID, owner: String, app: String)] = []
        for (objectID, ref) in dataSourcesNeedingMetadata {
            print("🔍 Fetching metadata for saved search: \(ref)")
            do {
                let metadata = try await splunkDataSource.fetchSavedSearchMetadata(ref: ref)
                updates.append((objectID, metadata.owner, metadata.app))
                print("✅ Fetched metadata for \(ref): owner=\(metadata.owner), app=\(metadata.app)")
            } catch {
                print("❌ Failed to fetch metadata for \(ref): \(error)")
                // Use defaults if fetch fails
                updates.append((objectID, "admin", "search"))
            }
        }

        // Update CoreData with fetched metadata
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        try await context.perform {
            for (objectID, owner, app) in updates {
                if let dataSource = try? context.existingObject(with: objectID) as? DataSource {
                    dataSource.owner = owner
                    dataSource.app = app
                }
            }
            try context.save()
            print("✅ Saved metadata updates for \(updates.count) saved search(es)")
        }
    }

    /// Start a search execution (for refresh worker and scheduled searches)
    public func startSearchExecution(
        searchId: String,
        in dashboardId: UUID,
        userTokenValues: [String: String],
        timeRange: (earliest: String, latest: String)?,
        parameterOverrides: [String: String],
        credentials: (host: String, port: Int, token: String)?,
        baseExecutionId: String? = nil  // Splunk SID of base search for chained searches
    ) async throws -> UUID {
        let context = persistentContainer.newBackgroundContext()
        // Use merge policy to handle concurrent saves gracefully
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump

        // Find the dashboard and data source
        let (dataSourceEntityId, query, configId, configHost, configPort, configToken, extractedEarliest, extractedLatest) = try await context.perform {
            // Find the dashboard
            let dashboardFetch: NSFetchRequest<Dashboard> = Dashboard.fetchRequest()
            dashboardFetch.predicate = NSPredicate(format: "id == %@", dashboardId as CVarArg)
            guard let dashboard = try? context.fetch(dashboardFetch).first else {
                throw CoreDataManagerError.dashboardNotFound
            }

            // Find the data source with matching sourceId
            guard let dataSources = dashboard.dataSources?.allObjects as? [DataSource],
                  let dataSource = dataSources.first(where: { $0.sourceId == searchId }) else {
                throw CoreDataManagerError.dataSourceNotFound
            }

            // Get the query and apply token substitutions
            var query = dataSource.query ?? ""

            // Apply token substitutions
            for (token, value) in userTokenValues {
                query = query.replacingOccurrences(of: "$\(token)$", with: value)
            }

            // Apply parameter overrides
            for (param, value) in parameterOverrides {
                query = query.replacingOccurrences(of: "$\(param)$", with: value)
            }

            // Normalize query based on search type
            let extendsId = dataSource.extendsId

            // Extract ref and time range from optionsJSON
            var ref: String?
            var extractedEarliest: String?
            var extractedLatest: String?

            if let json = dataSource.optionsJSON,
               let data = json.data(using: .utf8) {
                // Try new format first (nested under queryParameters)
                if let options = try? JSONDecoder().decode(DataSourceOptions.self, from: data) {
                    ref = options.ref
                    extractedEarliest = options.queryParameters?.earliest
                    extractedLatest = options.queryParameters?.latest
                }

                // Fall back to legacy flat format if new format didn't have time range
                if extractedEarliest == nil || extractedLatest == nil,
                   let legacyDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    extractedEarliest = extractedEarliest ?? (legacyDict["earliest"] as? String)
                    extractedLatest = extractedLatest ?? (legacyDict["latest"] as? String)
                }

                print("📅 Extracted time range from DataSource: earliest=\(extractedEarliest ?? "nil"), latest=\(extractedLatest ?? "nil")")
            } else {
                print("⚠️ Failed to decode optionsJSON: \(dataSource.optionsJSON ?? "nil")")
            }

            // Process query based on type
            if let ref = ref {
                // This is a saved search reference
                if let refresh = dataSource.refresh, !refresh.isEmpty {
                    // Has refresh interval = scheduled search, use loadjob with owner:app:ref format
                    let owner = dataSource.owner ?? "admin"
                    let app = dataSource.app ?? "search"
                    query = "| loadjob savedsearch=\"\(owner):\(app):\(ref)\" artifact_offset=\"0\" "
                    print("📦 Using saved search loadjob: \(query)")
                } else {
                    // No refresh = regular saved search
                    query = "| savedsearch \(ref)"
                }
            } else if let base = extendsId {
                // This is a chained search (post-processing)
                // Prepend with loadjob to load base search results
                if let baseSid = baseExecutionId {
                    // Ensure post-processing query starts with |
                    let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
                    if !trimmedQuery.starts(with: "|") {
                        query = "| " + trimmedQuery
                    }
                    // Prepend loadjob command
                    query = "| loadjob \(baseSid) \(query)"
                    print("🔗 Chained search query with loadjob: \(query)")
                } else {
                    print("⚠️ Chained search (extends: \(base)) started without baseExecutionId - results may be empty")
                    // Query must start with | for post-processing
                    if !query.trimmingCharacters(in: .whitespaces).starts(with: "|") {
                        query = "| " + query
                    }
                }
            } else {
                // Regular search - ensure it starts with search or |
                let trimmed = query.trimmingCharacters(in: .whitespaces)
                if !trimmed.starts(with: "search ") && !trimmed.starts(with: "|") {
                    query = "search " + query
                }
            }

            // Get or create DataSourceConfig
            var dataSourceConfig: DataSourceConfig?
            var configHost: String
            var configPort: Int
            var configToken: String?

            if let creds = credentials {
                // Use provided credentials
                configHost = creds.host
                configPort = creds.port
                configToken = creds.token

                // Try to find or create config entity
                let configFetch: NSFetchRequest<DataSourceConfig> = DataSourceConfig.fetchRequest()
                configFetch.predicate = NSPredicate(format: "host == %@ AND port == %d", creds.host, Int32(creds.port))

                if let existingConfig = try? context.fetch(configFetch).first {
                    dataSourceConfig = existingConfig
                } else {
                    let newConfig = DataSourceConfig(context: context)
                    newConfig.id = UUID()
                    newConfig.name = "Auto-generated config for \(creds.host)"
                    newConfig.type = "splunk"
                    newConfig.host = creds.host
                    newConfig.port = Int32(creds.port)
                    newConfig.authToken = creds.token
                    newConfig.isDefault = false
                    newConfig.createdAt = Date()
                    dataSourceConfig = newConfig

                    do {
                        try context.save()
                    } catch {
                        // Handle race condition: refetch in case another context created it
                        if let existingConfig = try? context.fetch(configFetch).first {
                            print("ℹ️ Config for \(creds.host):\(creds.port) created by another context, using existing")
                            dataSourceConfig = existingConfig
                        } else {
                            throw error
                        }
                    }
                }
            } else {
                // Try to get default config from CoreData
                let configFetch: NSFetchRequest<DataSourceConfig> = DataSourceConfig.fetchRequest()
                configFetch.predicate = NSPredicate(format: "isDefault == YES")
                if let defaultConfig = try? context.fetch(configFetch).first {
                    dataSourceConfig = defaultConfig
                    configHost = defaultConfig.host ?? "localhost"
                    configPort = Int(defaultConfig.port)
                    configToken = defaultConfig.authToken
                } else {
                    // Fall back to UserDefaults - create a default DataSourceConfig
                    let baseURLString = UserDefaults.standard.string(forKey: "splunkBaseURL") ?? "https://localhost:8089"

                    // Extract host and port from URL
                    if let url = URL(string: baseURLString) {
                        configHost = url.host ?? "localhost"
                        configPort = url.port ?? 8089
                    } else {
                        // Not a valid URL, might be just "hostname:port" format
                        let components = baseURLString.components(separatedBy: ":")
                        configHost = components.first ?? "localhost"
                        configPort = components.count > 1 ? Int(components[1]) ?? 8089 : 8089
                    }

                    print("📍 Creating default config: baseURL=\(baseURLString) → host=\(configHost), port=\(configPort)")

                    // Create a default DataSourceConfig from UserDefaults
                    let newDefaultConfig = DataSourceConfig(context: context)
                    newDefaultConfig.id = UUID()
                    newDefaultConfig.name = "Default Splunk Config"
                    newDefaultConfig.type = "splunk"
                    newDefaultConfig.host = configHost
                    newDefaultConfig.port = Int32(configPort)
                    newDefaultConfig.isDefault = true
                    newDefaultConfig.createdAt = Date()

                    // Will try to get token from CredentialManager in the calling code
                    configToken = nil
                    dataSourceConfig = newDefaultConfig

                    do {
                        try context.save()
                    } catch {
                        // Handle race condition: another context may have created default config
                        // Refetch to get the one that was saved
                        let retryFetch: NSFetchRequest<DataSourceConfig> = DataSourceConfig.fetchRequest()
                        retryFetch.predicate = NSPredicate(format: "isDefault == YES")
                        if let existingDefault = try? context.fetch(retryFetch).first {
                            print("ℹ️ Default config created by another context, using existing")
                            dataSourceConfig = existingDefault
                            configHost = existingDefault.host ?? "localhost"
                            configPort = Int(existingDefault.port)
                            configToken = existingDefault.authToken
                        } else {
                            // Still failed, propagate error
                            throw error
                        }
                    }
                }
            }

            guard let dsId = dataSource.id else {
                throw CoreDataManagerError.dataSourceNotFound
            }

            return (dsId, query, dataSourceConfig?.id ?? UUID(), configHost, configPort, configToken, extractedEarliest, extractedLatest)
        }

        // Get auth token from CredentialManager if not provided
        var finalToken = configToken
        if finalToken == nil {
            // Try to get from CredentialManager
            do {
                finalToken = try await CredentialManager.shared.retrieveAuthToken(host: configHost)
                print("✅ Retrieved auth token from Keychain for \(configHost)")
            } catch {
                // Fall back to UserDefaults (like the working sync code does)
                if let storedToken = UserDefaults.standard.string(forKey: "splunkToken"), !storedToken.isEmpty {
                    finalToken = storedToken
                    print("✅ Using auth token from UserDefaults")
                } else {
                    print("⚠️ No auth token found for \(configHost), will attempt unauthenticated connection")
                }
            }
        }

        // Get SSL validation setting from UserDefaults (default to true if not set)
        let validateSSL: Bool
        if UserDefaults.standard.object(forKey: "splunkValidateSSL") != nil {
            validateSSL = UserDefaults.standard.bool(forKey: "splunkValidateSSL")
        } else {
            validateSSL = true // Default to secure
        }

        let useSSLProtocol = configHost.starts(with: "https") || configPort == 8089

        print("🔒 SSL Configuration: useSSL=\(useSSLProtocol), validateSSL=\(validateSSL)")

        // Check if we already have a SplunkDataSource for this config (reuse for connection pooling)
        let splunkDataSource: SplunkDataSource
        if let existingDataSource = getDataSource(withId: configId.uuidString) as? SplunkDataSource {
            // Reuse existing DataSource to preserve URLSession and connection pool
            print("♻️ Reusing existing SplunkDataSource for config \(configId) (preserves connection pool)")
            splunkDataSource = existingDataSource
        } else {
            // No existing DataSource - create new one
            print("🆕 Creating new SplunkDataSource for config \(configId)")
            splunkDataSource = SplunkDataSource(
                host: configHost,
                port: configPort,
                authToken: finalToken,
                useSSL: useSSLProtocol,
                validateSSL: validateSSL
            )
            registerDataSource(splunkDataSource, withId: configId.uuidString)
        }

        // Build search parameters
        // Use timeRange parameter if provided, otherwise use extracted values from DataSource
        var finalEarliest = timeRange?.earliest ?? extractedEarliest
        var finalLatest = timeRange?.latest ?? extractedLatest

        // Apply token substitutions to time range values
        if let earliest = finalEarliest {
            var substituted = earliest
            for (token, value) in userTokenValues {
                substituted = substituted.replacingOccurrences(of: "$\(token)$", with: value)
            }
            finalEarliest = substituted
            if substituted != earliest {
                print("🎛️ Substituted earliest: '\(earliest)' → '\(substituted)'")
            }
        }
        if let latest = finalLatest {
            var substituted = latest
            for (token, value) in userTokenValues {
                substituted = substituted.replacingOccurrences(of: "$\(token)$", with: value)
            }
            finalLatest = substituted
            if substituted != latest {
                print("🎛️ Substituted latest: '\(latest)' → '\(substituted)'")
            }
        }

        let parameters = SearchParameters(
            earliestTime: finalEarliest,
            latestTime: finalLatest,
            maxResults: nil,
            timeout: nil,
            tokens: userTokenValues
        )

        // Now actually execute the search using the existing executeSearch method
        print("📊 Starting search execution for searchId: \(searchId)")
        print("   Query: \(query)")
        print("   Config: \(configHost):\(configPort)")

        return try await executeSearch(
            dataSourceId: dataSourceEntityId,
            query: query,
            parameters: parameters,
            dataSourceConfigId: configId
        )
    }

    /// Parse refresh interval string (e.g., "2m", "30s", "1h") to TimeInterval
    private func parseRefreshInterval(_ refresh: String) -> TimeInterval? {
        let trimmed = refresh.trimmingCharacters(in: .whitespaces).lowercased()

        // Match patterns like "30s", "2m", "1h"
        let pattern = #"^(\d+)([smh])$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
              match.numberOfRanges == 3 else {
            return nil
        }

        // Extract number and unit
        guard let numberRange = Range(match.range(at: 1), in: trimmed),
              let unitRange = Range(match.range(at: 2), in: trimmed),
              let number = Int(trimmed[numberRange]) else {
            return nil
        }

        let unit = String(trimmed[unitRange])

        // Convert to seconds
        switch unit {
        case "s":
            return TimeInterval(number)
        case "m":
            return TimeInterval(number * 60)
        case "h":
            return TimeInterval(number * 3600)
        default:
            return nil
        }
    }

    // MARK: - Input Search Results Processing

    /// Process completed input search results and populate dynamic choices
    /// This should be called after input searches complete to extract field values
    public func processInputSearchResults(dashboardId: UUID) async throws {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump

        var didSaveChanges = false

        try await context.perform {
            // Find the dashboard
            let dashboardFetch: NSFetchRequest<Dashboard> = Dashboard.fetchRequest()
            dashboardFetch.predicate = NSPredicate(format: "id == %@", dashboardId as CVarArg)
            guard let dashboard = try? context.fetch(dashboardFetch).first else {
                print("⚠️ Dashboard not found for input search processing")
                return
            }

            // Get all inputs for this dashboard
            guard let allInputs = dashboard.inputs?.allObjects as? [DashboardInput] else {
                return
            }

            // Process each input that has choiceSearch configuration
            for input in allInputs {
                try self.processInputSearchResult(input: input, dashboard: dashboard, context: context)
            }

            // Save changes
            if context.hasChanges {
                try context.save()
                print("✅ Processed input search results for dashboard '\(dashboard.title ?? "unknown")'")
                didSaveChanges = true
            }
        }

        // Post notification on main thread if changes were saved
        if didSaveChanges {
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .inputSearchResultsProcessed,
                    object: nil,
                    userInfo: ["dashboardId": dashboardId.uuidString]
                )
            }
        }
    }

    /// Process a single input's search results
    private nonisolated func processInputSearchResult(input: DashboardInput, dashboard: Dashboard, context: NSManagedObjectContext) throws {
        // Parse optionsJSON to check for choiceSearch
        guard let optionsJSON = input.optionsJSON,
              let data = optionsJSON.data(using: .utf8),
              let options = try? JSONDecoder().decode([String: AnyCodable].self, from: data),
              let choiceSearchData = options["choiceSearch"],
              let choiceSearchDict = choiceSearchData.value as? [String: Any],
              let sourceId = choiceSearchDict["sourceId"] as? String else {
            return  // No choiceSearch configuration
        }

        let fieldForLabel = choiceSearchDict["fieldForLabel"] as? String ?? "value"
        let fieldForValue = choiceSearchDict["fieldForValue"] as? String ?? "value"

        // Find the DataSource for this input search
        guard let dataSources = dashboard.dataSources?.allObjects as? [DataSource],
              let dataSource = dataSources.first(where: { $0.sourceId == sourceId }) else {
            print("⚠️ DataSource '\(sourceId)' not found for input '\(input.token ?? "unknown")'")
            return
        }

        // Find the most recent completed search execution for this DataSource
        guard let executions = dataSource.executions?.allObjects as? [SearchExecution] else {
            print("⚠️ No search executions found for input '\(input.token ?? "unknown")'")
            return
        }

        let completedExecutions = executions.filter { $0.status == "completed" }
        let sortedExecutions = completedExecutions.sorted { ($0.endTime ?? Date.distantPast) > ($1.endTime ?? Date.distantPast) }

        guard let latestExecution = sortedExecutions.first,
              let results = latestExecution.results?.allObjects as? [SearchResult] else {
            print("⚠️ No completed search results found for input '\(input.token ?? "unknown")'")
            return
        }

        print("🔄 Processing \(results.count) search results for input '\(input.token ?? "unknown")'")

        // Extract choices from search results
        var dynamicChoices: [[String: Any]] = []
        for result in results.sorted(by: { $0.rowIndex < $1.rowIndex }) {
            guard let resultJSON = result.resultJSON,
                  let resultData = resultJSON.data(using: String.Encoding.utf8),
                  let resultDict = try? JSONSerialization.jsonObject(with: resultData) as? [String: Any] else {
                continue
            }

            // Extract the specified fields
            let labelValue = resultDict[fieldForLabel] as? String ?? ""
            let choiceValue = resultDict[fieldForValue] as? String ?? labelValue

            if !choiceValue.isEmpty {
                dynamicChoices.append([
                    "label": labelValue,
                    "value": choiceValue
                ])
            }
        }

        // Merge with existing static choices
        var updatedOptions = options
        var allChoices: [[String: Any]] = []

        // Add static choices first
        if let existingChoices = options["choices"]?.value as? [[String: Any]] {
            allChoices.append(contentsOf: existingChoices)
        }

        // Add dynamic choices (avoiding duplicates by value)
        let existingValues = Set(allChoices.compactMap { $0["value"] as? String })
        for choice in dynamicChoices {
            if let value = choice["value"] as? String, !existingValues.contains(value) {
                allChoices.append(choice)
            }
        }

        // Update options with merged choices
        updatedOptions["choices"] = AnyCodable(allChoices)

        // Serialize back to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        if let updatedData = try? encoder.encode(updatedOptions),
           let updatedJSON = String(data: updatedData, encoding: .utf8) {
            input.optionsJSON = updatedJSON
            print("✅ Updated input '\(input.token ?? "unknown")' with \(dynamicChoices.count) dynamic choices (total: \(allChoices.count))")
        }
    }
}

/// CoreDataManager error types
public enum CoreDataManagerError: Error, CustomStringConvertible {
    case dashboardNotFound
    case dataSourceNotFound
    case dataSourceConfigNotFound
    case dataSourceNotRegistered
    case executionNotFound
    case saveFailed(message: String)
    case invalidConfiguration
    case configNotFound

    public var description: String {
        switch self {
        case .dashboardNotFound:
            return "Dashboard not found"
        case .dataSourceNotFound:
            return "Data source not found"
        case .dataSourceConfigNotFound:
            return "Data source configuration not found"
        case .dataSourceNotRegistered:
            return "Data source not registered with manager"
        case .executionNotFound:
            return "Search execution not found"
        case .saveFailed(let message):
            return "Save failed: \(message)"
        case .invalidConfiguration:
            return "Invalid configuration"
        case .configNotFound:
            return "Configuration not found"
        }
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    /// Posted when input search results have been processed and choices updated
    static let inputSearchResultsProcessed = Notification.Name("inputSearchResultsProcessed")
}
