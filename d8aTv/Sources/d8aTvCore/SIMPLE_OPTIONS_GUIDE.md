# Simple Visualization Options - Quick Guide

## What Changed

Added **one simple method** to extract all options from a visualization element into a flat dictionary.

## The Solution

### 1. XMLParsingUtilities.swift
Added `extractAllOptions()` method to `SimpleXMLElement`:

```swift
public func extractAllOptions() -> [String: String]
```

This extracts:
- Direct options: `<option name="count">5</option>` → `["count": "5"]`
- Format options: `<format type="color" field="error">...` → `["format.error.type": "color"]`
- Nested format options: All format settings with namespaced keys

### 2. CoreDataEntities.swift  
Added helper methods to `VisualizationEntity`:

```swift
public var allOptions: [String: Any]           // Get all options
public func option(_ name: String) -> String?  // Get specific option
public func setOptions(_ options: [String: Any]) throws  // Store options
```

## Usage

### Parse and Extract
```swift
let parser = SimpleXMLParser()
let element = try parser.parse(xmlString: xmlString)
let options = element.extractAllOptions()
```

### Store in Core Data
```swift
let viz = VisualizationEntity(context: context)
try viz.setOptions(options)
try context.save()
```

### Read from Core Data
```swift
let count = viz.option("count")               // "5"
let drilldown = viz.option("drilldown")       // "none"

// Format options use namespaced keys
let errorType = viz.option("format.error.type")                    // "color"
let errorColors = viz.option("format.error.palette.colors")        // "#FF0000,#00FF00"
let errorThresholds = viz.option("format.error.scale.thresholds")  // "0,30,70,100"

let unit = viz.option("format.count.unit")                         // "£"
let unitPos = viz.option("format.count.unitPosition")              // "before"
```

## Option Key Format

### Direct Options
- `count` → from `<option name="count">5</option>`
- `drilldown` → from `<option name="drilldown">none</option>`

### Format Options
- `format.{field}.type` → format type (color, number, etc.)
- `format.{field}.{optionName}` → nested option values
- `format.{field}.palette.type` → palette type
- `format.{field}.palette.colors` → color values
- `format.{field}.palette.minColor` → min color for gradient
- `format.{field}.palette.maxColor` → max color for gradient
- `format.{field}.scale.type` → scale type
- `format.{field}.scale.thresholds` → threshold values

## Example: Your XML

```xml
<table>
  <option name="count">5</option>
  <option name="drilldown">none</option>
  <format type="color" field="error">
    <colorPalette type="list">[#118832,#1182F3,#CBA700]</colorPalette>
    <scale type="threshold">0,30,70</scale>
  </format>
  <format type="number" field="count">
    <option name="unit">£</option>
    <option name="unitPosition">before</option>
  </format>
</table>
```

**Extracts to:**
```swift
[
  "count": "5",
  "drilldown": "none",
  "format.error.type": "color",
  "format.error.palette.type": "list",
  "format.error.palette.colors": "[#118832,#1182F3,#CBA700]",
  "format.error.scale.type": "threshold",
  "format.error.scale.thresholds": "0,30,70",
  "format.count.type": "number",
  "format.count.unit": "£",
  "format.count.unitPosition": "before"
]
```

## Complete Example

```swift
// Parse XML
let parser = SimpleXMLParser()
let tableElement = try parser.parse(xmlString: xmlString)

// Extract options
let options = tableElement.extractAllOptions()

// Create visualization
let viz = VisualizationEntity(context: context)
viz.id = UUID().uuidString
viz.type = "table"

// Store options
try viz.setOptions(options)
try context.save()

// Read options
print("Table shows \(viz.option("count") ?? "10") rows")
print("Drilldown: \(viz.option("drilldown") ?? "none")")

if let errorColors = viz.option("format.error.palette.colors") {
    print("Error field colors: \(errorColors)")
}

if let unit = viz.option("format.count.unit") {
    print("Count unit: \(unit)")
}
```

## That's It!

No complex structs, no nested models, just a simple flat dictionary stored as JSON.

---

**Files Changed:**
1. `XMLParsingUtilities.swift` - Added `extractAllOptions()` method
2. `CoreDataEntities.swift` - Added helper methods to `VisualizationEntity`
3. `SimpleVisualizationOptionsExample.swift` - Examples (new file)

**Files to Delete:**
- All the complex files I created before (`VisualizationOptionsParsing.swift`, `SimpleXMLElementExtensions.swift`, etc.)
