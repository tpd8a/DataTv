# DashboardKit

A ground-up Swift framework for managing dashboards from multiple sources and formats. Supports Splunk Dashboard Studio, legacy SimpleXML, and extensible architecture for Elastic and Prometheus dashboards with comprehensive CoreData persistence.

## Overview

DashboardKit is a Swift 6 framework designed for macOS v26 and tvOS v26 that provides:

- **Dashboard Studio Support**: Parse, validate, and manage Splunk 10+ Dashboard Studio JSON format
- **Legacy SimpleXML Support**: Full backward compatibility with SimpleXML dashboards
- **Format Conversion**: Bidirectional conversion between Dashboard Studio and SimpleXML
- **CoreData Persistence**: Robust storage of dashboard configurations with full fidelity
- **Execution Tracking**: Historical tracking of search executions and results
- **Multi-Source Support**: Modular architecture supporting Splunk, Elastic, and Prometheus
- **Layout Systems**: Support for both absolute/grid positioning and bootstrap-style layouts

## Architecture

### CoreData Schema

The framework uses a comprehensive CoreData model with the following entities:

- **Dashboard**: Top-level dashboard configuration (title, description, format type)
- **DataSource**: SPL queries and search definitions (supports chaining with `ds.chain`)
- **Visualization**: Chart, table, single value, and other visualization types
- **DashboardLayout**: Layout configuration (absolute, grid, or bootstrap)
- **LayoutItem**: Individual positioning for visualizations and inputs
- **DashboardInput**: Time pickers, dropdowns, and other input controls
- **SearchExecution**: Tracks when searches are executed with execution IDs
- **SearchResult**: Historical results from searches (enables timeline features)
- **DataSourceConfig**: Splunk/Elastic/Prometheus instance configurations

### Key Components

#### Parsers

- **DashboardStudioParser**: Parse Dashboard Studio JSON format (Splunk 10+)
  - Supports CDATA-wrapped XML format for deployment
  - Full validation of data source references and layout structure
  - Serialization back to JSON

- **SimpleXMLParser**: Parse legacy SimpleXML dashboards
  - Bootstrap-style layout parsing
  - Fieldset and input handling
  - Panel and visualization extraction

#### Data Sources

- **DataSourceProtocol**: Protocol for data source implementations
- **SplunkDataSource**: Full Splunk REST API implementation
  - Search job creation
  - Status monitoring
  - Result retrieval
  - Token substitution

Easily extensible for Elastic and Prometheus.

#### Managers

- **CoreDataManager**: Background worker for CoreData operations
  - Dashboard persistence (both formats)
  - Search execution tracking
  - Historical result storage
  - Data source registration

#### Converters

- **DashboardConverter**: Convert between formats
  - SimpleXML → Dashboard Studio
  - Dashboard Studio → SimpleXML (lossy)
  - Type mapping and layout conversion

## Usage

### Parsing a Dashboard Studio Dashboard

```swift
import DashboardKit

// Initialize framework
await DashboardKit.initialize()

// Parse Dashboard Studio JSON
let parser = await DashboardStudioParser()
let config = try await parser.parse(jsonString)

// Validate configuration
try await parser.validate(config)

// Save to CoreData
let manager = await CoreDataManager.shared
let dashboardId = try await manager.saveDashboard(config)
```

### Parsing a SimpleXML Dashboard

```swift
import DashboardKit

// Parse SimpleXML
let parser = await SimpleXMLParser()
let config = try await parser.parse(xmlString)

// Convert to Dashboard Studio format
let converter = DashboardConverter()
let studioConfig = converter.convertToStudio(config)

// Save to CoreData
let manager = await CoreDataManager.shared
let dashboardId = try await manager.saveDashboard(studioConfig)
```

### Executing Searches with Tracking

```swift
import DashboardKit

// Create and register a Splunk data source
let splunk = await SplunkDataSource(
    host: "splunk.example.com",
    port: 8089,
    authToken: "your-bearer-token",
    useSSL: true
)

let manager = await CoreDataManager.shared
await manager.registerDataSource(splunk, withId: "splunk-prod")

// Save data source configuration
let configId = try await manager.saveDataSourceConfig(
    name: "Production Splunk",
    type: .splunk,
    host: "splunk.example.com",
    port: 8089,
    authToken: "your-bearer-token",
    isDefault: true
)

// Execute a search with tracking
let executionId = try await manager.executeSearch(
    dataSourceId: dataSourceUUID,
    query: "search index=main | stats count by host",
    parameters: SearchParameters(
        earliestTime: "-24h",
        latestTime: "now",
        tokens: ["host": "web01"]
    ),
    dataSourceConfigId: configId
)

// Monitor search status
let status = try await splunk.checkSearchStatus(executionId: executionId.uuidString)

if status == .completed {
    // Fetch results
    let results = try await splunk.fetchResults(
        executionId: executionId.uuidString,
        offset: 0,
        limit: 100
    )

    // Save results to CoreData for historical tracking
    try await manager.updateSearchExecution(
        executionId: executionId,
        status: .completed,
        results: results
    )
}
```

### Accessing Historical Data

```swift
import DashboardKit

let manager = await CoreDataManager.shared

// Fetch search history for a data source
let history = try await manager.fetchSearchHistory(
    dataSourceId: dataSourceUUID,
    limit: 100
)

// Access historical results (timeline feature)
for execution in history {
    print("Execution at \(execution.startTime!)")
    print("Status: \(execution.status!)")
    print("Result count: \(execution.resultCount)")

    // Access stored results
    if let results = execution.results as? Set<SearchResult> {
        for result in results.sorted(by: { $0.rowIndex < $1.rowIndex }) {
            print(result.resultJSON!)
        }
    }
}
```

## Dashboard Studio Format

Dashboard Studio uses JSON with these core sections:

### Visualizations

```json
{
  "viz_cpu": {
    "type": "splunk.singlevalue",
    "title": "CPU Usage",
    "dataSources": {
      "primary": "ds_cpu"
    },
    "options": {
      "majorValue": "> primary | seriesByIndex(0)"
    }
  }
}
```

### Data Sources

```json
{
  "ds_base": {
    "type": "ds.search",
    "options": {
      "query": "index=main sourcetype=metrics"
    }
  },
  "ds_cpu": {
    "type": "ds.chain",
    "extends": "ds_base",
    "options": {
      "query": "| stats avg(cpu_percent)"
    }
  }
}
```

### Layout

```json
{
  "layout": {
    "type": "absolute",
    "structure": [
      {
        "item": "viz_cpu",
        "type": "block",
        "position": {
          "x": 0,
          "y": 60,
          "w": 300,
          "h": 200
        }
      }
    ]
  }
}
```

### Inputs

```json
{
  "input_time": {
    "type": "input.timerange",
    "title": "Time Range",
    "token": "global_time",
    "defaultValue": "-60m@m,now"
  }
}
```

## SimpleXML Format

Legacy SimpleXML uses bootstrap-style layout:

```xml
<form>
  <label>Server Monitoring</label>
  <fieldset>
    <input type="time" token="time_range">
      <label>Time Range</label>
    </input>
  </fieldset>
  <row>
    <panel>
      <title>CPU Usage</title>
      <single>
        <search>
          <query>index=main | stats avg(cpu_percent)</query>
          <earliest>$time_range.earliest$</earliest>
          <latest>$time_range.latest$</latest>
        </search>
      </single>
    </panel>
  </row>
</form>
```

## Integration with SplTV

This framework is designed to integrate with the SplTV GUI application, which:

- Displays dashboards using the CoreData models
- Extrapolates tokens from inputs
- Manages search timers and refresh intervals
- Passes searches to CoreDataManager for execution
- Provides timeline views of historical search results

The CoreDataManager acts as a background worker/helper making requests to Splunk instances, while SplTV handles the UI layer.

## Extending to Other Data Sources

To add support for Elastic or Prometheus:

```swift
public actor ElasticDataSource: DataSourceProtocol {
    public let type: DataSourceType = .elastic

    public func executeSearch(query: String, parameters: SearchParameters) async throws -> SearchExecutionResult {
        // Implement Elastic search API
    }

    // Implement other protocol methods...
}
```

Register the new data source:

```swift
let elastic = await ElasticDataSource(host: "elastic.example.com")
await manager.registerDataSource(elastic, withId: "elastic-prod")
```

## Examples

See the `Examples/` directory for complete dashboard examples:

- `dashboard_studio_example.json`: Full Dashboard Studio dashboard with multiple visualizations
- `simple_xml_example.xml`: Legacy SimpleXML dashboard

## Testing

Run tests with:

```bash
swift test
```

Tests cover:
- Dashboard Studio parsing and validation
- SimpleXML parsing
- Format conversion
- Data source chaining
- Serialization and round-tripping

## Requirements

- Swift 6.0+
- macOS 14+
- tvOS 17+
- CoreData framework

## License

Copyright © 2025. All rights reserved.

## Features Unique to This Implementation

### Historical Timeline

Unlike web-based Splunk dashboards, this implementation stores all search results in CoreData, enabling:

- Historical trending beyond web session lifetime
- Offline access to previous search results
- Timeline visualization of metric changes
- Search result comparison over time

### Data Source Awareness

The CoreData schema is specifically designed to differentiate and track:

- Different data source types (Splunk, Elastic, Prometheus)
- Search execution metadata (execution ID, timestamps, status)
- Chained data sources (Dashboard Studio `ds.chain` support)
- Individual data source configurations with authentication

### Dual Format Support

Seamlessly work with both formats:

- Parse legacy SimpleXML dashboards from existing Splunk instances
- Convert them to Dashboard Studio format for modern features
- Store both formats in the same CoreData model
- Export to either format as needed

## Future Enhancements

- Elastic Search data source implementation
- Prometheus data source implementation
- Real-time search streaming
- Dashboard templating
- Export to PDF/image formats
- Dashboard version control
