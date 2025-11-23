# d8aTvCore Migration Status

## Overview
This document tracks the migration from legacy d8aTvCore entities to modern DashboardKit entities in the SplTV app.

**Last Updated**: 2025-11-23
**Status**: ✅ **MIGRATION COMPLETE** - 100% DashboardKit, zero d8aTvCore dependencies!

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

**✅ NONE** - All d8aTvCore dependencies have been removed!

### Previously Dependent Files (Now Migrated)
1. **DashboardRenderView.swift** - ✅ Migrated to DashboardKit entities
2. **VisualizationFormatting.swift** - ✅ Removed legacy entity support
3. **SplTvApp.swift** - ✅ Removed d8aTvCore import

---

## Migration Roadmap

### Phase 7: DashboardRenderView Migration
**Status**: ✅ **COMPLETE**
**Completed**: 2025-11-23

**Achievements**:
1. ✅ Created DashboardStudioRenderView for Dashboard entity
2. ✅ Implemented layout rendering from DashboardLayout/LayoutItem
3. ✅ Replaced panel system with visualization grid
4. ✅ Migrated to modern SwiftUI layout
5. ✅ Updated navigation to use new view
6. ✅ Removed d8aTvCore import from SplTvApp.swift

### Phase 8: Remove Legacy Support
**Status**: ✅ **COMPLETE**
**Completed**: 2025-11-23

**Achievements**:
1. ✅ Removed VisualizationEntity support from VisualizationFormatting.swift
2. ✅ Removed d8aTvCore import entirely
3. ✅ Achieved zero d8aTvCore dependencies
4. ✅ Updated documentation

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
- **Modern Components**: 7+ modular components
- **Entity Migration**: 100% - All views use DashboardKit entities
- **CoreData Model**: Fully unified on DashboardKit model
- **Compilation**: All files compile successfully
- **d8aTvCore Dependencies**: ✅ **ZERO** - Complete removal achieved!
- **Migration Complete**: All 8 phases finished

### Final Status 🎉
- **Full Migration**: ✅ 100% Complete
- **Zero d8aTvCore**: ✅ All imports removed
- **Legacy Views**: ✅ All migrated or replaced
- **Architecture**: Pure DashboardKit implementation

---

## Recent Enhancements (Post-Migration)

### Saved Search Metadata Feature (2025-11-23)
After completing the migration, we added support for proper saved search handling:

**Problem**: Saved searches with refresh intervals need owner and app context for proper execution
- Old format: `| loadjob {ref}` ❌ (incorrect)
- New format: `| loadjob savedsearch="{owner}:{app}:{ref}"` ✅ (correct)

**Solution**: Automatic metadata population during dashboard sync

**Implementation**:
1. Added `owner` and `app` fields to DataSource entity (CoreData schema)
2. Added `owner` and `app` to DataSourceOptions struct (models)
3. Created `fetchSavedSearchMetadata(ref:)` in SplunkDataSource
   - Executes: `| rest /servicesNS/-/-/saved/searches | search title="{ref}"`
   - Extracts: `eai:acl.owner`, `eai:acl.app`, `search` query
4. Created `populateSavedSearchMetadata(dashboardId:dataSourceConfigId:)` in CoreDataManager
   - Finds DataSources with `ref` but missing owner/app
   - Fetches metadata from Splunk
   - Updates CoreData with owner/app values
5. Integrated into `saveDashboard()` - automatically runs after syncing each dashboard
6. Updated loadjob query building to use `"{owner}:{app}:{ref}"` format

**Files Modified**:
- `DashboardModel.xcdatamodel/contents` - Added owner/app attributes
- `DataSource+CoreDataProperties.swift` - Added Swift properties
- `DashboardStudioModels.swift` - Added owner/app to DataSourceOptions
- `SplunkDataSource.swift` - Added fetchSavedSearchMetadata method
- `CoreDataManager.swift` - Added populateSavedSearchMetadata, updated saveDashboard
- `SplTvApp.swift` - Pass dataSourceConfigId to saveDashboard calls

**Benefits**:
- Proper saved search execution with correct owner:app:ref format
- Automatic metadata fetch (no manual configuration needed)
- Works with both token and basic authentication
- Configuration-based SplunkDataSource initialization preserves credentials

### Configuration-Based SplunkDataSource Integration
Added convenience initializer to reuse session configuration:

```swift
// Old: Create with individual parameters (loses credentials)
SplunkDataSource(host: host, port: port, authToken: token, ...)

// New: Create with full configuration (preserves all credentials)
SplunkDataSource(configuration: config)
```

This ensures the SplunkDataSource used for metadata fetching has the same credentials as the dashboard sync session, preventing authentication failures.

---

## Contact

For questions about this migration:
- See [README.md](README.md) for project overview
- See [PROJECT_ARCHITECTURE.md](PROJECT_ARCHITECTURE.md) for detailed architecture
- See [SPLTV_100_PERCENT_COMPLETE.md](SPLTV_100_PERCENT_COMPLETE.md) for Phase 1-6 completion status (if exists)
- See [SPLTV_FINAL_STATUS.md](SPLTV_FINAL_STATUS.md) for overall refactoring progress (if exists)
