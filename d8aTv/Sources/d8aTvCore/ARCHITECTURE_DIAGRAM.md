# Visualization Options Architecture Diagram

## System Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Splunk SimpleXML Dashboard                       │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ <table>                                                            │  │
│  │   <search>...</search>                                             │  │
│  │   <option name="count">5</option>                                  │  │
│  │   <option name="drilldown">none</option>                           │  │
│  │   <format type="color" field="error">                              │  │
│  │     <colorPalette type="list">...</colorPalette>                   │  │
│  │     <scale type="threshold">0,30,70,100</scale>                    │  │
│  │   </format>                                                         │  │
│  │ </table>                                                            │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      SimpleXMLParser (Foundation)                        │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ XMLParser (NSXMLParser)                                            │  │
│  │   - didStartElement                                                │  │
│  │   - foundCharacters                                                │  │
│  │   - didEndElement                                                  │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          SimpleXMLElement Tree                           │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ SimpleXMLElement                                                   │  │
│  │   • name: String                                                   │  │
│  │   • attributes: [String: String]                                   │  │
│  │   • value: String?                                                 │  │
│  │   • children: [SimpleXMLElement]                                   │  │
│  │   • parent: SimpleXMLElement?                                      │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                   Option & Format Extraction Layer                       │
│  ┌─────────────────────────────────────────────────────────────┬─────┐  │
│  │ extractOptions() → [String: String]                         │     │  │
│  │   - Finds all <option name="...">value</option>             │     │  │
│  │   - Returns dictionary of name → value                      │     │  │
│  ├─────────────────────────────────────────────────────────────┤     │  │
│  │ extractFormats() → [FormatConfiguration]                    │NEW  │  │
│  │   - Finds all <format type="..." field="...">               │     │  │
│  │   - Extracts nested <colorPalette>                          │     │  │
│  │   - Extracts nested <scale>                                 │     │  │
│  │   - Extracts nested <option> elements                       │     │  │
│  └─────────────────────────────────────────────────────────────┴─────┘  │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      Structured Data Models (Swift)                      │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ VisualizationOptions (Codable)                                    │  │
│  │   ├─ options: [String: String]                                    │  │
│  │   └─ formats: [FormatConfiguration]                               │  │
│  │                                                                    │  │
│  │ FormatConfiguration (Codable)                                     │  │
│  │   ├─ type: String                ("color", "number", etc.)        │  │
│  │   ├─ field: String?              ("error", "count", etc.)         │  │
│  │   ├─ options: [String: String]   (nested options)                 │  │
│  │   ├─ colorPalette: ColorPaletteConfig?                            │  │
│  │   └─ scale: ScaleConfig?                                          │  │
│  │                                                                    │  │
│  │ ColorPaletteConfig (Codable)                                      │  │
│  │   ├─ type: String                ("list", "minMidMax", etc.)      │  │
│  │   ├─ colors: [String]            (["#FF0000", "#00FF00", ...])    │  │
│  │   ├─ minColor: String?                                            │  │
│  │   ├─ midColor: String?                                            │  │
│  │   └─ maxColor: String?                                            │  │
│  │                                                                    │  │
│  │ ScaleConfig (Codable)                                             │  │
│  │   ├─ type: String                ("threshold", "minMidMax", etc.) │  │
│  │   ├─ minValue: Double?                                            │  │
│  │   ├─ midValue: Double?                                            │  │
│  │   ├─ maxValue: Double?                                            │  │
│  │   └─ thresholds: [Double]        ([0, 30, 70, 100])               │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼ JSON Encoding
┌─────────────────────────────────────────────────────────────────────────┐
│                         JSON Representation                              │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ {                                                                  │  │
│  │   "options": {                                                     │  │
│  │     "count": "5",                                                  │  │
│  │     "drilldown": "none",                                           │  │
│  │     ...                                                            │  │
│  │   },                                                               │  │
│  │   "formats": [                                                     │  │
│  │     {                                                              │  │
│  │       "type": "color",                                             │  │
│  │       "field": "error",                                            │  │
│  │       "colorPalette": { ... },                                     │  │
│  │       "scale": { ... }                                             │  │
│  │     }                                                              │  │
│  │   ]                                                                │  │
│  │ }                                                                  │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      Core Data Persistence Layer                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ VisualizationEntity                                                │  │
│  │   ├─ id: String                                                    │  │
│  │   ├─ type: String                                                  │  │
│  │   ├─ chartOptions: Data ◄──── JSON stored here                    │  │
│  │   ├─ formatOptions: Data (legacy)                                 │  │
│  │   ├─ colorPalette: Data (legacy)                                  │  │
│  │   └─ ... other fields                                             │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      Convenience Accessor Layer                          │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ extension VisualizationEntity {                                    │  │
│  │                                                                    │  │
│  │   var visualizationOptions: VisualizationOptions?                 │  │
│  │     → Decodes chartOptions Data back to struct                    │  │
│  │                                                                    │  │
│  │   func setVisualizationOptions(_ options: VisualizationOptions)   │  │
│  │     → Encodes struct to JSON and stores in chartOptions           │  │
│  │                                                                    │  │
│  │   func option(_ name: String) -> String?                          │  │
│  │     → Quick access to individual options                          │  │
│  │                                                                    │  │
│  │   var formatsArray: [FormatConfiguration]                         │  │
│  │     → All format configurations                                   │  │
│  │                                                                    │  │
│  │   func format(forField field: String) -> FormatConfiguration?     │  │
│  │     → Get format for specific field                               │  │
│  │                                                                    │  │
│  │   func formats(ofType type: String) -> [FormatConfiguration]      │  │
│  │     → Filter by format type                                       │  │
│  │ }                                                                  │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          Application Layer                               │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ Your SwiftUI Views / UIKit Controllers                             │  │
│  │   - Read options: viz.option("count")                             │  │
│  │   - Get formats: viz.format(forField: "error")                    │  │
│  │   - Apply colors, scales, number formatting                       │  │
│  │   - Render visualizations with full fidelity                      │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

## Data Flow Example

### Parsing Flow (XML → Core Data)

```
1. XML String
   ↓
2. SimpleXMLParser.parse(xmlString:)
   ↓
3. SimpleXMLElement tree structure
   ↓
4. element.parseVisualizationOptions()
   ├─ extractOptions() → [String: String]
   └─ extractFormats() → [FormatConfiguration]
   ↓
5. VisualizationOptions(options:, formats:)
   ↓
6. options.toJSONData()
   ↓
7. viz.chartOptions = jsonData
   ↓
8. context.save()
```

### Reading Flow (Core Data → App)

```
1. Fetch VisualizationEntity from Core Data
   ↓
2. viz.visualizationOptions
   ├─ Reads viz.chartOptions (Data)
   ├─ Decodes JSON
   └─ Returns VisualizationOptions
   ↓
3. Access specific option
   ├─ viz.option("count") → "5"
   ├─ viz.format(forField: "error") → FormatConfiguration
   └─ viz.formats(ofType: "color") → [FormatConfiguration]
   ↓
4. Use in UI rendering
   ├─ Configure table row count
   ├─ Apply color formatting
   └─ Format numbers with units
```

## Component Relationships

```
┌────────────────────────────────────────────────────────────────┐
│                         Your Project                            │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ XMLParsingUtilities.swift                                │  │
│  │  ├─ XMLParsingError                                      │  │
│  │  ├─ SimpleXMLElement                 (Core Parser)       │  │
│  │  ├─ SimpleXMLParser                                      │  │
│  │  ├─ TokenValidator                                       │  │
│  │  ├─ VisualizationOptions             (NEW)              │  │
│  │  ├─ FormatConfiguration              (NEW)              │  │
│  │  ├─ ColorPaletteConfig               (NEW)              │  │
│  │  └─ ScaleConfig                      (NEW)              │  │
│  └──────────────────────────────────────────────────────────┘  │
│                            │                                    │
│                            │ uses                               │
│                            ▼                                    │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ SimpleXMLElementExtensions.swift                         │  │
│  │  ├─ Convenience properties                               │  │
│  │  ├─ Navigation helpers                                   │  │
│  │  ├─ Query methods                                        │  │
│  │  └─ Validation helpers                                   │  │
│  └──────────────────────────────────────────────────────────┘  │
│                            │                                    │
│                            │ extends                            │
│                            ▼                                    │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ CoreDataEntities.swift                                   │  │
│  │  ├─ DashboardEntity                                      │  │
│  │  ├─ RowEntity                                            │  │
│  │  ├─ PanelEntity                                          │  │
│  │  ├─ VisualizationEntity             (Stores options)    │  │
│  │  ├─ SearchEntity                                         │  │
│  │  └─ ... other entities                                   │  │
│  └──────────────────────────────────────────────────────────┘  │
│                            │                                    │
│                            │ extends                            │
│                            ▼                                    │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ CoreDataModelExtensions.swift                            │  │
│  │  ├─ visualizationOptions property    (NEW)              │  │
│  │  ├─ setVisualizationOptions()        (NEW)              │  │
│  │  ├─ option(_ name:)                  (NEW)              │  │
│  │  ├─ formatsArray                     (NEW)              │  │
│  │  ├─ format(forField:)                (NEW)              │  │
│  │  └─ formats(ofType:)                 (NEW)              │  │
│  └──────────────────────────────────────────────────────────┘  │
│                            │                                    │
│                            │ used by                            │
│                            ▼                                    │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ CompleteDashboardParsingExample.swift                    │  │
│  │  └─ CompleteDashboardParser          (Example)          │  │
│  └──────────────────────────────────────────────────────────┘  │
│                            │                                    │
│                            │ demonstrates                       │
│                            ▼                                    │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Your Dashboard Parser & Views                            │  │
│  │  ├─ Parse dashboards from Splunk                         │  │
│  │  ├─ Store in Core Data                                   │  │
│  │  └─ Render with full option support                      │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Key Files Summary

| File | Purpose | Key Components |
|------|---------|---------------|
| `XMLParsingUtilities.swift` | Core XML parsing & data models | `SimpleXMLElement`, `VisualizationOptions`, `FormatConfiguration` |
| `SimpleXMLElementExtensions.swift` | Convenience methods | Navigation, queries, validation |
| `CoreDataEntities.swift` | Core Data entity definitions | `VisualizationEntity` stores `chartOptions: Data` |
| `CoreDataModelExtensions.swift` | Entity convenience accessors | `option()`, `format()`, `setVisualizationOptions()` |
| `VisualizationOptionsParsing.swift` | Practical examples | Complete parsing workflow examples |
| `VisualizationOptionsTests.swift` | Test coverage | 20+ test cases for all functionality |
| `CompleteDashboardParsingExample.swift` | End-to-end example | Full dashboard parsing with all features |
| `VISUALIZATION_OPTIONS_GUIDE.md` | Full documentation | Comprehensive usage guide |
| `VISUALIZATION_OPTIONS_QUICK_REF.md` | Quick reference | Cheat sheet for developers |

## Architecture Decisions

### Why JSON Storage?
- ✅ Flexible - Easily add new option types
- ✅ Queryable - Can inspect in database tools
- ✅ Compact - Efficient storage
- ✅ Portable - Easy to export/import
- ✅ Type-safe - Codable provides compile-time safety

### Why Nested Structs?
- ✅ Type safety - Compiler catches errors
- ✅ Clear structure - Easy to understand
- ✅ Maintainable - Changes are localized
- ✅ Testable - Each struct can be tested independently
- ✅ Extensible - Easy to add new format types

### Why Core Data Extensions?
- ✅ Separation of concerns - Data model vs. accessor logic
- ✅ Backward compatible - Doesn't break existing code
- ✅ Performance - Computed properties are efficient
- ✅ Convenience - Simple, intuitive API
- ✅ Maintainable - Easy to update without touching entities

## Performance Characteristics

| Operation | Time Complexity | Notes |
|-----------|----------------|-------|
| Parse XML | O(n) | n = number of XML elements |
| Extract options | O(m) | m = number of child elements |
| Extract formats | O(m) | m = number of child elements |
| JSON encode | O(k) | k = total options + formats |
| JSON decode | O(k) | k = total options + formats |
| Option lookup | O(1) | Dictionary access |
| Format lookup | O(f) | f = number of formats (typically < 10) |
| Store in Core Data | O(1) | Single attribute write |

## Memory Usage

Typical visualization with 10 options and 3 formats:
- In-memory struct: ~2 KB
- JSON serialized: ~1-2 KB
- Core Data storage: ~1-2 KB + overhead

## Future Extensions

Possible enhancements:
1. ✨ Format validation rules
2. ✨ Option value type checking
3. ✨ Dynamic option rendering
4. ✨ Export to Splunk XML
5. ✨ Option diff/comparison
6. ✨ Format templates
7. ✨ Color palette management
8. ✨ Scale validation

---

**Last Updated**: November 11, 2025  
**Architecture Version**: 1.0
