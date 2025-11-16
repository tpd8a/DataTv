# Dashboard Monitor GUI

A native SwiftUI application for monitoring and controlling automatic refresh of Splunk dashboard searches.

## Overview

The Dashboard Monitor GUI provides a real-time view of dashboards and their automatic refresh timers. It leverages Core Data's automatic change propagation to display live updates as searches execute and complete.

## Architecture

### Core Components

1. **DashboardRefreshWorker** (`DashboardRefreshWorker.swift`)
   - Singleton service managing all refresh timers
   - Runs on main actor for thread safety
   - Uses Combine publishers for reactive state updates
   - Executes searches in background context

2. **DashboardMonitorView** (`DashboardMonitorView.swift`)
   - SwiftUI interface for monitoring dashboards
   - Split view with sidebar and detail pane
   - Real-time updates via `@FetchRequest` and `@StateObject`
   - Platform-specific toolbars for macOS 26 and tvOS 26

3. **DashboardMonitorApp** (`DashboardMonitorApp.swift`)
   - App entry point
   - Provides Core Data context
   - Registers keyboard shortcuts (macOS)
   - Includes settings panel (macOS)

### How It Works

```
┌─────────────────────────────────────────────────────┐
│  DashboardMonitorView (SwiftUI)                     │
│  - @FetchRequest observes DashboardEntity           │
│  - @StateObject observes DashboardRefreshWorker     │
└──────────────────┬──────────────────────────────────┘
                   │
                   │ Commands (Start/Stop)
                   ▼
┌─────────────────────────────────────────────────────┐
│  DashboardRefreshWorker (@MainActor)                │
│  - Manages Timer publishers                         │
│  - Executes searches via CoreDataManager            │
│  - Updates @Published state                         │
└──────────────────┬──────────────────────────────────┘
                   │
                   │ Search Execution
                   ▼
┌─────────────────────────────────────────────────────┐
│  CoreDataManager                                    │
│  - Background context for writes                    │
│  - View context with automaticallyMergesChanges     │
│  - Executes Splunk REST calls                       │
└──────────────────┬──────────────────────────────────┘
                   │
                   │ Automatic Merge
                   ▼
┌─────────────────────────────────────────────────────┐
│  Core Data Persistent Store                        │
│  - Single source of truth                           │
│  - Atomic transactions                              │
└─────────────────────────────────────────────────────┘
```

## Features

### Main View
- **Sidebar**: Lists all dashboards with active timer counts
- **Detail Pane**: Shows selected dashboard with active timers and controls
- **Status Bar**: Displays overall status (running/stopped) and timer count
- **Toolbar**: Start/Stop all timers, access settings

### Dashboard Details
- **Timer List**: Shows all active refresh timers for searches
  - Search ID
  - Refresh interval
  - Last refresh time
  - Next scheduled refresh
- **Controls**: Start/Stop timers for specific dashboard

### Platform-Specific Features

#### macOS 26
- Window with sidebar and detail panes
- Toolbar with buttons and keyboard shortcuts
  - ⌘R - Start all timers
  - ⌘S - Stop all timers
- Settings panel (⌘,)
  - Auto-start timers on launch
  - Notification preferences
  - Logging options

#### tvOS 26
- Focus-based navigation
- Top bar trailing placement for controls
- Optimized for TV viewing distance

## Usage

### Building the GUI

1. **Create a new macOS/tvOS target** in your Xcode project
   - Product Name: "Dashboard Monitor"
   - Interface: SwiftUI
   - Language: Swift
   - Minimum Deployment: macOS 26.0 / tvOS 26.0

2. **Add the source files**:
   ```
   DashboardRefreshWorker.swift
   DashboardMonitorView.swift
   DashboardMonitorApp.swift
   ```

3. **Link required frameworks**:
   - CoreData.framework
   - Combine.framework
   - d8aTvCore (your existing Core Data module)

4. **Build and run** ⌘R

### Running the Monitor

1. **Launch the app**
   - The main window shows all dashboards from Core Data

2. **Start monitoring**
   - Click "Start All" in toolbar to begin all refresh timers
   - Or select a dashboard and click "Start Timers" for that dashboard only

3. **View activity**
   - Watch timers count down in real-time
   - See last refresh timestamps update
   - Monitor active search executions

4. **Stop monitoring**
   - Click "Stop All" to halt all timers
   - Or stop individual dashboards as needed

## Configuration

### Settings (macOS only)

Access via **Dashboard Monitor → Settings** (⌘,)

- **Auto-start timers on launch**: Automatically begin monitoring when app opens
- **Show notifications**: Display alerts when refresh operations fail
- **Log refresh activity**: Write detailed logs to console

### Environment Variables

None required - uses existing Core Data configuration from `CoreDataManager.shared`

## Development Notes

### Thread Safety

- All timer management happens on `@MainActor`
- Background context used for Core Data writes
- View context automatically merges changes from parent
- No explicit observation or notification handling needed

### State Management

The GUI uses SwiftUI's reactive bindings:

```swift
@StateObject private var refreshWorker = DashboardRefreshWorker.shared
@FetchRequest private var dashboards: FetchedResults<DashboardEntity>
```

Changes to either:
1. The refresh worker's published properties
2. Core Data entities

...automatically trigger view updates.

### Adding New Features

To add dashboard-level controls:

```swift
Button {
    // Custom action
    await refreshWorker.triggerRefresh(
        searchId: "my_search",
        in: dashboardId
    )
} label: {
    Label("Refresh Now", systemImage: "arrow.clockwise")
}
```

To observe specific search executions:

```swift
@FetchRequest(
    entity: SearchExecutionEntity.entity(),
    sortDescriptors: [NSSortDescriptor(keyPath: \SearchExecutionEntity.startTime, ascending: false)],
    predicate: NSPredicate(format: "dashboardId == %@", dashboardId)
)
private var executions: FetchedResults<SearchExecutionEntity>
```

## Troubleshooting

### Timers not starting

**Check**: Dashboard has searches with `refresh` attribute
```bash
# Use CLI to verify
splunk-dashboard query list-refresh --dashboard <dashboard-id>
```

### UI not updating

**Check**: Core Data merge policy is set correctly
```swift
// In CoreDataManager or DashboardRefreshWorker init:
viewContext.automaticallyMergesChangesFromParent = true
```

### Memory leaks

**Check**: Use `[weak self]` in timer closures
```swift
.sink { [weak self] _ in
    self?.refreshSearch(...)
}
```

## Future Enhancements

Potential improvements for future iterations:

1. **Search Results Viewer**: Display actual results from executed searches
2. **Error Notifications**: Native macOS notifications for failures
3. **Performance Metrics**: Charts showing execution time, result counts
4. **Manual Token Input**: UI for providing token values for parameterized searches
5. **Export Functionality**: Save results to CSV/JSON
6. **Dark Mode Support**: Optimize color schemes for dark environments

## Requirements

- macOS 26.0+ or tvOS 26.0+
- Xcode 16.0+
- Swift 6.0+
- Core Data framework
- Combine framework
- d8aTvCore module (your existing Core Data stack)

## License

Same as parent project.
