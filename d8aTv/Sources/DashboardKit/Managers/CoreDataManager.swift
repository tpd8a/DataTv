import Foundation
import CoreData

/// Background worker that manages CoreData persistence and search execution tracking
public actor CoreDataManager {
    public static let shared = CoreDataManager()

    private let persistentContainer: NSPersistentContainer
    private var dataSources: [String: any DataSourceProtocol] = [:]

    // MARK: - Initialization

    private init() {
        persistentContainer = NSPersistentContainer(name: "DashboardModel")

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
        persistentContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
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

    // MARK: - Dashboard Persistence

    /// Save a Dashboard Studio configuration to CoreData
    public func saveDashboard(
        _ config: DashboardStudioConfiguration,
        dataSourceConfigId: UUID? = nil
    ) async throws -> UUID {
        let context = persistentContainer.newBackgroundContext()

        return try await context.perform {
            let dashboard = Dashboard(context: context)
            dashboard.id = UUID()
            dashboard.title = config.title
            dashboard.dashboardDescription = config.description
            dashboard.formatType = "dashboardStudio"
            dashboard.createdAt = Date()
            dashboard.updatedAt = Date()

            // Store raw JSON
            let encoder = JSONEncoder()
            if let jsonData = try? encoder.encode(config),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                dashboard.rawJSON = jsonString
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
                dataSource.extendsId = sourceDef.extends

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
            layout.type = config.layout.type.rawValue

            if let options = config.layout.options,
               let optionsData = try? JSONSerialization.data(withJSONObject: options.mapValues { $0.value }),
               let optionsString = String(data: optionsData, encoding: .utf8) {
                layout.optionsJSON = optionsString
            }

            layout.dashboard = dashboard

            // Save layout items
            for structureItem in config.layout.structure {
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

            // Save inputs
            if let inputs = config.inputs {
                for (inputId, inputDef) in inputs {
                    let input = DashboardInput(context: context)
                    input.id = UUID()
                    input.inputId = inputId
                    input.type = inputDef.type
                    input.title = inputDef.title
                    input.token = inputDef.token
                    input.defaultValue = inputDef.defaultValue

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
    }

    /// Save a SimpleXML configuration to CoreData
    public func saveDashboard(
        _ config: SimpleXMLConfiguration,
        dataSourceConfigId: UUID? = nil
    ) async throws -> UUID {
        let context = persistentContainer.newBackgroundContext()

        return try await context.perform {
            let dashboard = Dashboard(context: context)
            dashboard.id = UUID()
            dashboard.title = config.label
            dashboard.dashboardDescription = config.description
            dashboard.formatType = "simpleXML"
            dashboard.createdAt = Date()
            dashboard.updatedAt = Date()

            // Create layout (bootstrap style)
            let layout = DashboardLayout(context: context)
            layout.id = UUID()
            layout.type = "bootstrap"
            layout.dashboard = dashboard

            var position = 0

            // Process rows and panels
            for row in config.rows {
                for panel in row.panels {
                    // Create data source if search exists
                    if let search = panel.search {
                        let dataSource = DataSource(context: context)
                        dataSource.id = UUID()
                        dataSource.sourceId = "search_\(UUID().uuidString)"
                        dataSource.type = "ds.search"
                        dataSource.query = search.query
                        dataSource.refresh = search.refresh
                        dataSource.refreshType = search.refreshType
                        dataSource.dashboard = dashboard

                        // Create visualization
                        let viz = Visualization(context: context)
                        viz.id = UUID()
                        viz.vizId = "viz_\(UUID().uuidString)"
                        viz.type = "splunk.\(panel.visualization.type.rawValue)"
                        viz.title = panel.title
                        viz.dataSource = dataSource
                        viz.dashboard = dashboard

                        // Create layout item
                        let layoutItem = LayoutItem(context: context)
                        layoutItem.id = UUID()
                        layoutItem.type = "block"
                        layoutItem.bootstrapWidth = "12" // Full width by default
                        layoutItem.position = Int32(position)
                        layoutItem.layout = layout
                        layoutItem.visualization = viz

                        position += 1
                    }
                }
            }

            // Process inputs
            if let fieldsets = config.fieldsets {
                for fieldset in fieldsets {
                    for simpleInput in fieldset.inputs {
                        let input = DashboardInput(context: context)
                        input.id = UUID()
                        input.inputId = "input_\(UUID().uuidString)"
                        input.type = "input.\(simpleInput.type.rawValue)"
                        input.title = simpleInput.label
                        input.token = simpleInput.token
                        input.defaultValue = simpleInput.defaultValue
                        input.dashboard = dashboard

                        // Create layout item for input
                        let layoutItem = LayoutItem(context: context)
                        layoutItem.id = UUID()
                        layoutItem.type = "input"
                        layoutItem.bootstrapWidth = "12"
                        layoutItem.position = Int32(position)
                        layoutItem.layout = layout
                        layoutItem.input = input

                        position += 1
                    }
                }
            }

            try context.save()
            return dashboard.id!
        }
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

        // Get the data source configuration
        guard let config = try await fetchDataSourceConfig(id: dataSourceConfigId) else {
            throw CoreDataManagerError.dataSourceConfigNotFound
        }

        // Get the registered data source
        guard let dataSource = dataSources[config.id!.uuidString] else {
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
                execution.resultCount = Int64(results.count)

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
}

/// CoreDataManager error types
public enum CoreDataManagerError: Error, CustomStringConvertible {
    case dataSourceConfigNotFound
    case dataSourceNotRegistered
    case executionNotFound
    case saveFailed(message: String)

    public var description: String {
        switch self {
        case .dataSourceConfigNotFound:
            return "Data source configuration not found"
        case .dataSourceNotRegistered:
            return "Data source not registered with manager"
        case .executionNotFound:
            return "Search execution not found"
        case .saveFailed(let message):
            return "Save failed: \(message)"
        }
    }
}
