# Visualization Options Quick Reference

## 🚀 Quick Start

### Parse XML and Extract Options
```swift
let parser = SimpleXMLParser()
let element = try parser.parse(xmlString: xmlString)
let vizOptions = element.parseVisualizationOptions()
```

### Store in Core Data
```swift
let viz = VisualizationEntity(context: context)
try viz.setVisualizationOptions(vizOptions)
```

### Read from Core Data
```swift
if let count = viz.option("count") {
    print("Row count: \(count)")
}
```

---

## 📊 Data Structures

| Type | Purpose | Key Properties |
|------|---------|---------------|
| `VisualizationOptions` | Main container | `options: [String: String]`<br>`formats: [FormatConfiguration]` |
| `FormatConfiguration` | Format rules | `type: String` (color/number)<br>`field: String?`<br>`colorPalette: ColorPaletteConfig?`<br>`scale: ScaleConfig?` |
| `ColorPaletteConfig` | Color definitions | `type: String`<br>`colors: [String]`<br>`minColor/midColor/maxColor: String?` |
| `ScaleConfig` | Scale rules | `type: String`<br>`thresholds: [Double]` |

---

## 🔧 Common Methods

### SimpleXMLElement Extensions
```swift
element.extractOptions()              // Get all <option> elements
element.extractFormats()              // Get all <format> elements  
element.parseVisualizationOptions()   // Get complete VisualizationOptions
element.isVisualizationType           // Check if chart/table/etc
```

### VisualizationEntity Extensions
```swift
viz.visualizationOptions              // Get structured options
viz.setVisualizationOptions(options)  // Store options
viz.option("name")                    // Get specific option
viz.formatsArray                      // Get all formats
viz.format(forField: "count")         // Get format for field
viz.formats(ofType: "color")          // Get all color formats
```

---

## 💡 Common Use Cases

### Get Table Display Options
```swift
let rowCount = viz.option("count") ?? "10"
let showNumbers = viz.option("rowNumbers") == "true"
let wrapText = viz.option("wrap") != "false"
```

### Get Color Rules for Field
```swift
if let format = viz.format(forField: "status"),
   let palette = format.colorPalette,
   let scale = format.scale {
    print("Colors: \(palette.colors)")
    print("Thresholds: \(scale.thresholds)")
}
```

### Get Number Formatting
```swift
if let format = viz.format(forField: "revenue"),
   format.type == "number" {
    let unit = format.options["unit"] ?? ""
    let position = format.options["unitPosition"] ?? "after"
    let precision = format.options["precision"] ?? "0"
}
```

### Check for Drilldown
```swift
let hasDrilldown = viz.option("drilldown") != "none"
let drilldownType = viz.option("drilldown") ?? "row"
```

---

## 📝 Example XML Patterns

### Basic Options
```xml
<table>
  <option name="count">10</option>
  <option name="drilldown">row</option>
  <option name="wrap">true</option>
</table>
```

### Color Format (Threshold)
```xml
<format type="color" field="status">
  <colorPalette type="list">#00FF00,#FFFF00,#FF0000</colorPalette>
  <scale type="threshold">50,90</scale>
</format>
```

### Color Format (Gradient)
```xml
<format type="color" field="value">
  <colorPalette type="minMidMax" minColor="#FFFFFF" maxColor="#FF0000"></colorPalette>
  <scale type="minMidMax"></scale>
</format>
```

### Number Format
```xml
<format type="number" field="price">
  <option name="unit">$</option>
  <option name="unitPosition">before</option>
  <option name="precision">2</option>
</format>
```

---

## ⚡ Performance Tips

1. **Cache options** after first access:
   ```swift
   private lazy var cachedOptions = viz.visualizationOptions
   ```

2. **Batch access** when reading multiple options:
   ```swift
   if let options = viz.visualizationOptions {
       let count = options.options["count"]
       let wrap = options.options["wrap"]
       let drilldown = options.options["drilldown"]
   }
   ```

3. **Filter early** when searching:
   ```swift
   // Good: Filter before accessing options
   let vizs = allViz.filter { $0.type == "table" }
   let results = vizs.compactMap { $0.option("count") }
   
   // Less efficient: Access options for all
   let results = allViz.compactMap { $0.option("count") }
   ```

---

## 🎨 Color Palette Types

| Type | Description | Attributes |
|------|-------------|-----------|
| `list` | Discrete colors | `colors: [String]` |
| `minMidMax` | Gradient with 2-3 colors | `minColor`, `midColor?`, `maxColor` |
| `sharedList` | Reference to shared palette | - |
| `expression` | Dynamic color rules | Expression in palette value |

---

## 📏 Scale Types

| Type | Description | Properties |
|------|-------------|-----------|
| `threshold` | Discrete thresholds | `thresholds: [Double]` |
| `minMidMax` | Min/mid/max values | `minValue`, `midValue?`, `maxValue` |
| `linear` | Linear scale | `minValue`, `maxValue` |
| `category` | Categorical values | - |
| `sharedCategory` | Shared categories | - |

---

## 🔍 Debugging

### Print All Options
```swift
if let options = viz.visualizationOptions {
    print("=== Options ===")
    for (key, value) in options.options.sorted(by: { $0.key < $1.key }) {
        print("  \(key) = \(value)")
    }
}
```

### Print All Formats
```swift
for format in viz.formatsArray {
    print("\nFormat: \(format.type)")
    print("  Field: \(format.field ?? "none")")
    
    if let palette = format.colorPalette {
        print("  Palette: \(palette.type)")
        print("  Colors: \(palette.colors)")
    }
    
    if let scale = format.scale {
        print("  Scale: \(scale.type)")
        print("  Thresholds: \(scale.thresholds)")
    }
}
```

### Export to JSON
```swift
if let options = viz.visualizationOptions,
   let jsonData = try? options.toJSONData(),
   let jsonString = String(data: jsonData, encoding: .utf8) {
    print(jsonString)
}
```

---

## ✅ Validation

### Check Required Options
```swift
func validateTableOptions(_ viz: VisualizationEntity) -> Bool {
    guard viz.type == "table" else { return false }
    guard viz.option("count") != nil else { return false }
    return true
}
```

### Check Format Completeness
```swift
func validateColorFormat(_ format: FormatConfiguration) -> Bool {
    guard format.type == "color" else { return false }
    guard format.field != nil else { return false }
    guard format.colorPalette != nil else { return false }
    guard format.scale != nil else { return false }
    return true
}
```

---

## 🛠 Common Option Names

### Table Options
- `count` - Number of rows to display
- `drilldown` - Drilldown behavior (none/row/cell)
- `rowNumbers` - Show row numbers (true/false)
- `wrap` - Wrap text (true/false)
- `totalsRow` - Show totals row (true/false)
- `percentagesRow` - Show percentages (true/false)
- `dataOverlayMode` - Data overlay mode
- `refresh.display` - Refresh indicator (progressbar/preview/none)

### Chart Options
- `charting.chart` - Chart type (line/bar/pie/etc)
- `charting.legend.show` - Show legend (true/false)
- `charting.legend.placement` - Legend position (right/left/top/bottom)
- `charting.chart.stackMode` - Stack mode (stacked/stacked100/default)
- `charting.chart.showDataLabels` - Show data labels (true/false)
- `charting.axisTitleX.text` - X-axis title
- `charting.axisTitleY.text` - Y-axis title

### Single Value Options
- `underLabel` - Label under value
- `unit` - Unit to display
- `unitPosition` - Unit position (before/after)
- `trendInterval` - Trend comparison interval
- `useColors` - Use color ranges (true/false)

---

## 📚 Related Files

- **Implementation**: `XMLParsingUtilities.swift`
- **Extensions**: `CoreDataModelExtensions.swift`
- **Examples**: `VisualizationOptionsParsing.swift`
- **Tests**: `VisualizationOptionsTests.swift`
- **Full Guide**: `VISUALIZATION_OPTIONS_GUIDE.md`

---

## 🆘 Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| Options not found | Element has no `<option>` children | Check XML structure |
| Format incomplete | Missing required attributes | Verify `type` and `field` exist |
| JSON decode fails | Invalid stored data | Clear and re-parse XML |
| Colors not parsed | Invalid color format | Check color string format |
| Threshold mismatch | Wrong number of colors vs thresholds | Verify scale configuration |

---

## 🎯 Best Practices

1. ✅ **Always check for nil** when accessing options
2. ✅ **Provide defaults** for missing values
3. ✅ **Cache parsed options** for repeated access
4. ✅ **Validate data** after parsing
5. ✅ **Use structured access** (formats/options) over raw dictionaries
6. ✅ **Serialize to JSON** for debugging
7. ✅ **Test with real Splunk XML** samples
8. ✅ **Document custom options** in your code

---

**Last Updated**: November 2025  
**Version**: 1.0
