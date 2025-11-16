import Foundation

/// Main entry point for DashboardKit framework
///
/// This framework provides comprehensive support for dashboard management across
/// multiple formats and data sources, including Splunk Dashboard Studio, SimpleXML,
/// and extensible support for Elastic and Prometheus.
///
/// ## Features
///
/// - Parse Dashboard Studio JSON format (Splunk 10+)
/// - Parse legacy SimpleXML dashboards
/// - Convert between formats
/// - Store dashboards in CoreData with full fidelity
/// - Track search executions and historical results
/// - Support multiple data sources (Splunk, Elastic, Prometheus)
/// - Handle both absolute/grid and bootstrap layouts
///
/// ## Usage
///
/// ```swift
/// // Parse a Dashboard Studio dashboard
/// let parser = await DashboardStudioParser()
/// let config = try await parser.parse(jsonString)
///
/// // Save to CoreData
/// let manager = await CoreDataManager.shared
/// let dashboardId = try await manager.saveDashboard(config)
///
/// // Register a data source
/// let splunk = await SplunkDataSource(
///     host: "splunk.example.com",
///     authToken: "your-token"
/// )
/// await manager.registerDataSource(splunk, withId: "splunk-prod")
///
/// // Execute a search
/// let executionId = try await manager.executeSearch(
///     dataSourceId: dataSourceId,
///     query: "search index=main | stats count",
///     parameters: SearchParameters(),
///     dataSourceConfigId: configId
/// )
/// ```
///
public struct DashboardKit {
    public static let version = "1.0.0"

    /// Initialize the framework
    public static func initialize() async {
        // Ensure CoreDataManager is initialized
        _ = await CoreDataManager.shared
    }
}

// MARK: - Public Exports

// Models
public typealias DashboardConfig = DashboardStudioConfiguration
public typealias SimpleXMLConfig = SimpleXMLConfiguration

// Parsers
public typealias StudioParser = DashboardStudioParser
public typealias XMLParser = SimpleXMLParser

// Managers
public typealias DashboardManager = CoreDataManager

// Data Sources
public typealias SplunkSource = SplunkDataSource

// Converters
public typealias Converter = DashboardConverter
