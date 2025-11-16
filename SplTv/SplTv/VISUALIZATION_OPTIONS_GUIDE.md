# Visualization Options Parsing Guide

## Overview

This guide explains how to extract and store visualization options and format configurations from Splunk SimpleXML dashboards. The system now fully supports parsing `<option name="...">value</option>` elements and nested `<format>` configurations.

## Key Components

### 1. XML Parsing Extensions

**File:** `XMLParsingUtilities.swift`

Added methods to `SimpleXMLElement`:

```swift
// Extract all <option name="...">value</option> elements
func extractOptions() -> [String: String]

// Extract all <format> elements with nested configurations
func extractFormats() -> [FormatConfiguration]
```

### 2. Data Models

#### VisualizationOptions
Main container for all visualization configuration:

```swift
struct VisualizationOptions: Codable {
    let options: [String: String]          // Key-value pairs from <option> elements
    let formats: [FormatConfiguration]     // Format configurations
}
```

#### FormatConfiguration
Represents a `<format>` element:

```swift
struct FormatConfiguration: Codable {
    let type: String                       // e.g., "color", "number"
    let field: String?                     // Target field name
    let options: [String: String]          // Nested <option> elements
    let colorPalette: ColorPaletteConfig?  // Color palette configuration
    let scale: ScaleConfig?                // Scale configuration
}
```

#### ColorPaletteConfig
Color palette from `<colorPalette>` element:

```swift
struct ColorPaletteConfig: Codable {
    let type: String                       // "list", "minMidMax", "sharedList", etc.
    let colors: [String]                   // Array of color values
    let minColor: String?                  // Min color for gradients
    let midColor: String?                  // Mid color for gradients
    let maxColor: String?                  // Max color for gradients
}
```

#### ScaleConfig
Scale configuration from `<scale>` element:

```swift
struct ScaleConfig: Codable {
    let type: String                       // "threshold", "minMidMax", "linear", etc.
    let minValue: Double?
    let midValue: Double?
    let maxValue: Double?
    let thresholds: [Double]               // Threshold values
}
```

## XML Structure Support

The parser now handles the complete structure shown in your example:

```xml
<table>
  <!-- Search definition -->
  <search>
    <query>index=_internal | stats count by sourcetype</query>
    <earliest>-24h@h</earliest>
    <latest>now</latest>
  </search>
  
  <!-- Direct options on the visualization -->
  <option name="count">5</option>
  <option name="drilldown">none</option>
  <option name="rowNumbers">false</option>
  
  <!-- Format configurations with nested elements -->
  <format type="color" field="error">
    <colorPalette type="list">[#118832,#1182F3,#CBA700,#D94E17,#D41F1F]</colorPalette>
    <scale type="threshold">0,30,70,100</scale>
  </format>
  
  <format type="number" field="count">
    <option name="unit">£</option>
    <option name="unitPosition">before</option>
  </format>
</table>
```

## Usage Examples

### Parsing XML to Extract Options

```swift
import Foundation

func parseVisualizationFromXML() throws {
    let xmlString = """
    <table>
      <option name="count">5</option>
      <option name="drilldown">none</option>
      <format type="color" field="status">
        <colorPalette type="list">#FF0000,#00FF00</colorPalette>
        <scale type="threshold">50</scale>
      </format>
    </table>
    """
    
    // Parse XML
    let parser = SimpleXMLParser()
    let element = try parser.parse(xmlString: xmlString)
    
    // Extract options
    let vizOptions = VisualizationOptions.extract(from: element)
    
    // Access options
    print("Count: \(vizOptions.options["count"] ?? "N/A")")
    print("Drilldown: \(vizOptions.options["drilldown"] ?? "N/A")")
    
    // Access formats
    for format in vizOptions.formats {
        print("Format type: \(format.type), field: \(format.field ?? "none")")
        
        if let palette = format.colorPalette {
            print("  Palette: \(palette.type), colors: \(palette.colors)")
        }
        
        if let scale = format.scale {
            print("  Scale: \(scale.type), thresholds: \(scale.thresholds)")
        }
    }
}
```

### Storing in Core Data

```swift
import CoreData

func storeVisualizationInCoreData(
    _ xmlElement: SimpleXMLElement, 
    context: NSManagedObjectContext
) throws {
    // Create entity
    let visualization = VisualizationEntity(context: context)
    visualization.id = UUID().uuidString
    visualization.type = xmlElement.name
    
    // Extract and store options
    let options = VisualizationOptions.extract(from: xmlElement)
    try visualization.setVisualizationOptions(options)
    
    // Save
    try context.save()
}
```

### Reading from Core Data

```swift
func readVisualizationOptions(visualization: VisualizationEntity) {
    // Get a specific option
    if let count = visualization.option("count") {
        print("Table shows \(count) rows")
    }
    
    // Get format for a specific field
    if let errorFormat = visualization.format(forField: "error") {
        print("Error field has color format: \(errorFormat.type)")
        
        if let palette = errorFormat.colorPalette {
            print("Colors: \(palette.colors)")
        }
    }
    
    // Get all formats of a specific type
    let colorFormats = visualization.formats(ofType: "color")
    print("Found \(colorFormats.count) color format(s)")
    
    // Get all options
    if let vizOptions = visualization.visualizationOptions {
        for (key, value) in vizOptions.options {
            print("\(key): \(value)")
        }
    }
}
```

### Complete Example: Your XML Sample

```swift
func parseYourCompleteExample() throws {
    let xmlString = """
    <table>
      <search>
        <query>index=_internal | stats count by sourcetype</query>
        <earliest>-24h@h</earliest>
        <latest>now</latest>
        <sampleRatio>1</sampleRatio>
        <refresh>1m</refresh>
        <refreshType>delay</refreshType>
      </search>
      <option name="count">5</option>
      <option name="dataOverlayMode">none</option>
      <option name="drilldown">none</option>
      <option name="percentagesRow">false</option>
      <option name="refresh.display">progressbar</option>
      <option name="rowNumbers">false</option>
      <option name="totalsRow">false</option>
      <option name="wrap">true</option>
      <format type="color" field="error">
        <colorPalette type="list">[#118832,#1182F3,#CBA700,#D94E17,#D41F1F]</colorPalette>
        <scale type="threshold">0,30,70,100</scale>
      </format>
      <format type="color" field="count">
        <colorPalette type="minMidMax" maxColor="#118832" minColor="#FFFFFF"></colorPalette>
        <scale type="minMidMax"></scale>
      </format>
      <format type="color" field="info">
        <colorPalette type="sharedList"></colorPalette>
        <scale type="sharedCategory"></scale>
      </format>
      <format type="number" field="count">
        <option name="unit">£</option>
        <option name="unitPosition">before</option>
      </format>
    </table>
    """
    
    let parser = SimpleXMLParser()
    let element = try parser.parse(xmlString: xmlString)
    let vizOptions = element.parseVisualizationOptions()
    
    // All 8 options are now extracted
    print("Options:")
    print("  count: \(vizOptions.options["count"] ?? "N/A")")
    print("  drilldown: \(vizOptions.options["drilldown"] ?? "N/A")")
    print("  wrap: \(vizOptions.options["wrap"] ?? "N/A")")
    print("  ... and 5 more")
    
    // All 4 formats are extracted
    print("\nFormats:")
    for format in vizOptions.formats {
        print("  \(format.type) format for field '\(format.field ?? "unknown")'")
        
        if format.type == "number" {
            print("    Unit: \(format.options["unit"] ?? "none")")
            print("    Position: \(format.options["unitPosition"] ?? "none")")
        }
        
        if let palette = format.colorPalette {
            print("    Palette type: \(palette.type)")
            if !palette.colors.isEmpty {
                print("    Colors: \(palette.colors.joined(separator: ", "))")
            }
        }
        
        if let scale = format.scale {
            print("    Scale type: \(scale.type)")
            if !scale.thresholds.isEmpty {
                print("    Thresholds: \(scale.thresholds)")
            }
        }
    }
    
    // Serialize to JSON for storage
    let jsonData = try vizOptions.toJSONData()
    let jsonString = String(data: jsonData, encoding: .utf8)!
    print("\nJSON representation:")
    print(jsonString)
}
```

## Core Data Integration

The `VisualizationEntity` now has enhanced accessors:

### New Properties and Methods

```swift
extension VisualizationEntity {
    // Get structured options
    var visualizationOptions: VisualizationOptions?
    
    // Set structured options
    func setVisualizationOptions(_ options: VisualizationOptions) throws
    
    // Get specific option by name
    func option(_ name: String) -> String?
    
    // Get all formats
    var formatsArray: [FormatConfiguration]
    
    // Get format for specific field
    func format(forField field: String) -> FormatConfiguration?
    
    // Get formats by type
    func formats(ofType type: String) -> [FormatConfiguration]
}
```

### Example Queries

```swift
// Find visualizations with specific drilldown setting
let vizWithDrilldown = allVisualizations.filter { viz in
    viz.option("drilldown") == "row"
}

// Find visualizations with color formatting
let vizWithColorFormat = allVisualizations.filter { viz in
    !viz.formats(ofType: "color").isEmpty
}

// Get all unique fields with formatting
let formattedFields = Set(allVisualizations.flatMap { viz in
    viz.formatsArray.compactMap { $0.field }
})
```

## Backward Compatibility

The system maintains backward compatibility with existing code:

1. **Legacy fields** like `chartType`, `stackMode`, `legend` are still populated
2. **Existing chartOptions dictionary** can be read alongside new structured options
3. **Migration helper** provided to convert old data to new format

### Migration Example

```swift
func migrateOldVisualizations(context: NSManagedObjectContext) throws {
    let visualizations = try context.fetch(VisualizationEntity.fetchRequest())
    
    for viz in visualizations {
        // Skip if already migrated
        guard viz.visualizationOptions == nil else { continue }
        
        // Build options from legacy fields
        var options: [String: String] = [:]
        
        if let chartType = viz.chartType {
            options["charting.chart"] = chartType
        }
        if let drilldown = viz.drilldown {
            options["drilldown"] = drilldown
        }
        
        // Copy from old chartOptions dictionary
        for (key, value) in viz.chartOptionsDict {
            options[key] = String(describing: value)
        }
        
        // Create and store new format
        let vizOptions = VisualizationOptions(options: options, formats: [])
        try viz.setVisualizationOptions(vizOptions)
    }
    
    try context.save()
}
```

## Testing

Comprehensive tests are provided in `VisualizationOptionsTests.swift`:

- Basic option extraction
- Color format parsing
- Number format parsing
- Complete real-world examples
- Serialization/deserialization
- Edge cases and error handling

Run tests:
```bash
swift test
```

## Common Patterns

### Pattern 1: Extract All Table Options

```swift
func getTableConfiguration(_ xmlElement: SimpleXMLElement) -> [String: String] {
    let options = xmlElement.extractOptions()
    
    let tableConfig: [String: String] = [
        "count": options["count"] ?? "10",
        "drilldown": options["drilldown"] ?? "row",
        "wrap": options["wrap"] ?? "true",
        "rowNumbers": options["rowNumbers"] ?? "false"
    ]
    
    return tableConfig
}
```

### Pattern 2: Get Color Formatting Rules

```swift
func getColorRules(_ visualization: VisualizationEntity) -> [String: ColorPaletteConfig] {
    var rules: [String: ColorPaletteConfig] = [:]
    
    for format in visualization.formats(ofType: "color") {
        if let field = format.field, let palette = format.colorPalette {
            rules[field] = palette
        }
    }
    
    return rules
}
```

### Pattern 3: Apply Number Formatting

```swift
func formatNumber(_ value: Double, using format: FormatConfiguration) -> String {
    let unit = format.options["unit"] ?? ""
    let position = format.options["unitPosition"] ?? "after"
    let precision = Int(format.options["precision"] ?? "0") ?? 0
    
    let formatted = String(format: "%.\(precision)f", value)
    
    if position == "before" {
        return "\(unit)\(formatted)"
    } else {
        return "\(formatted)\(unit)"
    }
}
```

## JSON Output Format

The serialized format for storage in Core Data looks like this:

```json
{
  "formats": [
    {
      "colorPalette": {
        "colors": ["[#118832", "#1182F3", "#CBA700", "#D94E17", "#D41F1F]"],
        "type": "list"
      },
      "field": "error",
      "options": {},
      "scale": {
        "thresholds": [0, 30, 70, 100],
        "type": "threshold"
      },
      "type": "color"
    },
    {
      "field": "count",
      "options": {
        "unit": "£",
        "unitPosition": "before"
      },
      "type": "number"
    }
  ],
  "options": {
    "count": "5",
    "dataOverlayMode": "none",
    "drilldown": "none",
    "percentagesRow": "false",
    "refresh.display": "progressbar",
    "rowNumbers": "false",
    "totalsRow": "false",
    "wrap": "true"
  }
}
```

## Next Steps

1. **Update your dashboard parser** to use `VisualizationOptions.extract(from:)`
2. **Store options** using `setVisualizationOptions(_:)`
3. **Query options** using the new accessor methods
4. **Migrate existing data** if needed
5. **Run tests** to verify everything works

## Support for Additional Visualization Types

The system supports all Splunk visualization types:
- `<table>` - Table visualizations
- `<chart>` - Chart visualizations
- `<single>` - Single value displays
- `<map>` - Map visualizations
- `<event>` - Event viewers
- `<viz>` - Custom visualizations
- `<html>` - HTML panels

All follow the same parsing pattern!

## Troubleshooting

### Issue: Options not extracted
**Solution:** Ensure the element has `<option name="...">value</option>` children

### Issue: Format not parsed correctly
**Solution:** Check that `<format>` has both `type` and `field` attributes

### Issue: Colors not splitting correctly
**Solution:** Check if colors are in a list format like `[#FF0000,#00FF00]` or comma-separated

### Issue: JSON serialization fails
**Solution:** Verify all strings in options are valid UTF-8

## Additional Resources

- See `VisualizationOptionsParsing.swift` for complete examples
- See `VisualizationOptionsTests.swift` for comprehensive tests
- See `CoreDataModelExtensions.swift` for entity extensions
