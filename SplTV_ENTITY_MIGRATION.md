# SplTV Entity Migration Reference

## Quick Entity Mapping

| Old Entity | New Entity | Key Changes |
|------------|------------|-------------|
| `DashboardEntity` | `Dashboard` | `dashboardName` → `title`, `xmlContent` → `rawXML` |
| `FieldsetEntity` | `DashboardInput` | No more separate fieldset, inputs are direct |
| `TokenEntity` | `DashboardInput` | Merged with fieldset |
| `TokenChoiceEntity` | N/A (JSON) | Choices now in `optionsJSON` field |
| `RowEntity` | `LayoutItem` | Layout is now explicit via LayoutItem |
| `PanelEntity` | `Visualization` | Separated from layout |
| `SearchEntity` | `DataSource` | First-class entity, reusable |
| `VisualizationEntity` | `Visualization` | Options in `optionsJSON`, context in `contextJSON` |
| `SearchExecutionEntity` | `SearchExecution` | Similar, links to DataSource |

## Common Code Patterns

### Fetching Dashboards

**OLD:**
```swift
@FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \DashboardEntity.title, ascending: true)]
) private var dashboards: FetchedResults<DashboardEntity>
```

**NEW:**
```swift
@FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Dashboard.title, ascending: true)],
    entity: Dashboard.entity()
) private var dashboards: FetchedResults<NSManagedObject>
```

### Accessing Inputs/Tokens

**OLD:**
```swift
for fieldset in dashboard.fieldsetsArray {
    for token in fieldset.tokensArray {
        // Use token
    }
}
```

**NEW:**
```swift
if let inputs = dashboard.value(forKey: "inputs") as? Set<NSManagedObject> {
    for input in inputs {
        let token = input.value(forKey: "token") as? String
        let optionsJSON = input.value(forKey: "optionsJSON") as? String
        // Parse choices from JSON if needed
    }
}
```

### Layout Rendering

**OLD:**
```swift
for row in dashboard.rowsArray {
    for panel in row.panelsArray {
        renderPanel(panel)
    }
}
```

**NEW:**
```swift
if let layout = dashboard.value(forKey: "layout") as? NSManagedObject,
   let items = layout.value(forKey: "layoutItems") as? Set<NSManagedObject> {
    let sortedItems = items.sorted {
        ($0.value(forKey: "position") as? Int32 ?? 0) < 
        ($1.value(forKey: "position") as? Int32 ?? 0)
    }
    for item in sortedItems {
        if let viz = item.value(forKey: "visualization") as? NSManagedObject {
            renderVisualization(viz)
        }
    }
}
```

### Data Source Access

**OLD:**
```swift
let search = panel.searches?.first
let query = search?.query
```

**NEW:**
```swift
if let dataSource = visualization.value(forKey: "dataSource") as? NSManagedObject {
    let query = dataSource.value(forKey: "query") as? String
}
```

## Notes

- Most entities now use `NSManagedObject` with KVC instead of generated classes
- Need to cast values and handle optionals carefully
- JSON fields (`optionsJSON`, `contextJSON`) need parsing
- Layout system is completely different - no more rows
