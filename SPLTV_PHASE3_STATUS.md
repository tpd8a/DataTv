# SplTV Phase 3 Status: Search Execution Refactoring

## Overview

Phase 3 focuses on refactoring search execution and results display from the massive 3,098-line DashboardMonitorView into modular components.

## Progress

### ✅ Completed Components

**1. ExecutionTimelineView (208 lines)**
- Timeline slider with playback controls
- Play/pause/next/previous navigation
- Jump to latest execution
- Status badges and timestamps
- **Extracted from:** SearchResultsTableView (lines 958-1086)

**2. SearchExecutionAdapter (107 lines)**
- Bridges DashboardKit's SearchExecution entity
- Provides display properties (status, duration, colors)
- Results access and sorting
- Collection helpers for batch conversion

**3. SearchResultsTableView (175 lines)**
- Container for execution timeline and results
- Manages execution loading from CoreData
- Handles playback state and timers
- Notification listener for search completion
- **Reduced from:** 1,800+ lines to 175 lines (-90%!)

## Architecture

```
SearchResultsTableView (Container)
├── ExecutionTimelineView (Controls)
│   ├── Header with refresh button
│   ├── Playback controls (play/pause/prev/next)
│   ├── Timeline slider
│   └── Status display
└── ResultsTableContent (Display)
    └── [TO BE IMPLEMENTED]
```

## Entity Migration Status

### Current State

The code currently uses **SearchExecutionEntity** from the old `d8aTvCore` model. This is temporary for compatibility.

### Target State

Should use **SearchExecution** from the new `DashboardKit` model:

```swift
// OLD (d8aTvCore)
SearchExecutionEntity
├── id: String
├── dashboardId: String
├── searchId: String
├── startTime: Date
├── endTime: Date?
├── executionStatus: String
└── results: Set<SearchResultEntity>

// NEW (DashboardKit)
SearchExecution
├── id: UUID
├── executionId: String (Splunk job ID)
├── startTime: Date
├── endTime: Date?
├── status: String
├── resultCount: Int16
├── errorMessage: String?
├── dataSource: DataSource (relationship)
└── results: Set<SearchResult>
```

### Migration Path

1. **SearchResultsTableView** needs to:
   - Fetch `SearchExecution` instead of `SearchExecutionEntity`
   - Use relationship to `DataSource` instead of separate `searchId`
   - Update predicates for new schema

2. **CoreDataManager** needs to:
   - Provide fetch methods for `SearchExecution`
   - Link executions to `DataSource` entities
   - Handle both old and new formats during transition

3. **ResultsTableContent** needs to:
   - Parse `SearchResult` entities (JSON stored results)
   - Handle comparison between executions
   - Display formatted table with cell changes

## Remaining Work

### High Priority

1. **ResultsTableContent Implementation** (est. 400-600 lines)
   - Table header with sortable columns
   - Table rows with cell formatting
   - Cell change detection and highlighting
   - Splunk color palette support
   - **Complexity:** High (was 1,400+ lines in old file)

2. **Entity Migration** (est. 2-3 hours)
   - Update fetch requests for SearchExecution
   - Fix relationship navigation
   - Test with both dashboard formats

3. **CoreDataManager API Updates** (est. 2-3 hours)
   - Add SearchExecution fetch methods
   - Link to DataSource instead of searchId
   - Ensure notification compatibility

### Medium Priority

4. **DashboardRefreshWorker** Update (est. 3-4 hours)
   - Use DataSource entities instead of SearchEntity
   - Update dependency tracking for ds.chain
   - Fix timer key generation (use DataSource.sourceId)

5. **Search Execution Service** (est. 2-3 hours)
   - Centralize search execution logic
   - Handle token substitution
   - Manage execution lifecycle

### Low Priority

6. **Testing** (est. 2-3 hours)
   - Test timeline playback
   - Test with real search results
   - Verify change detection works

7. **Optimization** (est. 1-2 hours)
   - Reduce CoreData fetches
   - Optimize large result sets
   - Add pagination if needed

## Code Metrics

### Before (DashboardMonitorView.swift.old)
- Total: 3,098 lines
- SearchResultsTableView section: ~1,800 lines
- ResultsTableContent: ~1,400 lines
- Supporting code: ~600 lines

### After (so far)
- ExecutionTimelineView: 208 lines
- SearchExecutionAdapter: 107 lines
- SearchResultsTableView: 175 lines
- **Total: 490 lines (-73% reduction!)**

### Still To Create
- ResultsTableContent: ~400-600 lines (estimated)
- ResultsTableHeader: ~100-150 lines
- ResultsTableCell: ~150-200 lines
- **Estimated total: 1,140-1,440 lines (still way better than 1,800!)**

## Benefits of Refactoring

1. **Modularity** - Each component has single responsibility
2. **Testability** - Smaller units easier to test
3. **Maintainability** - Clear separation of concerns
4. **Reusability** - Timeline component can be used elsewhere
5. **Readability** - No more 3,000-line files!

## Next Steps

1. Implement ResultsTableContent with modular cell components
2. Update entity fetching to use SearchExecution from DashboardKit
3. Test timeline playback with real data
4. Update DashboardRefreshWorker for DataSource entities
5. Create SearchExecutionService for centralized logic

## Known Issues

1. **Entity Compatibility** - Using old SearchExecutionEntity temporarily
2. **ResultsTableContent** - Currently placeholder, needs full implementation
3. **Notification Names** - May need alignment with CoreDataManager
4. **DashboardRefreshWorker** - Still uses old entity types

## Estimated Remaining Effort

- ResultsTableContent implementation: 4-6 hours
- Entity migration: 2-3 hours
- DashboardRefreshWorker update: 3-4 hours
- Testing and integration: 2-3 hours
- **Total Phase 3 remaining: 11-16 hours**
