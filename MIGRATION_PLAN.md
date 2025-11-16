# SplTV Migration Plan: d8aTvCore → DashboardKit

## Overview

The d8aTv package has been refactored from scratch as **DashboardKit**, with a completely new CoreData schema. This document outlines the migration plan for updating SplTV to use the new framework.

## Entity Mapping

### Old Schema (d8aTvCore) → New Schema (DashboardKit)

| Old Entity | New Entity | Migration Notes |
|------------|------------|-----------------|
| `DashboardEntity` | `Dashboard` | - `dashboardName` → `title`<br>- `xmlContent` → `rawXML`<br>- Add `formatType` field<br>- `appName` removed (use DataSourceConfig) |
| `FieldsetEntity` | `DashboardInput` | - Simplified structure<br>- Choices now in `optionsJSON` |
| `TokenEntity` | `DashboardInput` | - Combined with Fieldset<br>- Token configuration in `optionsJSON` |
| `TokenChoiceEntity` | (JSON in `optionsJSON`) | - No longer separate entity |
| `RowEntity` | `LayoutItem` | - Layout is now explicit<br>- Bootstrap positioning preserved |
| `PanelEntity` | `Visualization` + `LayoutItem` | - Separated visualization from layout |
| `SearchEntity` | `DataSource` | - Now first-class entity<br>- `base` → `extendsId` for chaining<br>- Time params in `optionsJSON` |
| `VisualizationEntity` | `Visualization` | - Options in `optionsJSON`<br>- Formatting in `contextJSON` |
| `SearchExecutionEntity` | `SearchExecution` | - Similar structure<br>- Links to DataSource and DataSourceConfig |
| `SearchResultRecordEntity` | `SearchResult` | - Renamed for clarity |
| — | `DashboardLayout` | **NEW**: Explicit layout management |
| — | `DataSourceConfig` | **NEW**: Multi-source backend config |

## Key Structural Changes

### 1. Layout Management
**Old**: Implicit layout via Row → Panel hierarchy
```swift
Dashboard → Row (orderIndex) → Panel (orderIndex)
```

**New**: Explicit layout with LayoutItem
```swift
Dashboard → DashboardLayout → LayoutItem → Visualization
```

### 2. Data Sources
**Old**: Searches embedded in panels
```swift
Panel → Search (embedded)
```

**New**: Data sources are first-class entities
```swift
Dashboard → DataSource (reusable)
Visualization → references DataSource
```

### 3. Inputs/Tokens
**Old**: Complex hierarchy
```swift
Dashboard → Fieldset → Token → TokenChoice (separate entities)
```

**New**: Simplified structure
```swift
Dashboard → DashboardInput (choices in JSON)
```

## SplTV File Migration Checklist

### Core Files
- [ ] `SplTvApp.swift` - Update imports, use DashboardKit
- [ ] `Persistence.swift` - Use DashboardKit CoreData model
- [ ] Update Xcode project to reference DashboardKit

### View Files
- [ ] `DashboardMainView.swift`
  - Update `@FetchRequest` to use `Dashboard` entity
  - Update sidebar to use `Dashboard.inputs` instead of `fieldsets`
  - Update token loading for new input system

- [ ] `DashboardMonitorView.swift`
  - Update to fetch `Dashboard` entities
  - Update search execution monitoring to use `SearchExecution`
  - Update data source references

- [ ] `DashboardRenderView.swift`
  - Rewrite layout rendering to use `DashboardLayout` and `LayoutItem`
  - Update visualization rendering to use new `Visualization` entity
  - Update to reference `DataSource` instead of embedded searches

### Worker Files
- [ ] `DashboardRefreshWorker.swift`
  - Update to work with `DataSource` entities
  - Update search execution tracking

- [ ] `DashboardTokenManager.swift`
  - Rewrite to work with `DashboardInput` instead of `TokenEntity`
  - Parse choices from `optionsJSON`

### Utility Files
- [ ] `VisualizationFormatting.swift`
  - Update to read from `optionsJSON` and `contextJSON`
  - Remove old `chartOptions` accessors

## Migration Strategy

### Phase 1: Infrastructure (Current)
1. ✅ Merge DashboardKit refactor
2. ⏳ Update Xcode project dependencies
3. ⏳ Replace CoreData model reference

### Phase 2: Core App
1. Update `SplTvApp.swift` to import DashboardKit
2. Update `Persistence.swift` to use DashboardKit's CoreData model
3. Ensure app can build (views will be broken)

### Phase 3: Views (Order matters)
1. **Start with DashboardTokenManager** - Foundation for inputs
2. **Update DashboardMainView** - Navigation and sidebar
3. **Update DashboardRenderView** - Most complex, layout rendering
4. **Update DashboardMonitorView** - Monitoring functionality
5. **Update DashboardRefreshWorker** - Background refresh

### Phase 4: Testing
1. Test dashboard loading
2. Test input handling
3. Test search execution
4. Test refresh workers
5. Test visualization rendering

## Breaking Changes to Handle

### 1. No More Rows
Old code iterates through rows:
```swift
for row in dashboard.rowsArray {
    for panel in row.panelsArray {
        // render panel
    }
}
```

New code uses layout items:
```swift
let layout = dashboard.layout
for item in layout.layoutItems.sorted(by: { $0.position < $1.position }) {
    if let viz = item.visualization {
        // render visualization
    }
}
```

### 2. Inputs vs Tokens
Old code accesses tokens:
```swift
for fieldset in dashboard.fieldsetsArray {
    for token in fieldset.tokensArray {
        // render input
    }
}
```

New code accesses inputs:
```swift
for input in dashboard.inputs {
    // Parse choices from optionsJSON
    if let optionsJSON = input.optionsJSON,
       let options = try? JSONDecoder().decode(InputOptions.self, from: Data(optionsJSON.utf8)) {
        // render input with options
    }
}
```

### 3. Search Execution
Old code creates search executions:
```swift
let execution = SearchExecutionEntity(context: context)
execution.search = searchEntity
```

New code uses data sources:
```swift
let execution = SearchExecution(context: context)
execution.dataSource = dataSource
execution.dataSourceConfig = config
```

## Estimated Complexity

- **DashboardTokenManager**: Medium (rewrite input parsing)
- **DashboardMainView**: Low (straightforward entity swap)
- **DashboardRenderView**: **High** (complete layout rewrite)
- **DashboardMonitorView**: Medium (update entity references)
- **DashboardRefreshWorker**: Medium (update entity references)
- **VisualizationFormatting**: Low (JSON accessor updates)

## Next Steps

1. Update Xcode project to depend on DashboardKit
2. Remove SplTV's local CoreData model (use DashboardKit's)
3. Begin Phase 2 migration
