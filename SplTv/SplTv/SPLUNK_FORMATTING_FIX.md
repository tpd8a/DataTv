# Splunk Formatting Fixes

## Summary
Fixed the application of Splunk visualization formatting in the Dashboard Monitor view to correctly apply color formatting to cell backgrounds and number formatting (including units) to cell text.

## Issues Fixed

### 1. Color Formatting (Ranges/Scales/Values)
**Problem**: Color formatting from Splunk visualizations was being applied to text color instead of cell background.

**Solution**: 
- Moved `applyColorFormatting()` from the `textColor` calculation to the `backgroundColor` calculation in `cellView()`
- Added opacity (0.7) to Splunk colors to ensure text remains readable
- Maintained proper priority order:
  1. Custom cell background (highest)
  2. Change highlight background
  3. Splunk color formatting (NEW - was missing)
  4. Zebra striping (lowest)

**Location**: `DashboardMonitorView.swift` - `cellView()` function, lines ~1513-1528

### 2. Number Formatting (Units like £)
**Problem**: Number formatting with units (e.g., "£" with unitPosition "before") was implemented but might not have been clearly visible.

**Improvements**:
- Added spacing between units and numbers for better readability:
  - Before: `£100` → After: `£ 100`
  - Before: `100USD` → After: `100 USD`
- Added debug logging to verify formatting is being applied correctly
- Ensured empty units don't add extra spaces

**Location**: `VisualizationFormatting.swift` - `applyNumberFormatting()` function

## Code Changes

### DashboardMonitorView.swift - cellView()
```swift
let backgroundColor: Color = {
    // Custom cell background (if enabled) - takes highest priority
    if settings.tableAppearance.useCustomCellBackground {
        return settings.tableAppearance.customCellBackgroundColor
    }
    
    // Change highlight background (takes priority over zebra striping and Splunk formatting)
    if changeInfo.hasChanged && settings.cellChangeSettings.highlightStyle != .none {
        let baseColor = changeInfo.color
        let opacity = isAnimating && settings.cellChangeSettings.animateChanges ? 0.8 : settings.cellChangeSettings.fillOpacity
        return baseColor.opacity(opacity)
    }
    
    // ✨ NEW: Splunk color formatting (ranges/scales/values) - applies to background
    if let formatting = vizFormatting,
       let splunkColor = formatting.applyColorFormatting(field: field, value: rawValue ?? value) {
        return splunkColor.opacity(0.7) // Use opacity so text remains readable
    }
    
    // Zebra striping background (lowest priority)
    return rowBackground(for: rowIndex)
}()

let textColor: Color = {
    // ✨ REMOVED: Splunk color formatting no longer applied to text
    // (It now goes to background instead)
    
    // Changed cell text color override
    if changeInfo.hasChanged && settings.tableAppearance.changedCellTextColor != nil {
        return settings.tableAppearance.changedCellTextColor!
    }
    
    // Custom text color
    if let customColor = settings.tableAppearance.customTextColor {
        return customColor
    }
    
    // Default text color
    // ...
}()
```

### VisualizationFormatting.swift - applyNumberFormatting()
```swift
// Apply unit with proper spacing
let formattedValue: String
if !unit.isEmpty {
    if unitPosition == "before" {
        // Add space after unit for readability (e.g., "£ 100" instead of "£100")
        formattedValue = "\(unit) \(formattedNumber)"
    } else {
        // Add space before unit for readability (e.g., "100 USD" instead of "100USD")
        formattedValue = "\(formattedNumber) \(unit)"
    }
} else {
    formattedValue = formattedNumber
}

#if DEBUG
// Debug logging to verify formatting is being applied
print("💰 Number formatting applied to field '\(field)': \(value) → '\(formattedValue)' (unit: '\(unit)', position: \(unitPosition), precision: \(precision))")
#endif

return formattedValue
```

### VisualizationFormatting.swift - applyColorFormatting()
```swift
/// Apply color formatting to a field value
/// Returns a color that should be applied to the cell background, not text
public func applyColorFormatting(field: String, value: Any) -> Color? {
    // ... existing logic ...
    
    #if DEBUG
    if let color = resultColor {
        print("🎨 Color formatting applied to field '\(field)': \(value) → color (type: \(paletteType))")
    }
    #endif
    
    return resultColor
}
```

## Testing

To verify the fixes are working:

1. **Color Formatting**: 
   - Look for cells with colored backgrounds (not colored text) where Splunk color formatting is configured
   - Check the debug console for messages like: `🎨 Color formatting applied to field 'fieldName': value → color (type: list)`

2. **Number Formatting**:
   - Look for numbers with units like "£ 100" (with space) instead of "£100" (no space)
   - Check the debug console for messages like: `💰 Number formatting applied to field 'amount': 100 → '£ 100' (unit: '£', position: before, precision: 0)`

## Priority Order

The final priority order for cell background colors is now:

1. **Custom cell background** (user's manual override in settings)
2. **Change highlight** (orange/green/red when values change between executions)
3. **Splunk color formatting** (ranges/scales/values from dashboard config) ✨ NEW
4. **Zebra striping** (alternating row colors for readability)

Text color remains separate and is controlled by:
1. **Changed cell text color** (override for changed cells)
2. **Custom text color** (user's manual text color setting)
3. **Default text color** (system default based on dark/light mode)

## Notes

- Debug logging is only enabled in DEBUG builds and will not appear in release builds
- The 0.7 opacity on Splunk color backgrounds ensures text remains readable even with bright colors
- Spacing between units and numbers improves readability, especially for currency symbols
