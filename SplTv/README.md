# SplTv - Splunk Dashboard Viewer for macOS

A native macOS application for viewing and rendering Splunk dashboards using SwiftUI and the modern DashboardKit architecture.

## Overview

SplTv is a standalone dashboard viewer that connects to Splunk Enterprise instances to fetch, render, and interact with both Dashboard Studio (v2) and SimpleXML (v1) dashboards. It provides a native macOS experience with support for visualizations, search execution, data refresh, and interactive inputs.

## Key Features

- **Dashboard Studio (v2) Support**: Full rendering of modern Dashboard Studio dashboards with absolute/grid layouts
- **SimpleXML (v1) Support**: Backward compatibility with legacy SimpleXML dashboards
- **Live Search Execution**: Execute SPL queries against Splunk with real-time results
- **Visualization Support**: Tables, single values, charts with extensive formatting options
- **Dashboard Sync**: Fetch and cache dashboards from Splunk for offline viewing
- **Token/Input Support**: Interactive time pickers, dropdowns, and text inputs
- **Saved Search Support**: Load and execute saved searches with proper metadata (owner/app/ref)
- **Data Refresh**: Automatic and manual refresh with configurable intervals
- **Chained Searches**: Support for post-processing queries (ds.chain)
- **CoreData Persistence**: Local caching of dashboards, search executions, and results

## Architecture

SplTv is built on a modern **modular architecture** using the `DashboardKit` framework:

### DashboardKit Module (`d8aTv/Sources/DashboardKit/`)
Core framework providing:
- **CoreData Model**: Modern entities (Dashboard, DataSource, Visualization, SearchExecution, etc.)
- **Splunk Integration**: REST API client, search service, dashboard service
- **Parsers**: Dashboard Studio JSON parser, SimpleXML parser
- **Data Sources**: Protocol-based data source abstraction for Splunk (extensible to Elastic, Prometheus)
- **Managers**: CoreDataManager for persistence, SearchExecutionMonitor for tracking

### SplTv App (`SplTv/SplTv/`)
SwiftUI application providing:
- **Views**: DashboardRenderView, VisualizationViews (TableView, SingleValueView, etc.)
- **Settings**: Connection management, sync configuration, credential storage
- **UI**: Navigation, sidebar, search execution status, token inputs

### Data Flow
```
Splunk Enterprise
    ↓ (REST API)
SplunkDashboardService
    ↓ (fetch dashboard XML/JSON)
Parsers (Studio/SimpleXML)
    ↓ (configuration objects)
CoreDataManager
    ↓ (persist entities)
CoreData (DashboardModel.sqlite)
    ↓ (fetch entities)
DashboardRenderView
    ↓ (execute searches)
SplunkDataSource → SplunkSearchService
    ↓ (results)
Visualization Views (SwiftUI)
```

## Getting Started

### Prerequisites
- macOS 14.0 or later
- Xcode 15.0 or later
- Splunk Enterprise 8.x or 9.x instance

### Build & Run
1. Clone the repository
2. Open `SplTv.xcodeproj` in Xcode
3. Build the project (Cmd+B)
4. Run the application (Cmd+R)

### Initial Setup
1. Open Settings (Cmd+,)
2. Configure Splunk connection:
   - Base URL (e.g., `https://splunk.example.com:8089`)
   - Authentication (token or basic auth)
   - Default app and owner
3. Sync dashboards from the Dashboards tab
4. Select a dashboard to view

## CoreData Entities

The DashboardKit CoreData model includes:

| Entity | Purpose |
|--------|---------|
| `Dashboard` | Dashboard metadata, title, format type |
| `DataSource` | SPL queries, saved search references |
| `Visualization` | Viz type, options, formatting |
| `DashboardLayout` | Layout structure (absolute/grid/bootstrap) |
| `LayoutItem` | Positioning information for visualizations |
| `DashboardInput` | Time pickers, dropdowns, text inputs |
| `SearchExecution` | Search job tracking, status, timestamps |
| `SearchResult` | Result rows, cached data |
| `DataSourceConfig` | Splunk connection configurations |

## Documentation Index

### Architecture & Migration
- [PROJECT_ARCHITECTURE.md](PROJECT_ARCHITECTURE.md) - Detailed architecture overview
- [D8ATVCORE_MIGRATION_STATUS.md](D8ATVCORE_MIGRATION_STATUS.md) - Migration from legacy d8aTvCore

### Features
- [DASHBOARD_EXPORT_FEATURE.md](SplTv/DASHBOARD_EXPORT_FEATURE.md) - Export dashboards to JSON
- [DASHBOARD_TOKENS_IMPLEMENTATION.md](SplTv/DASHBOARD_TOKENS_IMPLEMENTATION.md) - Token substitution and inputs
- [ANIMATION_ENHANCEMENTS.md](SplTv/ANIMATION_ENHANCEMENTS.md) - Visualization animations

### Visualization & Formatting
- [VISUALIZATION_OPTIONS_GUIDE.md](SplTv/VISUALIZATION_OPTIONS_GUIDE.md) - Complete visualization options reference
- [VISUALIZATION_OPTIONS_QUICK_REF.md](SplTv/VISUALIZATION_OPTIONS_QUICK_REF.md) - Quick reference guide
- [SPLUNK_FORMATTING_COMPLETE.md](SplTv/SPLUNK_FORMATTING_COMPLETE.md) - Splunk formatting support
- [FORMATTING_EXAMPLES.md](SplTv/FORMATTING_EXAMPLES.md) - Formatting pattern examples

### Tables
- [TABLE_APPEARANCE_REDESIGN.md](SplTv/TABLE_APPEARANCE_REDESIGN.md) - Table styling system
- [TABLE_APPEARANCE_UI_GUIDE.md](SplTv/TABLE_APPEARANCE_UI_GUIDE.md) - Table UI customization
- [TABLE_ROW_LIMIT_COLUMN_RESIZE.md](SplTv/TABLE_ROW_LIMIT_COLUMN_RESIZE.md) - Row limits and column resizing

### Settings & Configuration
- [SETTINGS_UPDATES.md](SplTv/SETTINGS_UPDATES.md) - Settings view and CoreData management

## Technologies Used

- **Swift 6**: Modern concurrency with async/await, actors
- **SwiftUI**: Declarative UI framework
- **CoreData**: Local persistence
- **Foundation**: Networking, JSON/XML parsing
- **Keychain**: Secure credential storage

## Project Structure

```
SplTv/
├── README.md                    (this file)
├── PROJECT_ARCHITECTURE.md      (detailed architecture)
├── SplTv/                      (macOS app)
│   ├── SplTvApp.swift          (app entry point)
│   ├── Views/                  (SwiftUI views)
│   ├── Settings/               (settings views)
│   └── *.md                    (feature documentation)
└── d8aTv/
    └── Sources/
        └── DashboardKit/       (core framework)
            ├── CoreData/       (entities, model)
            ├── DataSources/    (Splunk, protocols)
            ├── Managers/       (CoreDataManager)
            ├── Models/         (Studio/XML models)
            ├── Parsers/        (JSON/XML parsers)
            └── Services/       (Splunk integration)
```

## Recent Changes

### Saved Search Metadata Feature
- Added `owner` and `app` fields to DataSource entity
- Automatic metadata fetch for saved searches using `| rest /servicesNS/-/-/saved/searches`
- Proper loadjob format: `| loadjob savedsearch="{owner}:{app}:{ref}"`
- Configuration-based SplunkDataSource initialization to preserve credentials

### DashboardKit Migration Complete
- Migrated from legacy d8aTvCore to modern DashboardKit architecture
- Consolidated Splunk functionality into SplunkIntegration
- Fixed Swift 6 concurrency issues
- Achieved 100% migration (zero d8aTvCore dependencies)

## Contributing

This is a personal project for learning and experimentation with Splunk dashboards on macOS.

## License

Private project - All rights reserved.
