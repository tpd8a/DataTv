# d8aTvCore Migration Status

## Overview
This document tracks the migration from legacy d8aTvCore entities to modern DashboardKit entities in the SplTV app.

**Last Updated**: 2025-11-18
**Status**: Partial Migration - Core functionality uses DashboardKit, some legacy views remain

---

## Migration Summary

### ✅ Fully Migrated (Uses DashboardKit)
- **DashboardMainView.swift** - Main dashboard list view uses `Dashboard` entity
- **SearchResultsTableView.swift** - Table view uses `SearchExecution` and `SearchResult` entities
- **SearchRowView.swift** - Data source rows use `DataSource` via `DataSourceAdapter`
- **DashboardDetailView.swift** - Detail view uses `Dashboard` and `DataSource` entities
- **ExecutionTimelineView.swift** - Timeline uses `SearchExecution` entity
- **ResultsTableContent.swift** - Results table uses `SearchExecution` and `SearchResult` entities
- **SplTvApp.swift (Settings)** - Settings/export now uses `Dashboard` and `PersistenceController`
- **PersistenceController** - Uses DashboardKit's CoreData model
- **All Phase 3-6 components** - Modern modular architecture (7 new components)

### ⏸️ Partial Migration (Compatibility Mode)
These files use legacy entities but have DashboardKit imports for compatibility:

#### VisualizationFormatting.swift
- **Status**: Compatibility bridge
- **Legacy Usage**: `VisualizationEntity` support
- **Modern Usage**: `Visualization` support
- **Strategy**: Dual-mode formatter supporting both old and new entities
- **Import**: `import d8aTvCore`
- **Reason**: Backward compatibility during transition
- **Next Steps**: Can be fully migrated once all visualizations use new format

#### DashboardRenderView.swift
- **Status**: Legacy view
- **Legacy Usage**:
  - `DashboardEntity` - Main dashboard structure
  - `RowEntity` - Dashboard rows
  - `PanelEntity` - Dashboard panels
  - `CoreDataTokenType` - Token/input types
- **Modern Usage**: None
- **Import**: `import d8aTvCore`
- **Preview**: Disabled (commented out)
- **Reason**: Complete view designed for legacy XML-based dashboard structure
- **Next Steps**: **Full rewrite required** to use DashboardKit entities
- **Migration Complexity**: HIGH - ~780 lines, complex Bootstrap grid layout

---

## CoreDataManager Usage

### Old: d8aTvCore CoreDataManager
```swift
// Location: d8aTv/Sources/d8aTvCore/CoreDataManager.swift
// Model: tmpDashboardModel (legacy entities)
@MainActor
public class CoreDataManager {
    public static var shared = CoreDataManager()
    var persistentContainer: NSPersistentContainer
    var context: NSManagedObjectContext
    func clearAllData() throws
    func fetchAllDashboards() -> [DashboardEntity]
}
```

**Entities**:
- DashboardEntity, RowEntity, PanelEntity
- SearchEntity, VisualizationEntity
- SearchExecutionEntity, SearchResultEntity
- TokenEntity, FieldsetEntity, etc.

### New: DashboardKit CoreDataManager
```swift
// Location: d8aTv/Sources/DashboardKit/Managers/CoreDataManager.swift
// Model: DashboardModel (modern entities)
public actor CoreDataManager {
    public static let shared = CoreDataManager()
    var viewContext: NSManagedObjectContext
    func saveDashboard(_: DashboardStudioConfiguration) async throws -> UUID
    func saveDataSourceConfig(...) async throws -> UUID
    func executeSearch(...) async throws -> UUID
}
```

**Entities**:
- Dashboard, DataSource, Visualization
- SearchExecution, SearchResult
- DashboardInput, DashboardLayout, LayoutItem
- DataSourceConfig

### App Usage (After This Commit)
- **SplTvApp.swift**: Uses `PersistenceController` (wraps DashboardKit model)
- **DashboardMainView.swift**: Uses `DashboardKit.CoreDataManager.shared.viewContext`
- **DashboardRenderView.swift**: Still uses d8aTvCore (legacy view, marked for migration)
- **VisualizationFormatting.swift**: Imports d8aTvCore for compatibility only

---

## Entity Mapping (Legacy → Modern)

| Legacy (d8aTvCore) | Modern (DashboardKit) | Status |
|-------------------|---------------------|---------|
| DashboardEntity | Dashboard | ✅ Migrated |
| SearchEntity | DataSource | ✅ Migrated |
| SearchExecutionEntity | SearchExecution | ✅ Migrated |
| SearchResultEntity | SearchResult | ✅ Migrated |
| VisualizationEntity | Visualization | ✅ Migrated (dual-support) |
| RowEntity | DashboardLayout + LayoutItem | ⏸️ Not yet migrated |
| PanelEntity | LayoutItem + Visualization | ⏸️ Not yet migrated |
| TokenEntity | DashboardInput | ✅ Migrated |
| FieldsetEntity | DashboardInput (grouped) | ✅ Migrated |

---

## Key Differences

### ID Types
- **Legacy**: String IDs (`dashboard.id: String`)
- **Modern**: UUID IDs (`dashboard.id: UUID?`)

### Structure
- **Legacy**: XML-based (rows → panels → searches)
- **Modern**: Studio-based (layout → items → visualizations)

### Data Access
- **Legacy**: Nested relationships (`dashboard.rows.panels.searches`)
- **Modern**: Flat relationships (`dashboard.dataSources`, `dashboard.visualizations`)

---

## Files Still Using d8aTvCore

### Critical Path (3 files)
1. **DashboardRenderView.swift** (780 lines)
   - Full XML dashboard renderer
   - Bootstrap grid layout system
   - Complex row/panel/visualization hierarchy
   - **Action Required**: Complete rewrite for DashboardKit

2. **VisualizationFormatting.swift** (150 lines)
   - Dual-mode visualization formatter
   - **Action Required**: Remove legacy support once all visualizations migrated

3. **SplTvApp.swift** (header only)
   - Import statement: `import d8aTvCore`
   - **Action Required**: Can be removed if DashboardRenderView is migrated or moved

---

## Migration Roadmap

### Phase 7 (Future): DashboardRenderView Migration
**Complexity**: HIGH
**Est. Effort**: 2-3 days
**Priority**: LOW (view not actively used)

**Steps**:
1. Create new `DashboardStudioRenderView.swift` for Dashboard entity
2. Implement layout rendering from DashboardLayout/LayoutItem
3. Replace panel system with visualization grid
4. Migrate Bootstrap grid to modern SwiftUI layout
5. Update navigation to use new view
6. Deprecate old DashboardRenderView.swift
7. Remove d8aTvCore import from SplTvApp.swift

### Phase 8 (Future): Remove Legacy Support
**Complexity**: LOW
**Est. Effort**: 1 day
**Priority**: LOW

**Steps**:
1. Remove VisualizationEntity support from VisualizationFormatting.swift
2. Remove d8aTvCore import entirely
3. Archive/delete legacy .old files if still present
4. Update documentation

---

## Why Not Fully Migrate Now?

### DashboardRenderView.swift
- **Reason 1**: View is designed for legacy XML dashboard structure
- **Reason 2**: Modern DashboardKit uses Studio layout (different paradigm)
- **Reason 3**: View may not be actively used in production
- **Reason 4**: Migration requires complete architectural redesign
- **Decision**: Mark as legacy, defer migration until view is needed

### VisualizationFormatting.swift
- **Reason 1**: Provides compatibility bridge during transition
- **Reason 2**: Minimal maintenance burden (just imports)
- **Reason 3**: Easy to remove once legacy visualizations are gone
- **Decision**: Keep dual-support for now, remove in Phase 8

---

## Current Architecture

```
SplTV App
├── Modern Stack (DashboardKit)
│   ├── PersistenceController → DashboardKit model
│   ├── DashboardMainView → Dashboard entities
│   ├── SearchResultsTableView → SearchExecution/SearchResult
│   ├── DashboardDetailView → Dashboard/DataSource
│   ├── Phase 3-6 Components (7 modern components)
│   └── SplTvApp Settings → Dashboard export
│
├── Compatibility Layer
│   ├── VisualizationFormatting → Both old and new
│   └── DataSourceAdapter → Bridges DataSource to views
│
└── Legacy Stack (d8aTvCore)
    └── DashboardRenderView → DashboardEntity/RowEntity/PanelEntity
        ├── DashboardMainRowView
        ├── DashboardPanelView
        ├── BootstrapGridLayout
        └── CompactSearchResultsView (uses modern entities internally)
```

---

## Testing Notes

### Verified Working
- ✅ Dashboard list loads from Dashboard entity
- ✅ Dashboard detail shows DataSource entities
- ✅ Search execution tracking with SearchExecution
- ✅ Results table displays SearchResult entities
- ✅ Visualization options load from DataSource
- ✅ Token management with DashboardInput
- ✅ Settings dashboard export uses new entities
- ✅ Clear all data works with DashboardKit entities

### Not Tested (Legacy)
- ⚠️ DashboardRenderView (legacy view, may have issues)
- ⚠️ XML dashboard rendering (legacy format)
- ⚠️ Row/Panel layout system (legacy structure)

---

## Breaking Changes (This Commit)

### SplTvApp.swift
- **Before**: Used `CoreDataManager.shared` (d8aTvCore) for database operations
- **After**: Uses `persistenceController.container` (PersistenceController)
- **Impact**: Settings view now works with Dashboard entities only

### DashboardExportView
- **Before**: Exported DashboardEntity with app filtering
- **After**: Exports Dashboard entity with simple JSON format
- **Impact**: Export format changed, no app filtering available

### DashboardRenderView Preview
- **Before**: Active preview using CoreDataManager.shared
- **After**: Preview commented out (disabled)
- **Impact**: No Xcode preview available for this view

---

## Recommendations

1. **Short Term**:
   - Continue using current hybrid architecture
   - Monitor DashboardRenderView usage in production
   - Collect requirements for Studio layout rendering

2. **Medium Term**:
   - Implement DashboardStudioRenderView if needed
   - Migrate all visualizations to new format
   - Remove VisualizationEntity compatibility

3. **Long Term**:
   - Fully deprecate d8aTvCore dependency
   - Archive legacy dashboard XML support
   - Pure DashboardKit architecture

---

## Success Metrics

### Achieved ✅
- **Code Reduction**: 47% reduction (from previous phases)
- **Modern Components**: 7 new modular components
- **Entity Migration**: 90%+ of views use DashboardKit entities
- **CoreData Model**: Unified on DashboardKit model
- **Compilation**: All files compile successfully
- **d8aTvCore Dependencies**: Reduced to 2-3 files only

### Remaining 🎯
- **Full Migration**: 10% (DashboardRenderView only)
- **Zero d8aTvCore**: Remove final imports
- **Legacy Views**: Archive or rewrite DashboardRenderView
- **Test Coverage**: Add tests for migrated components

---

## Contact

For questions about this migration:
- See SPLTV_100_PERCENT_COMPLETE.md for Phase 1-6 completion status
- See SPLTV_FINAL_STATUS.md for overall refactoring progress
- See SPLTV_PHASE4_COMPLETE.md for entity migration details
