# CoreData Schema Comparison: Old vs New (DashboardKit)

## Overview

The new DashboardKit schema is a ground-up redesign that provides better data source awareness, execution tracking, and multi-format support while maintaining compatibility with your existing dashboards.

## Key Architectural Changes

### 1. **Data Source Awareness** (NEW!)

**Old Schema:**
- Searches were embedded directly in panels/visualizations
- No separate entity for data sources
- Hard to track which searches are related or chained
- Search execution was not tracked

```
PanelEntity -> SearchEntity (embedded query)
```

**New Schema:**
- **DataSource** is a first-class entity
- Supports chaining with `ds.chain` type (like Dashboard Studio)
- Each unique search becomes a DataSource
- Can be referenced by multiple visualizations
- Tracks execution history

```
Dashboard -> DataSource (reusable, trackable)
         -> Visualization -> references DataSource
```

**Example:**
```json
// Old: Search embedded in panel
{
  "SearchEntity": {
    "query": "index=_internal | stats count",
    "panel": {...}
  }
}

// New: DataSource is separate and reusable
{
  "DataSource": {
    "sourceId": "base_search",
    "type": "ds.search",
    "query": "index=_internal | stats count"
  },
  "DataSource": {
    "sourceId": "derived_search",
    "type": "ds.chain",
    "extendsId": "base_search",  // ← Chains from base_search
    "query": "| stats sum(count) by host"
  }
}
```

### 2. **Search Execution Tracking** (NEW!)

**Old Schema:**
- No tracking of when searches were executed
- No historical results stored
- Lost data when app restarts

**New Schema:**
- **SearchExecution** entity tracks every search run
- Stores execution ID, start/end times, status
- **SearchResult** entity stores actual results
- Enables timeline features that web doesn't have

```json
{
  "DataSource": {
    "sourceId": "base_new",
    "executions": [
      {
        "executionId": "1731613990.123",  // Splunk job ID
        "startTime": "2025-11-14T20:13:10Z",
        "endTime": "2025-11-14T20:13:15Z",
        "status": "completed",
        "resultCount": 4,
        "results": [
          {"rowIndex": 0, "resultJSON": "{...}"},
          {"rowIndex": 1, "resultJSON": "{...}"}
        ]
      }
    ]
  }
}
```

**Benefits:**
- View historical search results offline
- Compare results over time (timeline feature)
- Track search performance
- Replay old searches without re-executing

### 3. **Layout Separation**

**Old Schema:**
- Layout was implicit in Row -> Panel hierarchy
- Row ordering via `orderIndex`
- Panel ordering via `orderIndex`

```
Dashboard
  └── RowEntity (orderIndex: 0)
       ├── PanelEntity (orderIndex: 0)
       └── PanelEntity (orderIndex: 1)
```

**New Schema:**
- **DashboardLayout** is explicit
- **LayoutItem** defines positioning
- Supports both bootstrap (SimpleXML) and absolute/grid (Dashboard Studio)

```
Dashboard
  └── DashboardLayout (type: "bootstrap" or "absolute")
       ├── LayoutItem (position: 0, width: "12", viz ref)
       ├── LayoutItem (position: 1, width: "6", viz ref)
       └── LayoutItem (position: 2, width: "6", viz ref)
```

**Benefits:**
- Same schema handles SimpleXML and Dashboard Studio
- Easy conversion between layout types
- Explicit positioning information

### 4. **Input/Token Handling**

**Old Schema:**
- Complex hierarchy: FieldsetEntity -> TokenEntity -> TokenChoiceEntity
- Choices stored as separate entities

```
FieldsetEntity
  └── TokenEntity
       ├── TokenChoiceEntity (value: "option1")
       ├── TokenChoiceEntity (value: "option2")
       └── TokenChoiceEntity (value: "option3")
```

**New Schema:**
- Simplified to **DashboardInput**
- Choices stored as JSON in `optionsJSON`
- Cleaner, more flexible

```json
{
  "DashboardInput": {
    "inputId": "input_filename",
    "type": "input.dropdown",
    "token": "filename",
    "defaultValue": "*.log",
    "optionsJSON": "{
      \"choices\": [
        {\"label\": \"splunk ui\", \"value\": \"splunk_ui_access.log\"},
        {\"label\": \"all\", \"value\": \"*.log\"}
      ]
    }"
  }
}
```

### 5. **Visualization Options**

**Old Schema:**
- Separate `chartOptions` dictionary with formats array
- Options scattered across multiple fields

```
VisualizationEntity {
  drilldown: "none",
  chartOptions: {
    options: {...},
    formats: [{...}]
  }
}
```

**New Schema:**
- All options in `optionsJSON`
- Context/formatting in `contextJSON`
- Clean separation of concerns

```json
{
  "Visualization": {
    "type": "splunk.table",
    "optionsJSON": "{\"drilldown\":\"none\",\"count\":\"5\"}",
    "contextJSON": "{\"formats\":[{\"field\":\"error\",\"palette\":{...}}]}"
  }
}
```

### 6. **Multi-Source Support** (NEW!)

**Old Schema:**
- No concept of different data source types
- Assumed all queries go to Splunk

**New Schema:**
- **DataSourceConfig** entity for different backends
- Support for Splunk, Elastic, Prometheus
- Each DataSource/SearchExecution linked to specific config

```json
{
  "DataSourceConfig": {
    "name": "Production Splunk",
    "type": "splunk",
    "host": "splunk.example.com",
    "port": 8089,
    "isDefault": true
  },
  "DataSourceConfig": {
    "name": "Elastic Cluster",
    "type": "elastic",
    "host": "elastic.example.com",
    "port": 9200
  }
}
```

## Entity Mapping

| Old Schema | New Schema | Notes |
|------------|------------|-------|
| DashboardEntity | Dashboard | Added `formatType`, `rawJSON`, `rawXML` |
| FieldsetEntity | DashboardInput | Simplified, choices in JSON |
| TokenEntity | DashboardInput | Combined with fieldset |
| TokenChoiceEntity | (JSON in optionsJSON) | No longer separate entity |
| RowEntity | LayoutItem | Layout is now explicit |
| PanelEntity | Visualization + LayoutItem | Separated viz from layout |
| SearchEntity | DataSource | First-class entity, reusable |
| VisualizationEntity | Visualization | Options in JSON format |
| CustomContentEntity | (depends on type) | Integrated into appropriate entity |
| — | SearchExecution | **NEW**: Track executions |
| — | SearchResult | **NEW**: Store historical results |
| — | DataSourceConfig | **NEW**: Multi-source support |
| — | DashboardLayout | **NEW**: Explicit layout management |

## Field Mapping Examples

### Dashboard

| Old Field | New Field | Changes |
|-----------|-----------|---------|
| dashboardName | title | Renamed for clarity |
| dashboardDescription | dashboardDescription | Same |
| appName | — | Removed (use DataSourceConfig) |
| xmlContent | rawXML | Renamed, always preserved |
| — | rawJSON | **NEW**: Store Dashboard Studio JSON |
| — | formatType | **NEW**: "simpleXML" or "dashboardStudio" |
| version | — | Moved to XML/JSON content |
| theme | — | Moved to layout options |

### Search → DataSource

| Old Field (SearchEntity) | New Field (DataSource) | Changes |
|--------------------------|------------------------|---------|
| query | query | Same |
| id (xml id) | sourceId | Renamed for clarity |
| earliestTime | (in optionsJSON) | Moved to query parameters |
| latestTime | (in optionsJSON) | Moved to query parameters |
| refresh | refresh | Same |
| refreshType | refreshType | Same |
| base | extendsId | Renamed, now supports chaining |
| autostart | — | Removed (handled by refresh settings) |
| tokenReferences | (in optionsJSON) | Moved to JSON |

### Visualization

| Old Field | New Field | Changes |
|-----------|-----------|---------|
| type | type | Same, but prefixed (e.g., "splunk.table") |
| title | title | Same |
| drilldown | (in optionsJSON) | Moved to options |
| chartOptions.options | optionsJSON | Flattened to JSON |
| chartOptions.formats | contextJSON | Separated into context |

## Benefits of New Schema

### 1. **Timeline Feature**
- Store all search results in CoreData
- View historical data offline
- Compare metrics over time
- Something web-based Splunk can't do!

### 2. **Better Performance**
- DataSources are reusable (one search, multiple visualizations)
- Chaining reduces duplicate queries
- Cached results in SearchResult entities

### 3. **Multi-Format Support**
- Same schema for SimpleXML and Dashboard Studio
- Easy conversion between formats
- Future-proof for new dashboard types

### 4. **Data Source Flexibility**
- Add Elastic or Prometheus without schema changes
- Track which backend served which results
- Mix multiple sources in one dashboard

### 5. **Cleaner Data Model**
- Less nesting (JSON instead of entities for lists)
- Fewer total entities (simpler CoreData graph)
- Easier to query and filter

## Migration Path

When migrating from old schema to new:

1. **Parse xmlContent** using SimpleXMLParser
2. **Create DataSource entities** from SearchEntity objects
3. **Detect search chaining** (searches with `base` attribute)
4. **Create Visualization entities** from VisualizationEntity
5. **Build DashboardLayout** from Row/Panel structure
6. **Convert TokenEntity** to DashboardInput with choices in JSON
7. **Preserve rawXML** in Dashboard entity
8. **Set formatType** to "simpleXML"

The DashboardConverter in DashboardKit handles most of this automatically!

## Example Usage Comparison

### Old Schema: Getting Search Query
```swift
// Navigate: Dashboard -> Row -> Panel -> Search
let dashboard: DashboardEntity = ...
let firstRow = dashboard.rows?.first
let firstPanel = firstRow?.panels?.first
let search = firstPanel?.searches?.first
let query = search?.query
```

### New Schema: Getting Search Query
```swift
// Direct access to DataSource
let dashboard: Dashboard = ...
let dataSource = dashboard.dataSources?.first
let query = dataSource?.query

// Or via Visualization
let viz = dashboard.visualizations?.first
let query = viz?.dataSource?.query
```

### Old Schema: No Historical Data
```swift
// Can't access historical results - they're gone after execution
```

### New Schema: Access Historical Results
```swift
let dashboard: Dashboard = ...
let dataSource = dashboard.dataSources?.first
let executions = dataSource?.executions  // All historical runs

// Get last execution results
let lastExecution = executions?.sorted { $0.startTime! > $1.startTime! }.first
let results = lastExecution?.results?.sorted { $0.rowIndex < $1.rowIndex }

for result in results {
    let json = result.resultJSON  // Historical data!
}
```

## Summary

The new DashboardKit schema is:

✅ **More data-source aware** - DataSource as first-class entity
✅ **Tracks execution history** - SearchExecution and SearchResult
✅ **Multi-format** - SimpleXML and Dashboard Studio in same schema
✅ **Multi-source** - Splunk, Elastic, Prometheus support
✅ **Cleaner** - Less entity nesting, more JSON
✅ **Timeline-enabled** - Historical results for offline viewing
✅ **Future-proof** - Extensible for new dashboard types

While maintaining:
✅ **XML preservation** - rawXML field keeps original
✅ **All data** - Nothing is lost in migration
✅ **Compatibility** - SimpleXMLParser handles old format
