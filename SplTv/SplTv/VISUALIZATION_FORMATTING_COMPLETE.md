# Visualization Formatting Implementation Summary

## What Was Implemented

Added complete support for Splunk SimpleXML visualization options with proper formatting application in the table view.

## Files Changed

### 1. XMLParsingUtilities.swift
- Added `extractAllOptions()` method to extract options and formats as **structured nested data**
- Added `extractFormat()` helper to parse format elements with their nested palettes and scales
- Returns data in this structure:
```json
{
  "options": {"count": "5", "wrap": "true"},
  "formats": [
    {
      "type": "color",
      "field": "error",
      "palette": {"type": "list", "colors": ["#FF0000", "#00FF00"]},
      "scale": {"type": "threshold", "values": [0, 30, 70]}
    }
  ]
}
```

### 2. CoreDataEntities.swift
- Added helper methods to `VisualizationEntity`:
  - `allOptions` - Get all options as dictionary
  - `option(_:)` - Get specific option value
  - `setOptions(_:)` - Store options as JSON

### 3. DashboardLoader.swift
- Updated `parseVisualizations()` to use `extractAllOptions()`
- Properly extracts nested options structure
- Stores in `VisualizationEntity.chartOptions` as JSON

### 4. VisualizationFormatting.swift (NEW)
- Created reusable formatting system for all visualizations
- `VisualizationFormatting` struct with methods:
  - `tableRowCount` - Number of rows to display
  - `showRowNumbers` - Whether to show row number column
  - `wrapText` - Whether to wrap text in cells
  - `showTotalsRow` - Whether to show totals
  - `drilldownMode` - Drilldown behavior
  - `applyColorFormatting(field:value:)` - Apply color to field values
  - `applyNumberFormatting(field:value:)` - Format numbers with units

### 5. DashboardMonitorView.swift
- Updated `ResultsTableContent` to load and apply Splunk options:
  - **Row numbers**: Conditionally shown based on `rowNumbers` option
  - **Text wrapping**: Applied via `lineLimit` based on `wrap` option
  - **Color formatting**: Cells colored based on `<format type="color">` rules
  - **Number formatting**: Values formatted with units (e.g., "£5")

## How It Works

### Parsing Flow
```
XML → extractAllOptions() → Structured JSON → CoreData (chartOptions field)
```

### Rendering Flow
```
CoreData → VisualizationFormatting → Apply to Table Cells
```

### Example: Your XML
```xml
<format type="color" field="error">
  <colorPalette type="list">[#118832,#1182F3,#CBA700]</colorPalette>
  <scale type="threshold">0,30,70</scale>
</format>
```

**Becomes:**
```json
{
  "type": "color",
  "field": "error",
  "palette": {
    "type": "list",
    "colors": ["#118832", "#1182F3", "#CBA700"]
  },
  "scale": {
    "type": "threshold",
    "values": [0, 30, 70]
  }
}
```

**Applied as:**
- Values < 30 → #118832 (green)
- Values 30-70 → #1182F3 (blue)
- Values > 70 → #CBA700 (yellow)

## Supported Options

### Table Options
- ✅ `count` - Number of rows to display
- ✅ `rowNumbers` - Show/hide row number column
- ✅ `wrap` - Multi-line text in cells
- ✅ `drilldown` - Drilldown behavior (none/row/cell)
- ✅ `totalsRow` - Show totals row
- ✅ `percentagesRow` - Show percentages

### Format Types
- ✅ **Color (List)** - Threshold-based colors
- ✅ **Color (MinMidMax)** - Gradient colors
- ✅ **Number** - Units and precision (e.g., "£", "$", "errors")

## Usage Example

```swift
// Get formatting helper
let formatting = VisualizationFormatting(visualization: viz)

// Check options
let rowCount = formatting.tableRowCount // 5
let showRowNum = formatting.showRowNumbers // false
let wrap = formatting.wrapText // true

// Apply formatting
if let color = formatting.applyColorFormatting(field: "error", value: 45) {
    // Color the cell based on threshold
}

if let formatted = formatting.applyNumberFormatting(field: "count", value: 1234) {
    // Display as "£1,234"
}
```

## What's Applied in Table View

1. **Row Numbers**: Column shown/hidden based on `rowNumbers` option
2. **Text Wrapping**: `lineLimit` set to `nil` if `wrap=true`, else `3`
3. **Color Formatting**: Text color applied based on format rules
4. **Number Formatting**: Values formatted with units in correct position
5. **Priority**: Splunk formatting applied first, then user's change highlighting

## Extensibility

The `VisualizationFormatting` struct is designed to be reusable:
- Works with any `VisualizationEntity`
- Can be extended for charts, single values, maps, etc.
- Format configurations are field-specific, so different fields get different formatting

## Next Steps

To apply formatting to other visualizations:
1. Create formatting helper: `let formatting = VisualizationFormatting(visualization: viz)`
2. Use appropriate methods for that viz type
3. Apply formatting in your SwiftUI view

**The system is now fully functional for tables and ready to extend to other viz types!** ✅
