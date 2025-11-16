# Dashboard Export Feature

## Overview
Added a new feature to the Data Management section in Settings that allows users to export complete dashboard object graphs to JSON files, using the same export functionality as the CLI tool.

## User Flow

### 1. Access the Export Feature
- Go to **Settings** (⌘,)
- Navigate to the **Reset** tab
- Find the **Data Management** section
- Click **Export Dashboard Details...**

### 2. Select App and Dashboard
A modal sheet will appear with:
- **App Selector**: Choose from available apps in your CoreData database
- **Dashboard Selector**: After selecting an app, choose a specific dashboard
- Only dashboards that have been synced to CoreData will appear

### 3. Export to JSON
- Click **Export Dashboard...** button
- Choose where to save the JSON file
- Default filename: `{dashboardId}_export.json`

## Exported Data Structure

The JSON file is a complete CoreData object graph export (same as CLI `query export-json` command), including:

- Complete dashboard entity structure
- All related searches and their configurations  
- Search dependencies and relationships
- Token definitions and usage
- Panel and visualization information
- All metadata and relationships preserved

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
1. User selects app → Filters dashboards by app
2. User selects dashboard → Enables export button  
3. Export button → Redirects stdout to file
4. Calls `loader.exportDashboardAsJSON(dashboardId)` → Writes to redirected stdout
5. Restores stdout → Completes export

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

### CoreData Object Graph
The export includes the complete entity graph with all relationships:
- Dashboard → Searches (one-to-many)
- Searches → Dependencies (many-to-many)
- Dashboard → Tokens (one-to-many)
- All attributes and metadata preserved

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

### Extension Point
This feature uses:
- `DashboardEntity`: Core dashboard metadata from CoreData
- `DashboardLoader.exportDashboardAsJSON()`: Existing export method
- File descriptor manipulation for stdout redirection
