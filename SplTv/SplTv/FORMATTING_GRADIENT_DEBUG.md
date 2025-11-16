# Splunk Formatting - MinMidMax Gradient & Number Formatting Debug

## Changes Made

### 1. Fixed MinMidMax Gradient Calculation

**Problem**: MinMidMax palette was using a hardcoded 0-100 range instead of calculating actual min/max from the data.

**Solution**: 
- Updated `applyColorFormatting()` to accept `allValues` parameter
- Calculate actual min/max values from the column data
- Normalize each cell value based on actual data range
- Implement proper RGB color interpolation

**Before:**
```swift
// Assumed 0-100 range
let normalizedValue = min(max(numericValue / 100.0, 0.0), 1.0)
```

**After:**
```swift
// Calculate from actual data
let allColumnValues = results.map { $0[field] }
let minValue = numericValues.min() ?? 0
let maxValue = numericValues.max() ?? 100
let normalizedValue = (numericValue - minValue) / (maxValue - minValue)
```

**Example:**
- Column values: [50, 100, 150, 200]
- Min = 50, Max = 200
- Value 50 → normalized 0.0 → minColor
- Value 125 → normalized 0.5 → halfway between colors
- Value 200 → normalized 1.0 → maxColor

### 2. Improved RGB Color Interpolation

**Problem**: Color interpolation was just picking one color or the other (threshold-based).

**Solution**: Implement proper linear RGB interpolation.

**Before:**
```swift
return fraction < 0.5 ? from : to  // Just pick one!
```

**After:**
```swift
// Interpolate each RGB component
let r = fromR + (toR - fromR) * fraction
let g = fromG + (toG - fromG) * fraction
let b = fromB + (toB - fromB) * fraction
return Color(red: r, green: g, blue: b)
```

**Example:**
- From: White #FFFFFF (r=1.0, g=1.0, b=1.0)
- To: Green #118832 (r=0.067, g=0.533, b=0.196)
- Fraction 0.5 → (r=0.533, g=0.766, b=0.598) = Light green

### 3. Enhanced Number Formatting Debug Logging

**Problem**: Can't tell if number formatting is being called or why it's failing.

**Solution**: Added comprehensive debug logging at each step.

**Debug Output:**
```
✅ Found number format for field 'count': ["field": "count", "type": "number", "unit": "£", ...]
💰 Formatting options: unit='£', position=before, precision=0
💰 Number formatting applied to field 'count': 100 → '£ 100' (unit: '£', position: before, precision: 0)
```

**Failure Diagnostics:**
```
⚠️ No format found for field 'amount'
⚠️ Format for field 'status' is type 'color', not 'number'
⚠️ Could not parse value 'N/A' as number for field 'count'
```

### 4. Format Loading Debug Output

**Problem**: Can't see what formats are actually loaded from the dashboard.

**Solution**: Print all formats when loading results.

**Debug Output:**
```
📊 Loaded table options: wrap=false, rowNumbers=true, displayCount=10
📊 Available formats:
   [0] field: 'error', type: 'color'
      → palette type: list
   [1] field: 'count', type: 'number'
      → unit: '£', position: before, precision: 0
   [2] field: 'count', type: 'color'
      → palette type: minMidMax
   [3] field: 'info', type: 'color'
      → palette type: sharedList
```

## Testing Guide

### Test MinMidMax Gradient

1. Create a format with minMidMax palette:
```json
{
  "field": "amount",
  "type": "color",
  "palette": {
    "type": "minMidMax",
    "minColor": "#FFFFFF",
    "maxColor": "#118832"
  }
}
```

2. Look for debug output:
```
🎨 MinMidMax gradient: value=150, min=50, max=200, normalized=0.67
🎨 Color formatting applied to field 'amount': 150 → color (type: minMidMax)
```

3. Verify visual result:
- Lowest value → White background
- Highest value → Dark green background
- Middle values → Gradient from white to green

### Test Number Formatting

1. Create a format with unit:
```json
{
  "field": "count",
  "type": "number",
  "unit": "£",
  "unitPosition": "before",
  "precision": "2"
}
```

2. Look for debug output:
```
✅ Found number format for field 'count': ...
💰 Formatting options: unit='£', position=before, precision=2
💰 Number formatting applied to field 'count': 100 → '£ 100.00' (unit: '£', position: before, precision: 2)
```

3. Verify visual result:
- Cell text should show "£ 100.00" (with space after £)
- NOT "100" or "£100" (without space)

### Troubleshooting

#### Number Formatting Not Showing

If you see the format loaded but text doesn't show the unit:

**Check 1:** Is the format loaded?
```
📊 Available formats:
   [1] field: 'count', type: 'number'
      → unit: '£', position: before, precision: 0
```
✅ Format is loaded correctly

**Check 2:** Is formatting being applied?
```
✅ Found number format for field 'count': ...
💰 Number formatting applied to field 'count': 100 → '£ 100'
```
✅ Formatting is being applied

**Check 3:** Is the field name correct?
```
⚠️ No format found for field 'amount'
```
❌ Field name mismatch - check your format's "field" value

**Check 4:** Is the value numeric?
```
⚠️ Could not parse value 'N/A' as number for field 'count'
```
❌ Value is not a number - formatting only works on numeric values

#### MinMidMax Colors Not Gradating

If all cells have the same color instead of a gradient:

**Check 1:** Are all values the same?
```
🎨 MinMidMax gradient: value=100, min=100, max=100, normalized=0.50
```
✅ All values are 100, so gradient can't be calculated (shows middle color)

**Check 2:** Is the range very small?
```
🎨 MinMidMax gradient: value=100.1, min=100, max=100.2, normalized=0.50
```
⚠️ Range is too small (0.2), gradient may not be visible

**Check 3:** Are colors being applied?
```
🎨 Color formatting applied to field 'amount': 150 → color (type: minMidMax)
```
✅ Colors are being applied

## Code Locations

### VisualizationFormatting.swift
- `applyColorFormatting()` - Line ~120 - Now accepts `allValues` parameter
- `applyMinMidMaxColorFormat()` - Line ~210 - Calculates from actual min/max
- `interpolateColor()` - Line ~396 - Proper RGB interpolation
- `applyNumberFormatting()` - Line ~310 - Enhanced debug logging

### DashboardMonitorView.swift
- `cellView()` - Line ~1526 - Passes column values for gradient calculation
- `loadResults()` - Line ~1851 - Prints loaded formats for debugging

## Next Steps

If £ is still not showing:

1. Check the console for format loading:
   - Do you see `📊 Available formats:` with your field?
   - Does it show `unit: '£'`?

2. Check the console for formatting application:
   - Do you see `💰 Number formatting applied to field...`?
   - Does it show the formatted value with £?

3. Check the field name:
   - Does the format's "field" value exactly match the column name?
   - Field names are case-sensitive!

Share the console output and I can help diagnose further!
