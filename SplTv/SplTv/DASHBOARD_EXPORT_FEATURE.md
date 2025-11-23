# Dashboard Export Feature

## Overview
Added a new feature to the Data Management section in Settings that allows users to export complete dashboard configurations to JSON files. This feature uses the **modern DashboardKit entities** (Dashboard, DataSource, Visualization, etc.) to export both Dashboard Studio and SimpleXML formats.

## User Flow

### 1. Access the Export Feature
- Go to **Settings** (⌘,)
- Navigate to the **Reset** tab
- Find the **Data Management** section
- Click **Export Dashboard Details...**

### 2. Select Dashboard
A modal sheet will appear with:
- **Dashboard Selector**: Choose from dashboards synced to CoreData
- Only dashboards that have been synced via the Dashboards tab will appear
- Supports both Dashboard Studio (v2) and SimpleXML (v1) formats

### 3. Export to JSON
- Click **Export Dashboard...** button
- Choose where to save the JSON file
- Default filename: `{dashboardId}_export.json`

## Exported Data Structure

The JSON file exports the dashboard configuration using **DashboardKit entities**:

### Dashboard Studio Format (v2)
- **Dashboard** entity with metadata (title, description, formatType)
- **DataSource** entities (SPL queries, saved searches, chained searches)
- **Visualization** entities (tables, charts, single values with formatting)
- **DashboardLayout** and **LayoutItem** entities (absolute/grid positioning)
- **DashboardInput** entities (time pickers, dropdowns, text inputs)
- Original Studio JSON preserved in `rawJSON` field

### SimpleXML Format (v1)
- **Dashboard** entity with metadata
- **DataSource** entities (searches with earliest/latest/ref)
- **Visualization** entities (visualizations with type and options)
- **LayoutItem** entities (bootstrap-style positioning)
- Original SimpleXML preserved in `rawXML` field

### Common Fields
- All relationships preserved (dashboard → dataSources → visualizations)
- Search execution history (optional, if available)
- Saved search metadata (owner, app, ref)
- Token substitution patterns

## Implementation Details

### Files Modified
- **SplTvApp.swift**: Added export functionality to Settings view

### New Components
1. **DashboardExportView**: Modal sheet for selecting app/dashboard
2. **Export Method**: Uses existing `DashboardLoader.exportDashboardAsJSON()` with stdout redirection

### Key Features
- **App-based filtering**: Only shows dashboards for selected app
- **Complete object graph export**: Exports entire CoreData entity graph (same as CLI)
- **Native save dialog**: Uses macOS NSSavePanel for file selection
- **Stdout redirection**: Captures console output from existing export function

## Code Architecture

### Data Flow
1. User opens export modal → Loads Dashboard entities from DashboardKit CoreData
2. User selects dashboard → Enables export button
3. Export button → Opens save dialog
4. Exports Dashboard entity with all relationships to JSON
5. Writes to selected file location

### Stdout Redirection Technique
```swift
let fileHandle = try FileHandle(forWritingTo: url)
let originalStdout = dup(fileno(stdout))
dup2(fileHandle.fileDescriptor, fileno(stdout))
await loader.exportDashboardAsJSON(dashboard.id)
fflush(stdout)
dup2(originalStdout, fileno(stdout))
```

### Error Handling
- Validates dashboard selection
- Catches file I/O errors
- Handles stdout redirection failures
- Displays status messages to user

## Usage Examples

### Exporting for Backup
1. Select the "search" app
2. Choose your critical dashboard
3. Save to a backup location
4. Complete CoreData object graph is preserved

### Sharing Configurations
1. Export dashboard
2. Share JSON file with team members
3. They can review complete structure and relationships
4. Useful for documentation and collaboration

### Debugging
1. Export dashboard to inspect complete object graph
2. Verify all entity relationships
3. Check query syntax and search configurations
4. Analyze post-processing search chains

### Comparing with CLI
The GUI export is equivalent to running:
```bash
splunk-dashboard query export-json my_dashboard > output.json
```

## Technical Notes

### Why Stdout Redirection?
- Reuses existing, well-tested `DashboardLoader.exportDashboardAsJSON()` method
- Avoids code duplication
- Ensures GUI and CLI exports are identical
- Leverages CoreData's JSON encoding automatically

### DashboardKit Entity Graph
The export includes the complete entity graph with all relationships:
- **Dashboard** → **DataSources** (one-to-many)
- **Dashboard** → **Visualizations** (one-to-many)
- **Dashboard** → **DashboardInputs** (one-to-many)
- **Dashboard** → **DashboardLayout** (one-to-one)
- **DashboardLayout** → **LayoutItems** (one-to-many)
- **Visualization** → **DataSource** (many-to-one)
- **DataSource** → **SearchExecutions** (one-to-many, optional)
- All attributes and metadata preserved

### Entity Types Used
- `Dashboard` (from DashboardKit)
- `DataSource` (from DashboardKit)
- `Visualization` (from DashboardKit)
- `DashboardLayout` (from DashboardKit)
- `LayoutItem` (from DashboardKit)
- `DashboardInput` (from DashboardKit)

See [PROJECT_ARCHITECTURE.md](../PROJECT_ARCHITECTURE.md) for complete entity details.

## Future Enhancements

Potential improvements:
- [ ] Batch export (multiple dashboards at once)
- [ ] Export all dashboards in an app
- [ ] Import dashboard from JSON (reverse operation)
- [ ] Export with search results (optional)
- [ ] Progress indicator for large exports
- [ ] Export format options (compressed, minified)

## Testing Checklist

- [x] App selector populates correctly
- [x] Dashboard selector filters by app
- [x] File saves to correct location
- [x] Error handling works
- [x] Status messages display correctly
- [x] Stdout redirection works correctly
- [x] Original stdout is restored
- [x] Works with complex dashboards
- [x] Identical output to CLI export

## Related Code

### CLI Command
The GUI feature uses the same underlying export as:
```bash
splunk-dashboard query export-json <dashboard_id>
```

Located in `main.swift`:
```swift
struct ExportJSONCommand: AsyncParsableCommand {
    @Argument(help: "Dashboard ID")
    var dashboardId: String
    
    func run() async {
        let loader = await DashboardLoader()
        await loader.exportDashboardAsJSON(dashboardId)
    }
}
```

### Architecture Notes
This feature uses:
- **`Dashboard`** (DashboardKit): Modern entity with UUID IDs
- **`CoreDataManager.shared.viewContext`**: For querying dashboards
- **Native JSON encoding**: Encodes Dashboard entity with relationships
- **Both formats supported**: Dashboard Studio (JSON) and SimpleXML

### Migration from Legacy
**Before**: Used `DashboardEntity` from d8aTvCore
**After**: Uses `Dashboard` from DashboardKit (modern, UUID-based)

See [D8ATVCORE_MIGRATION_STATUS.md](../D8ATVCORE_MIGRATION_STATUS.md) for migration details.
