# SplTV App Architecture Analysis

## 1. PROJECT STRUCTURE & LOCATIONS

### Root Directory
- **Location**: `/home/user/DataTv/`

### SplTV App (iOS/macOS/tvOS Client)
- **Location**: `/home/user/DataTv/SplTv/SplTv/`
- **Type**: SwiftUI-based GUI application
- **Platforms**: macOS 26+, tvOS 17+

**Key App Files**:
```
/home/user/DataTv/SplTv/SplTv/
├── SplTvApp.swift               (Main app entry point, settings view)
├── ContentView.swift            (Legacy/basic view)
├── DashboardMainView.swift      (Main dashboard navigation view)
├── DashboardMonitorView.swift   (Search execution monitor/dashboard view)
├── DashboardRenderView.swift    (Dashboard rendering view)
├── DashboardTokenManager.swift  (Token state management)
├── DashboardRefreshWorker.swift (Auto-refresh timer management)
├── VisualizationFormatting.swift (Visualization formatting utilities)
├── Persistence.swift            (CoreData context setup)
└── SplTv.xcdatamodeld/          (Placeholder CoreData model)
```

### DashboardKit Framework (Core Library)
- **Location**: `/home/user/DataTv/d8aTv/Sources/DashboardKit/`
- **Type**: Swift Package
- **Package Definition**: `/home/user/DataTv/d8aTv/Package.swift`

**Core Subdirectories**:
```
/home/user/DataTv/d8aTv/Sources/DashboardKit/
├── CoreData/
│   ├── DashboardModel.xcdatamodeld/  (CoreData schema definition)
│   │   └── DashboardModel.xcdatamodel/contents
│   └── Entities/
│       ├── Dashboard+CoreDataClass.swift
│       ├── DataSource+CoreDataClass.swift
│       ├── Visualization+CoreDataClass.swift
│       ├── SearchExecution+CoreDataClass.swift
│       ├── SearchResult+CoreDataClass.swift
│       ├── DashboardLayout+CoreDataClass.swift
│       ├── DashboardInput+CoreDataClass.swift
│       ├── LayoutItem+CoreDataClass.swift
│       ├── DataSourceConfig+CoreDataClass.swift
│       └── [+CoreDataProperties.swift for each]
├── Managers/
│   ├── CoreDataManager.swift    (Main persistence manager)
│   ├── SearchExecutionMonitor.swift
│   └── CredentialManager.swift
├── DataSources/
│   └── SplunkDataSource.swift   (Splunk REST API implementation)
├── Models/
│   ├── DashboardStudioModels.swift
│   ├── SimpleXMLModels.swift
│   ├── TokenModels.swift
│   └── DashboardConverter.swift
├── Parsers/
│   ├── DashboardStudioParser.swift
│   └── SimpleXMLParser.swift
├── Protocols/
│   └── DataSourceProtocol.swift
└── DashboardKit.swift           (Public API entry point)
```

### d8aTvCore Module (Legacy Core Data)
- **Location**: `/home/user/DataTv/d8aTv/Sources/d8aTvCore/`

**Core Files**:
```
/home/user/DataTv/d8aTv/Sources/d8aTvCore/
├── CoreDataEntities.swift       (DashboardEntity, SearchEntity, TokenEntity)
├── CoreDataManager.swift        (Legacy CoreDataManager - startSearchExecution)
├── DashboardLoader.swift        (Dashboard parsing and loading)
├── SplunkIntegration.swift      (Splunk REST client)
├── SplunkCredentialManager.swift (Keychain credential storage)
├── TokenDefinitionParser.swift
├── SearchExecutionMonitor.swift
├── CompleteDashboardParsingExample.swift
├── XMLParsingUtilities.swift
├── SimpleXMLElementExtensions.swift
└── CoreDataModelConfiguration.swift
```

## 2. MAIN ENTRY POINTS & COMPONENTS

### App Entry Point
**File**: `/home/user/DataTv/SplTv/SplTv/SplTvApp.swift`

```swift
@main
struct SplTvApp: App {
    let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            DashboardMainView()
                .environment(\.managedObjectContext, persistenceController.context)
        }
        Settings {
            SettingsView() // macOS settings with Splunk connection config
        }
    }
}
```

### Main Navigation View
**File**: `/home/user/DataTv/SplTv/SplTv/DashboardMainView.swift`

**Features**:
- Fetches all dashboards from CoreData
- Provides view mode switcher (Monitor vs. Render)
- Dashboard selector sidebar
- Loads tokens for selected dashboard
- Shows dashboard inputs/fieldsets

### Dashboard Monitor View (Search Execution)
**File**: `/home/user/DataTv/SplTv/SplTv/DashboardMonitorView.swift`

**Features**:
- Displays all searches in dashboard
- Shows execution history and status
- Real-time progress tracking
- Search result visualization
- Configurable cell highlighting and table formatting
- Search execution timeline

### Dashboard Render View
**File**: `/home/user/DataTv/SplTv/SplTv/DashboardRenderView.swift`

**Features**:
- Renders dashboard layout from CoreData
- Displays rows, panels, visualizations
- Global timeline control toggle
- Search result panels

### Token Manager
**File**: `/home/user/DataTv/SplTv/SplTv/DashboardTokenManager.swift`

```swift
@MainActor
public class DashboardTokenManager: ObservableObject {
    public static let shared = DashboardTokenManager()
    
    @Published var tokenValues: [String: TokenValue]
    @Published var tokenDefinitions: [String: TokenEntity]
    @Published var activeDashboardId: String?
    
    // Key methods:
    public func loadTokens(for dashboard: DashboardEntity)
    public func setTokenValue(_ value: String, forToken name: String)
    public func getValue(forToken name: String) -> String?
    public func getAllValues() -> [String: String]
    public func executeSearch(searchId: String, in dashboardId: String, ...) -> String
}
```

### Refresh Worker
**File**: `/home/user/DataTv/SplTv/SplTv/DashboardRefreshWorker.swift`

```swift
@MainActor
public class DashboardRefreshWorker: ObservableObject {
    public static let shared = DashboardRefreshWorker()
    
    @Published var activeTimerCount: Int
    @Published var isRunning: Bool
    @Published var activeSearchTimers: [String: SearchTimerInfo]
    
    // Key methods:
    public func startAllRefreshTimers()
    public func stopAllTimers()
    // Handles post-process search dependencies
}
```

## 3. HOW SplTV INTERFACES WITH CoreDataManager

### Data Flow Diagram
```
SplTV App
    ↓
DashboardMainView (fetches dashboards)
    ├→ CoreDataManager.shared (d8aTvCore)
    │   └→ fetchAllDashboards() → [DashboardEntity]
    │
DashboardTokenManager.shared
    ├→ loadTokens(dashboard) 
    │   └→ Reads TokenEntity from dashboard
    │
    ├→ executeSearch(searchId, dashboardId, tokens)
    │   └→ CoreDataManager.shared.startSearchExecution(...)
    │       └→ Returns executionId
    │       └→ Posts notifications
    │       └→ Async execution via SplunkIntegration
    │
DashboardRefreshWorker.shared
    ├→ Subscribes to searchExecutionCompleted notification
    ├→ Manages Timer objects for refresh intervals
    └→ Calls executeSearch for dependent searches
```

### Key API Methods

#### 1. **Dashboard Fetching** (DashboardEntity)
**From**: `d8aTvCore/CoreDataManager.swift`

```swift
// Main fetch methods:
public func fetchAllDashboards() -> [DashboardEntity]
public func findDashboard(by id: String) -> DashboardEntity?
public func findDashboard(byAppAndName appName: String, dashboardName: String) -> DashboardEntity?
public func dashboardsInApp(_ appName: String) -> [DashboardEntity]

// Called from: DashboardMainView via @FetchRequest<DashboardEntity>
@FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \DashboardEntity.title, ascending: true)],
    animation: .default)
private var dashboards: FetchedResults<DashboardEntity>
```

#### 2. **Token Loading** (TokenEntity)
**From**: `d8aTvCore/CoreDataEntities.swift`

```swift
// DashboardEntity relationships:
@NSManaged public var fieldsets: NSSet?  // FieldsetEntity objects
    ├→ FieldsetEntity.tokens: NSSet?     // TokenEntity objects
    │   └→ TokenEntity properties:
    │       ├ name: String
    │       ├ type: String (input, dropdown, time, etc.)
    │       ├ label: String?
    │       ├ defaultValue: String?
    │       ├ initialValue: String?
    │       ├ choices: NSSet? (TokenChoiceEntity)
    │       └ changeConditions: NSSet?

// Loaded by DashboardTokenManager:
let allTokens = dashboard.allTokens
for token in allTokens {
    tokenValues[token.name] = TokenValue(
        name: token.name,
        value: token.initialValue ?? token.defaultValue ?? ""
    )
}
```

#### 3. **Search Execution** (SearchEntity → startSearchExecution)
**From**: `d8aTvCore/CoreDataManager.swift`

```swift
public func startSearchExecution(
    searchId: String,
    in dashboardId: String,
    userTokenValues: [String: String] = [:],
    timeRange: (earliest: String?, latest: String?)? = nil,
    parameterOverrides: SearchParameterOverrides = SearchParameterOverrides(),
    splunkCredentials: SplunkCredentials? = nil
) -> String {
    // Returns executionId
    // Creates SearchExecutionEntity in Core Data
    // Posts notifications
    // Async executes via executeSearchAsync
}

// Called from:
DashboardTokenManager.executeSearch(...) 
    → CoreDataManager.shared.startSearchExecution(...)
    
DashboardRefreshWorker (timers)
    → CoreDataManager.shared.startSearchExecution(...)
```

#### 4. **Search Discovery**
**From**: `d8aTvCore/CoreDataManager.swift`

```swift
public func findSearches(in dashboardId: String) -> SearchDiscoveryResult {
    // Returns SearchDiscoveryResult with:
    // - panelSearches: [SearchInfo]
    // - visualizationSearches: [SearchInfo]
    // - globalSearches: [SearchInfo]
    
    // Searches from DashboardEntity.rowsArray
    //   → RowEntity.panelsArray
    //       → PanelEntity.searchesArray [SearchEntity]
    //       → PanelEntity.visualizationsArray
    //           → VisualizationEntity.search (SearchEntity)
    
    // And DashboardEntity.globalSearchesArray [SearchEntity]
}

// Called from: DashboardMonitorView to list all searches
```

#### 5. **Search Results**
**From**: `d8aTvCore/CoreDataManager.swift`

```swift
// Get execution status:
public func getSearchExecutionStatus(executionId: String) -> SearchExecutionEntity?

// Get results:
public func getSearchResults(executionId: String) -> SplunkSearchResults?
public func getSearchResultRecords(
    executionId: String, 
    offset: Int = 0, 
    limit: Int = 1000
) -> [[String: Any]]

// Watch for updates:
public func watchSearchExecution(
    executionId: String, 
    callback: @escaping (SearchExecutionSummary) -> Void
) -> NSObjectProtocol

// Get summary:
public func getExecutionSummary(executionId: String) -> SearchExecutionSummary?
```

### Notification System
**From**: `d8aTvCore/CoreDataManager.swift`

```swift
// Published notifications:
extension Notification.Name {
    static let searchExecutionStarted = Notification.Name("searchExecutionStarted")
    static let searchExecutionProgressUpdated = Notification.Name("searchExecutionProgressUpdated")
    static let searchExecutionCompleted = Notification.Name("searchExecutionCompleted")
    static let searchExecutionCancelled = Notification.Name("searchExecutionCancelled")
    static let searchJobCreated = Notification.Name("searchJobCreated")
}

// Observed by:
// - DashboardRefreshWorker: Listens for searchExecutionCompleted
// - DashboardMonitorView: Updates UI with progress
```

## 4. DATA STRUCTURES & TYPES

### CoreData Entities (DashboardKit)

**Dashboard Studio Format** (Modern - DashboardModel.xcdatamodel):
```swift
Dashboard {
    id: UUID
    title: String
    dashboardDescription: String?
    formatType: String ("dashboardStudio")
    rawJSON: String?
    createdAt: Date
    updatedAt: Date
    
    Relationships:
    - dataSources: [DataSource]
    - visualizations: [Visualization]
    - inputs: [DashboardInput]
    - layout: DashboardLayout
    - dataSourceConfig: DataSourceConfig
}

DataSource {
    id: UUID
    sourceId: String
    name: String?
    type: String ("ds.search", "ds.chain")
    query: String?
    refresh: String?
    refreshType: String?
    optionsJSON: String?
    
    Relationships:
    - dashboard: Dashboard
    - executions: [SearchExecution]
    - visualizations: [Visualization]
}

Visualization {
    id: UUID
    vizId: String
    type: String
    title: String?
    optionsJSON: String?
    contextJSON: String?
    
    Relationships:
    - dashboard: Dashboard
    - dataSource: DataSource?
    - layoutItem: LayoutItem
}

SearchExecution {
    id: UUID
    executionId: String
    searchId: String
    query: String
    startTime: Date
    endTime: Date?
    status: String (running, completed, failed)
    resultCount: Int64
    errorMessage: String?
    
    Relationships:
    - dataSource: DataSource
    - results: [SearchResult]
    - dataSourceConfig: DataSourceConfig
}

SearchResult {
    id: UUID
    timestamp: Date
    resultJSON: String
    rowIndex: Int32
    
    Relationships:
    - execution: SearchExecution
}
```

### CoreData Entities (d8aTvCore Legacy Format)

**SimpleXML Format** (tmpDashboardModel.xcdatamodel):
```swift
DashboardEntity {
    id: String (composite: "app§dashboard" or UUID)
    appName: String?
    dashboardName: String?
    title: String?
    dashboardDescription: String?
    xmlContent: String?
    xmlHash: String?
    version: String?
    theme: String?
    refreshInterval: Int32
    
    Relationships:
    - rows: [RowEntity]
    - fieldsets: [FieldsetEntity]
    - globalSearches: [SearchEntity]
    - customContent: [CustomContentEntity]
}

RowEntity {
    id: String
    xmlId: String?
    orderIndex: Int32
    depends: String?
    rejects: String?
    
    Relationships:
    - dashboard: DashboardEntity
    - panels: [PanelEntity]
}

PanelEntity {
    id: String
    xmlId: String?
    title: String?
    orderIndex: Int32
    
    Relationships:
    - row: RowEntity
    - visualizations: [VisualizationEntity]
    - searches: [SearchEntity]
    - inputs: [TokenEntity]
}

TokenEntity {
    name: String
    type: String (dropdown, text, time, radio, etc.)
    label: String?
    defaultValue: String?
    initialValue: String?
    populatingSearch: String?
    searchWhenChanged: Bool
    required: Bool
    
    Relationships:
    - fieldset: FieldsetEntity?
    - panel: PanelEntity?
    - choices: [TokenChoiceEntity]
    - changeConditions: [TokenConditionEntity]
}

SearchEntity {
    id: String
    xmlId: String?
    query: String?
    ref: String? (reference to saved search)
    base: String? (base search reference)
    autostart: Bool
    refresh: String?
    
    Relationships:
    - panel: PanelEntity?
    - dashboard: DashboardEntity?
    - visualization: VisualizationEntity?
}

VisualizationEntity {
    id: String
    type: String (table, chart, single, etc.)
    title: String?
    chartType: String?
    chartOptions: Data? (JSON)
    colorPalette: Data? (JSON)
    
    Relationships:
    - panel: PanelEntity?
    - search: SearchEntity?
}
```

### Public API Data Models

**DataSourceProtocol**:
```swift
public protocol DataSourceProtocol: Sendable {
    var type: DataSourceType { get }
    func executeSearch(query: String, parameters: SearchParameters) async throws -> SearchExecutionResult
    func checkSearchStatus(executionId: String) async throws -> SearchStatus
    func fetchResults(executionId: String, offset: Int, limit: Int) async throws -> [SearchResultRow]
    func cancelSearch(executionId: String) async throws
    func validateConnection() async throws -> Bool
}

enum DataSourceType: String {
    case splunk
    case elastic
    case prometheus
}

struct SearchParameters {
    let earliestTime: String?
    let latestTime: String?
    let maxResults: Int?
    let timeout: TimeInterval?
    let tokens: [String: String]
}

struct SearchExecutionResult {
    let executionId: String
    let searchId: String
    let status: SearchStatus
    let startTime: Date
}

enum SearchStatus: String {
    case queued, running, completed, failed, cancelled
}
```

### UI State Models

**TokenValue** (DashboardTokenManager):
```swift
struct TokenValue: Equatable, Identifiable {
    let id = UUID()
    let name: String
    let value: String
    let source: TokenValueSource  // user, default, calculated, search
    let lastUpdated: Date
}

enum TokenValueSource: String {
    case user, default, calculated, search
}
```

**SearchExecutionSummary** (d8aTvCore):
```swift
struct SearchExecutionSummary {
    let id: String
    let searchId: String
    let dashboardId: String
    let status: SearchExecutionStatus
    let progress: Double
    let message: String?
    let startTime: Date
    let endTime: Date?
    let resultCount: Int
    let jobId: String?
    let errorMessage: String?
}
```

## 5. KEY FILES FOR UPDATING

### High Priority (Core Interfaces)

1. **`/home/user/DataTv/d8aTv/Sources/d8aTvCore/CoreDataManager.swift`**
   - Contains `startSearchExecution()` - main search API
   - Contains `findSearches()` - search discovery
   - Contains `findDashboard()` - dashboard lookup
   - Manages SearchExecutionEntity lifecycle

2. **`/home/user/DataTv/d8aTv/Sources/d8aTvCore/CoreDataEntities.swift`**
   - Defines DashboardEntity, SearchEntity, TokenEntity, etc.
   - Core data model definitions
   - Must match tmpDashboardModel.xcdatamodel

3. **`/home/user/DataTv/d8aTv/Sources/DashboardKit/Managers/CoreDataManager.swift`**
   - DashboardKit's CoreDataManager for Studio format
   - New format persistence layer

4. **`/home/user/DataTv/d8aTv/Sources/d8aTvCore/DashboardLoader.swift`**
   - Parses XML/JSON dashboards
   - Populates CoreData
   - Entry point for dashboard loading

### Medium Priority (UI Integration)

5. **`/home/user/DataTv/SplTv/SplTv/DashboardMainView.swift`**
   - Dashboard fetching via @FetchRequest
   - Token loading trigger
   - View mode management

6. **`/home/user/DataTv/SplTv/SplTv/DashboardTokenManager.swift`**
   - Token state management
   - executeSearch() wrapper
   - Token change notifications

7. **`/home/user/DataTv/SplTv/SplTv/DashboardMonitorView.swift`**
   - Search execution display
   - Result rendering
   - Status monitoring

8. **`/home/user/DataTv/SplTv/SplTv/DashboardRefreshWorker.swift`**
   - Auto-refresh timer management
   - Post-process search handling
   - Notification subscriptions

### Data Models

9. **`/home/user/DataTv/d8aTv/Sources/DashboardKit/CoreData/DashboardModel.xcdatamodeld/`**
   - Studio format CoreData schema

10. **Dashboard xcdatamodel in d8aTvCore**
    - Legacy SimpleXML CoreData schema
    - File: `tmpDashboardModel.xcdatamodeld`

### Settings & Configuration

11. **`/home/user/DataTv/SplTv/SplTv/SplTvApp.swift`**
    - SettingsView with Splunk connection config
    - Dashboard sync functionality
    - Credential management UI

12. **`/home/user/DataTv/SplTv/SplTv/Persistence.swift`**
    - PersistenceController setup
    - CoreData context configuration

## 6. API CALL FLOW EXAMPLE

### User selects a dashboard and clicks "Execute Search"

```
1. DashboardMainView
   └→ @FetchRequest<DashboardEntity> fetches from CoreData
   └→ User selects dashboard: selectedDashboard = dashboardEntity
   
2. OnChange callback in DashboardMainView
   └→ DashboardTokenManager.shared.loadTokens(for: selectedDashboard)
   
3. DashboardTokenManager.loadTokens()
   └→ Reads: dashboard.allTokens (gets TokenEntity objects)
   └→ Initializes: tokenValues with token defaults
   
4. DashboardMonitorView
   └→ Calls: CoreDataManager.shared.findSearches(in: dashboardId)
   └→ Returns: SearchDiscoveryResult with all searches
   └→ Displays: SearchEntity list with query, autostart, etc.
   
5. User sets token values in UI
   └→ DashboardTokenManager.setTokenValue(value, forToken: name)
   └→ Posts notification: .tokenValueChanged
   
6. User executes a search
   └→ DashboardTokenManager.executeSearch(searchId, dashboardId, ...)
   └→ Calls: CoreDataManager.shared.startSearchExecution(
        searchId: searchId,
        in: dashboardId,
        userTokenValues: tokenManager.getAllValues()
     )
   
7. CoreDataManager.startSearchExecution()
   └→ Creates: SearchExecutionEntity in CoreData
   └→ Posts notification: .searchExecutionStarted
   └→ Spawns: Task.detached → executeSearchAsync()
   
8. executeSearchAsync()
   └→ Finds dashboard and search
   └→ Calls: SplunkIntegration.executeSearchWithProgress()
   └→ Updates: SearchExecutionEntity status, progress, results
   └→ Posts: .searchExecutionProgressUpdated, .searchExecutionCompleted
   
9. DashboardRefreshWorker listens for completion
   └→ Triggers dependent post-process searches if any
   
10. DashboardMonitorView observes notification
    └→ Updates: Execution status, progress bar, results table
```

## 7. IMPORTANT NOTES

### Two CoreData Models in Use
1. **DashboardKit** (`/d8aTv/Sources/DashboardKit/`): Modern Dashboard Studio format
2. **d8aTvCore** (`/d8aTv/Sources/d8aTvCore/`): Legacy SimpleXML format

### Dual Format Support
- SplTV app loads both formats
- CoreDataManager (d8aTvCore) handles legacy format
- DashboardKit CoreDataManager handles Studio format
- Automatic format detection in `startSearchExecution()`

### Main Actor Requirement
- CoreDataManager marked as @MainActor (d8aTvCore)
- DashboardTokenManager marked as @MainActor
- DashboardRefreshWorker marked as @MainActor
- SplTV follows strict main-thread CoreData operations

### Notification-Based Architecture
- Search execution uses NSNotificationCenter
- Token changes post notifications
- DashboardRefreshWorker subscribes to completion notifications
- DashboardMonitorView can observe progress

### Credential Management
- Stored in system Keychain (SplunkCredentialManager)
- Not persisted in CoreData
- Retrieved on demand during search execution
- Used for Splunk REST API authentication
