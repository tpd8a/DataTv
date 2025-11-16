# DashboardKit Integration Status

## ✅ Completed: DashboardKit Framework

DashboardKit is now **feature-complete** and ready for SplTV integration!

### What's Been Done

#### 1. Core Refactor (from d8aTv-refactor branch)
- ✅ **Multi-format support**: SimpleXML + Dashboard Studio parsers
- ✅ **New CoreData schema**: Enhanced with historical tracking and multi-source support
- ✅ **Data source protocol**: Extensible for Splunk, Elastic, Prometheus
- ✅ **SplunkDataSource**: Complete REST API implementation
- ✅ **CoreDataManager**: CRUD operations and search execution
- ✅ **Format converters**: Bidirectional SimpleXML ↔ Dashboard Studio

#### 2. Additional Functionality Ported (just added)
- ✅ **Token system** (`TokenModels.swift`):
  - Complete token definition types (TokenType, TokenScope, TokenChoice, etc.)
  - TokenResolver actor for query token substitution
  - Support for all input types (dropdown, time, text, radio, checkbox, multiselect)
  - Token dependency tracking

- ✅ **Search monitoring** (`SearchExecutionMonitor.swift`):
  - Real-time execution tracking with ObservableObject
  - SearchExecutionSummary for SwiftUI displays
  - Polling-based monitoring with configurable intervals
  - Filter executions by status (running, completed, failed)
  - CoreDataManager extensions for fetching history

- ✅ **Credential management** (`CredentialManager.swift`):
  - Secure keychain storage for credentials
  - Support for both username/password and auth tokens
  - CRUD operations (store, retrieve, delete, exists check)

#### 3. Framework Integration
- ✅ Convenience accessors in `DashboardKit.swift`
- ✅ Type aliases for common types
- ✅ Clean public API

### What DashboardKit Provides

```swift
import DashboardKit

// Parse dashboards (both formats)
let studioParser = await DashboardStudioParser()
let xmlParser = await SimpleXMLParser()

// CoreData management
let manager = await DashboardKit.manager
await manager.saveDashboard(config)

// Token resolution
let resolver = await TokenResolver(tokenValues: ["host": "web01"])
let resolvedQuery = await resolver.resolveTokens(in: query, definitions: definitions)

// Search monitoring
let monitor = DashboardKit.monitor // @MainActor
await monitor.startMonitoring()

// Credential management
let credentials = await DashboardKit.credentials
try await credentials.storeAuthToken(host: "splunk.example.com", token: "abc123")

// Execute searches with tracking
let executionId = try await manager.executeSearch(
    dataSourceId: dataSourceUUID,
    query: resolvedQuery,
    parameters: SearchParameters(earliestTime: "-24h", latestTime: "now"),
    dataSourceConfigId: configId
)
```

## 📋 Next Step: SplTV Integration

SplTV needs to be migrated from old d8aTvCore entities to new DashboardKit entities.

### Entity Migration Required

| Old Entity (d8aTvCore) | New Entity (DashboardKit) |
|------------------------|---------------------------|
| `DashboardEntity` | `Dashboard` |
| `FieldsetEntity` + `TokenEntity` | `DashboardInput` |
| `TokenChoiceEntity` | JSON in `optionsJSON` |
| `RowEntity` | `LayoutItem` |
| `PanelEntity` | `Visualization` + `LayoutItem` |
| `SearchEntity` | `DataSource` |
| `VisualizationEntity` | `Visualization` |
| `SearchExecutionEntity` | `SearchExecution` |
| `SearchResultRecordEntity` | `SearchResult` |

### Files Needing Updates

**High Priority:**
1. `SplTvApp.swift` - Change import from `d8aTvCore` to `DashboardKit`
2. `Persistence.swift` - Remove local CoreData model, use DashboardKit's
3. `DashboardMainView.swift` - Update @FetchRequest to use new entities
4. `DashboardRenderView.swift` - **Most complex**: Rewrite layout system
5. `DashboardMonitorView.swift` - Update entity references
6. `DashboardRefreshWorker.swift` - Update to work with DataSource entities
7. `DashboardTokenManager.swift` - Rewrite using TokenModels from DashboardKit

**Medium Priority:**
8. `VisualizationFormatting.swift` - Update to read from `optionsJSON`/`contextJSON`

**Xcode Project:**
9. Update Package Dependencies in `SplTv.xcodeproj`
10. Remove reference to `SplTv.xcdatamodeld` (use DashboardKit's model)

### Migration Complexity Estimates

- **DashboardTokenManager**: Medium (rewrite input parsing)
- **DashboardMainView**: Low (straightforward entity swap)
- **DashboardRenderView**: **High** (complete layout rewrite for LayoutItem system)
- **DashboardMonitorView**: Medium (update entity references)
- **DashboardRefreshWorker**: Medium (update entity references)
- **VisualizationFormatting**: Low (JSON accessor updates)

### Key Architectural Changes

#### 1. No More Rows
```swift
// OLD
for row in dashboard.rowsArray {
    for panel in row.panelsArray {
        renderPanel(panel)
    }
}

// NEW
if let layout = dashboard.layout {
    for item in layout.layoutItems?.sorted(by: { $0.position < $1.position }) ?? [] {
        if let viz = item.visualization {
            renderVisualization(viz)
        }
    }
}
```

#### 2. Inputs Instead of Fieldsets/Tokens
```swift
// OLD
for fieldset in dashboard.fieldsetsArray {
    for token in fieldset.tokensArray {
        renderInput(token)
    }
}

// NEW
for input in dashboard.inputs ?? [] {
    // Parse choices from JSON
    if let optionsJSON = input.optionsJSON,
       let data = optionsJSON.data(using: .utf8) {
        let choices = try? JSONDecoder().decode([TokenChoice].self, from: data)
        renderInput(input, choices: choices)
    }
}
```

#### 3. DataSources Instead of Embedded Searches
```swift
// OLD
let search = panel.searches?.first
let query = search?.query

// NEW
let visualization = layoutItem.visualization
let dataSource = visualization?.dataSource
let query = dataSource?.query
```

### Estimated Timeline

- **Phase 1**: Update Xcode project dependencies (30 min)
- **Phase 2**: Update app initialization and persistence (1 hour)
- **Phase 3**: Migrate DashboardTokenManager (2 hours)
- **Phase 4**: Migrate DashboardMainView (1 hour)
- **Phase 5**: Migrate DashboardRenderView (4 hours) - **Most complex**
- **Phase 6**: Migrate DashboardMonitorView (2 hours)
- **Phase 7**: Migrate DashboardRefreshWorker (2 hours)
- **Phase 8**: Update VisualizationFormatting (1 hour)
- **Phase 9**: Testing and fixes (2 hours)

**Total: ~15 hours of development**

## 🎯 Benefits After Migration

1. **Timeline Features**: Historical search results stored in CoreData
2. **Multi-Source Support**: Easy to add Elastic/Prometheus data sources
3. **Better Performance**: Reusable DataSource entities, less duplicate queries
4. **Cleaner Schema**: Less nesting, more JSON, easier to query
5. **Dashboard Studio Support**: Parse modern Splunk 10+ dashboards
6. **Format Conversion**: Convert between SimpleXML and Dashboard Studio

## 📦 Repository Status

- ✅ DashboardKit complete and committed
- ✅ Migration plan documented (MIGRATION_PLAN.md)
- ✅ All changes pushed to `claude/setup-spltv-swift-01QtZj9aA9W5j7XyoZPFCpQt`
- ⏳ SplTV migration pending

## Next Command

```bash
# Start SplTV migration
cd SplTv
open SplTv.xcodeproj
# Update Package Dependencies from d8aTv to DashboardKit
```
