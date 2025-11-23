# SplTv Project Architecture

## Overview

SplTv is built on a modern **modular architecture** separating core functionality (DashboardKit framework) from the UI layer (SplTv app). This document provides a detailed technical overview of the architecture, data flow, and entity relationships.

## Architecture Layers

```
┌─────────────────────────────────────────────────────────────┐
│                        SplTv App                             │
│  ┌────────────────────────────────────────────────────────┐ │
│  │           SwiftUI Views & ViewModels                   │ │
│  │  • DashboardRenderView, TableView, SingleValueView    │ │
│  │  • SettingsView, NavigationSidebar                     │ │
│  │  • TokenInputViews, SearchStatusView                   │ │
│  └────────────────────────────────────────────────────────┘ │
│                            ↓↑                                │
└─────────────────────────────────────────────────────────────┘
                             ↓↑
┌─────────────────────────────────────────────────────────────┐
│                      DashboardKit                            │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                   Managers                             │ │
│  │  • CoreDataManager (persistence, search execution)     │ │
│  │  • SearchExecutionMonitor (status tracking)            │ │
│  │  • CredentialManager (keychain access)                 │ │
│  └────────────────────────────────────────────────────────┘ │
│                            ↓↑                                │
│  ┌────────────────────────────────────────────────────────┐ │
│  │              Splunk Integration                        │ │
│  │  • SplunkRestClient (HTTP requests)                    │ │
│  │  • SplunkSearchService (search jobs)                   │ │
│  │  • SplunkDashboardService (dashboard fetching)         │ │
│  │  • SplunkDataSource (DataSourceProtocol impl)          │ │
│  └────────────────────────────────────────────────────────┘ │
│                            ↓↑                                │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                  Parsers                               │ │
│  │  • DashboardStudioParser (JSON → config objects)       │ │
│  │  • SimpleXMLParser (XML → config objects)              │ │
│  └────────────────────────────────────────────────────────┘ │
│                            ↓↑                                │
│  ┌────────────────────────────────────────────────────────┐ │
│  │              CoreData Layer                            │ │
│  │  • Entities: Dashboard, DataSource, Visualization      │ │
│  │  • DashboardModel.xcdatamodeld                         │ │
│  │  • NSManagedObject subclasses                          │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                             ↓↑
┌─────────────────────────────────────────────────────────────┐
│                  Splunk Enterprise                           │
│  • REST API (port 8089)                                      │
│  • Dashboard definitions (Studio v2, SimpleXML v1)           │
│  • Search API (job creation, results fetching)               │
│  • Saved searches                                            │
└─────────────────────────────────────────────────────────────┘
```

## Module Structure

### DashboardKit (`d8aTv/Sources/DashboardKit/`)

Core framework providing all business logic and Splunk integration:

```
DashboardKit/
├── CoreData/
│   ├── DashboardModel.xcdatamodeld/     # CoreData schema
│   └── Entities/
│       ├── Dashboard+CoreDataProperties.swift
│       ├── DataSource+CoreDataProperties.swift
│       ├── Visualization+CoreDataProperties.swift
│       ├── SearchExecution+CoreDataProperties.swift
│       ├── SearchResult+CoreDataProperties.swift
│       ├── DashboardInput+CoreDataProperties.swift
│       ├── DashboardLayout+CoreDataProperties.swift
│       ├── LayoutItem+CoreDataProperties.swift
│       └── DataSourceConfig+CoreDataProperties.swift
│
├── DataSources/
│   ├── DataSourceProtocol.swift         # Protocol for data sources
│   └── SplunkDataSource.swift           # Splunk implementation
│
├── Managers/
│   ├── CoreDataManager.swift            # Main persistence manager
│   ├── SearchExecutionMonitor.swift     # Search tracking
│   └── CredentialManager.swift          # Keychain wrapper
│
├── Models/
│   ├── DashboardStudioModels.swift      # Studio configuration models
│   ├── SimpleXMLModels.swift            # SimpleXML models
│   ├── SearchModels.swift               # Search parameters, results
│   └── SplunkModels.swift               # Splunk API response models
│
├── Parsers/
│   ├── DashboardStudioParser.swift      # Parse Studio JSON
│   └── SimpleXMLParser.swift            # Parse SimpleXML
│
├── Services/
│   ├── SplunkIntegration.swift          # Core Splunk types
│   ├── SplunkRestClient.swift           # HTTP client
│   ├── SplunkSearchService.swift        # Search operations
│   └── SplunkDashboardService.swift     # Dashboard fetching
│
└── DashboardKit.swift                   # Module exports
```

### SplTv App (`SplTv/SplTv/`)

SwiftUI application layer:

```
SplTv/
├── SplTvApp.swift                       # App entry, dashboard sync
├── Views/
│   ├── DashboardRenderView.swift        # Main dashboard renderer
│   ├── Visualizations/
│   │   ├── TableView.swift              # Table visualization
│   │   ├── SingleValueView.swift        # Single value viz
│   │   ├── ChartView.swift              # Charts (future)
│   │   └── VisualizationFormatting.swift
│   ├── Inputs/
│   │   ├── TimePickerInputView.swift    # Time range picker
│   │   ├── DropdownInputView.swift      # Dropdown selector
│   │   └── TextInputView.swift          # Text input
│   └── SearchStatusView.swift           # Search execution status
│
├── Settings/
│   ├── SettingsView.swift               # Main settings
│   ├── ConnectionSettingsView.swift     # Splunk connection
│   └── ResetView.swift                  # CoreData management
│
├── Models/
│   └── PersistenceController.swift      # CoreData stack wrapper
│
└── *.md                                 # Feature documentation
```

## CoreData Entity Model

### Entity Relationship Diagram

```
Dashboard (1) ──────────┬──────────> (N) DataSource
    │                   │
    │ (1)               │ (1)
    │                   │
    ↓                   ↓
DashboardLayout (1)  Visualization (N)
    │                   │
    │ (1)               │ (1)
    │                   │
    ↓                   ↓
LayoutItem (N)      LayoutItem (N)
    │
    │ (1)
    │
    ↓
DashboardInput (0..1)

DataSource (1) ──> (N) SearchExecution (1) ──> (N) SearchResult

DataSourceConfig (1) ──> (N) SearchExecution
DataSourceConfig (1) ──> (N) Dashboard
```

### Entity Descriptions

#### Dashboard
**Purpose**: Root entity for a dashboard definition

**Attributes**:
- `id`: UUID (primary key)
- `title`: String (dashboard name)
- `dashboardDescription`: String? (optional description)
- `formatType`: String (dashboardStudio | simpleXML)
- `rawJSON`: String? (original Studio JSON)
- `rawXML`: String? (original SimpleXML)
- `defaultsJSON`: String? (default options)
- `createdAt`: Date
- `updatedAt`: Date

**Relationships**:
- `dataSources`: [DataSource] (queries/searches)
- `visualizations`: [Visualization] (charts, tables, etc.)
- `inputs`: [DashboardInput] (time pickers, dropdowns)
- `layout`: DashboardLayout? (positioning)
- `dataSourceConfig`: DataSourceConfig? (Splunk connection)

#### DataSource
**Purpose**: SPL query or saved search reference

**Attributes**:
- `id`: UUID
- `sourceId`: String (unique identifier within dashboard)
- `name`: String? (display name)
- `type`: String (ds.search | ds.savedSearch | ds.chain)
- `query`: String? (SPL query)
- `refresh`: String? (e.g., "30s", "5m")
- `refreshType`: String? (delay | interval)
- `optionsJSON`: String? (query parameters, time range)
- `extendsId`: String? (base search for chained searches)
- `owner`: String? (saved search owner)
- `app`: String? (saved search app context)

**Relationships**:
- `dashboard`: Dashboard
- `executions`: [SearchExecution] (execution history)
- `visualizations`: [Visualization] (vizs using this data)

**Special Fields (Saved Searches)**:
- For saved searches with `refresh`, uses `| loadjob savedsearch="{owner}:{app}:{ref}"`
- `owner` and `app` fetched via `| rest /servicesNS/-/-/saved/searches` on first sync
- Stored in `optionsJSON` as `ref` field

#### Visualization
**Purpose**: Chart, table, or single value display

**Attributes**:
- `id`: UUID
- `vizId`: String (unique within dashboard)
- `type`: String (splunk.table | splunk.singlevalue | viz.type)
- `title`: String? (visualization title)
- `optionsJSON`: String? (formatting, colors, styles)
- `contextJSON`: String? (context-specific options)
- `encoding`: String? (data encoding format)

**Relationships**:
- `dashboard`: Dashboard
- `dataSource`: DataSource? (primary data source)
- `layoutItem`: LayoutItem? (positioning)

#### SearchExecution
**Purpose**: Track search job lifecycle

**Attributes**:
- `id`: UUID
- `executionId`: String (Splunk search job SID)
- `searchId`: String (DataSource sourceId)
- `query`: String (executed SPL)
- `startTime`: Date
- `endTime`: Date?
- `status`: String (running | completed | failed)
- `resultCount`: Int64?
- `errorMessage`: String?

**Relationships**:
- `dataSource`: DataSource
- `results`: [SearchResult]
- `dataSourceConfig`: DataSourceConfig

#### SearchResult
**Purpose**: Cache search result rows

**Attributes**:
- `id`: UUID
- `timestamp`: Date
- `resultJSON`: String (serialized row data)
- `rowIndex`: Int32

**Relationships**:
- `execution`: SearchExecution

#### DashboardLayout
**Purpose**: Define layout structure

**Attributes**:
- `id`: UUID
- `type`: String (absolute | grid | bootstrap)
- `optionsJSON`: String? (layout options)
- `globalInputs`: String? (input order)

**Relationships**:
- `dashboard`: Dashboard
- `layoutItems`: [LayoutItem]

#### LayoutItem
**Purpose**: Position visualizations and inputs

**Attributes**:
- `id`: UUID
- `type`: String (block | input | line)
- `x`, `y`, `width`, `height`: Int32 (absolute/grid)
- `bootstrapWidth`: String? (bootstrap column width)
- `position`: Int32 (order)

**Relationships**:
- `layout`: DashboardLayout
- `visualization`: Visualization?
- `input`: DashboardInput?

#### DashboardInput
**Purpose**: Interactive inputs (time pickers, dropdowns)

**Attributes**:
- `id`: UUID
- `inputId`: String (unique within dashboard)
- `type`: String (input.timerange | input.dropdown | input.text)
- `title`: String?
- `token`: String? (token name for substitution)
- `defaultValue`: String?
- `optionsJSON`: String? (input-specific options)

**Relationships**:
- `dashboard`: Dashboard
- `layoutItem`: LayoutItem?

#### DataSourceConfig
**Purpose**: Splunk connection configuration

**Attributes**:
- `id`: UUID
- `name`: String
- `type`: String (splunk | elastic | prometheus)
- `host`: String
- `port`: Int32
- `username`: String?
- `authToken`: String?
- `isDefault`: Bool
- `configJSON`: String?
- `createdAt`: Date

**Relationships**:
- `dashboards`: [Dashboard]
- `executions`: [SearchExecution]

## Data Flow

### Dashboard Sync Flow

```
1. User clicks "Sync Dashboards"
   ↓
2. SplTvApp.syncDashboards()
   - Get credentials from CredentialManager
   - Create SplunkConfiguration
   - Create SplunkDashboardService
   ↓
3. SplunkDashboardService.listDashboards()
   - Fetch dashboard list from Splunk REST API
   - Returns array of dashboard entries
   ↓
4. For each dashboard:
   a. Detect format (Studio v2 vs SimpleXML v1)
   b. Parse using DashboardStudioParser or SimpleXMLParser
   c. Convert to configuration objects
   ↓
5. CoreDataManager.saveDashboard(config, dataSourceConfigId)
   - Create Dashboard entity
   - Create DataSource entities
   - Create Visualization entities
   - Create DashboardLayout and LayoutItem entities
   - Create DashboardInput entities
   - Save to CoreData
   ↓
6. CoreDataManager.populateSavedSearchMetadata(dashboardId, configId)
   - Find DataSources with `ref` but missing owner/app
   - Execute: | rest /servicesNS/-/-/saved/searches | search title="{ref}"
   - Update DataSource with owner and app
   ↓
7. Dashboard cached locally, ready for viewing
```

### Search Execution Flow

```
1. User opens dashboard in DashboardRenderView
   ↓
2. For each DataSource in dashboard:
   a. Check if has refresh interval
   b. Build search parameters (time range, tokens)
   c. Call CoreDataManager.startSearchExecution()
   ↓
3. CoreDataManager.startSearchExecution()
   - Get DataSource from CoreData
   - Process query based on type:
     * Saved search with refresh: | loadjob savedsearch="{owner}:{app}:{ref}"
     * Regular saved search: | savedsearch {ref}
     * Chained search: | loadjob {baseSID} | {postProcessing}
     * Regular search: search {query}
   - Substitute tokens ($token$ → value)
   - Get/create SplunkDataSource
   ↓
4. SplunkDataSource.executeSearch(query, parameters)
   - Create search job via SplunkSearchService
   - Returns executionId (Splunk SID)
   ↓
5. CoreDataManager creates SearchExecution entity
   - Link to DataSource
   - Track status (running)
   ↓
6. SearchExecutionMonitor polls status
   - Check SplunkDataSource.checkSearchStatus(executionId)
   - Update SearchExecution status
   ↓
7. When complete, fetch results
   - SplunkDataSource.fetchResults(executionId)
   - Save to SearchResult entities
   ↓
8. DashboardRenderView updates
   - Fetch SearchExecution and SearchResult entities
   - Pass results to visualization views
   - Render tables, single values, etc.
```

### Token Substitution Flow

```
1. User changes time picker or dropdown input
   ↓
2. DashboardRenderView updates token state
   - Dictionary: [tokenName: value]
   ↓
3. When executing search:
   - CoreDataManager.startSearchExecution() receives tokens
   - Replace $token$ in query with actual value
   - Example: "$earliest$" → "-24h@h"
   ↓
4. Splunk search executes with substituted values
```

## Key Protocols

### DataSourceProtocol
Abstract interface for data sources (Splunk, Elastic, Prometheus):

```swift
public protocol DataSourceProtocol: Actor {
    var type: DataSourceType { get }

    func executeSearch(query: String, parameters: SearchParameters) async throws -> SearchExecutionResult
    func checkSearchStatus(executionId: String) async throws -> SearchStatus
    func fetchResults(executionId: String, offset: Int, limit: Int) async throws -> [SearchResultRow]
    func cancelSearch(executionId: String) async throws
    func validateConnection() async throws -> Bool
}
```

Allows extensibility to support other data platforms in the future.

## Configuration Objects vs CoreData Entities

### Configuration Objects (In-Memory)
Used during parsing and before persistence:
- `DashboardStudioConfiguration`
- `SimpleXMLConfiguration`
- `VisualizationDefinition`
- `DataSourceDefinition`
- `LayoutDefinition`

**Purpose**: Strongly-typed Swift structs matching Splunk's JSON/XML structure

### CoreData Entities (Persistent)
Flattened, normalized representation:
- `Dashboard`
- `DataSource`
- `Visualization`
- `DashboardLayout`
- `LayoutItem`

**Purpose**: Efficient querying, relationships, caching

**Conversion**: Parsers create config objects → `CoreDataManager.saveDashboard()` converts to entities

## Concurrency Model

### Swift 6 Concurrency
- **Actors**: `CoreDataManager`, `SplunkDataSource`, `SearchExecutionMonitor`
- **@MainActor**: SwiftUI views, ViewModels
- **Sendable**: All configuration models, API response types
- **async/await**: All network requests, CoreData operations

### CoreData Context Strategy
- **viewContext** (main thread): Read-only access for UI
- **newBackgroundContext()**: Write operations (saves, updates)
- **automaticallyMergesChangesFromParent**: Enabled for UI updates

## Comparison with Legacy d8aTvCore

| Aspect | Legacy d8aTvCore | Modern DashboardKit |
|--------|------------------|---------------------|
| **Architecture** | Monolithic, app-specific | Modular framework |
| **Entity Model** | XML hierarchy (rows → panels) | Flat Studio model |
| **IDs** | String IDs | UUID IDs |
| **Relationships** | Nested (dashboard.rows.panels) | Flat (dashboard.dataSources) |
| **Parsing** | XML-only | JSON (Studio) + XML (SimpleXML) |
| **Concurrency** | Callback-based | async/await, actors |
| **Splunk Integration** | Scattered, duplicated | Consolidated in Services/ |
| **Extensibility** | Splunk-only | Protocol-based (DataSourceProtocol) |
| **Testing** | Tightly coupled | Testable, protocol-driven |

## Benefits of New Architecture

1. **Modularity**: DashboardKit can be reused in other apps (iOS, CLI tools)
2. **Studio Support**: Native support for Dashboard Studio v2 format
3. **Maintainability**: Clear separation of concerns
4. **Extensibility**: Easy to add new data sources (Elastic, Prometheus)
5. **Performance**: Flat entity model, efficient queries
6. **Type Safety**: Sendable types, Swift 6 concurrency
7. **Modern Swift**: async/await, actors, protocols

## Future Enhancements

### Planned Features
- Chart visualizations (line, bar, pie)
- Real-time streaming searches
- Dashboard editing/creation
- Multi-Splunk instance support
- Elasticsearch data source
- Prometheus data source
- iOS companion app

### Architecture Improvements
- SwiftData migration (post-iOS 17)
- ViewModel layer (MVVM)
- Dependency injection
- Unit test coverage
- Performance profiling

---

Last Updated: 2025-11-23
