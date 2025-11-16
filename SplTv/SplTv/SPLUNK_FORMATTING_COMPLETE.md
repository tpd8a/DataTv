# Splunk Formatting - Complete Per-Field Implementation

## Summary
Implemented complete per-field Splunk visualization formatting in the Dashboard Monitor view. Each column can have independent formatting rules for both appearance (color backgrounds) and display (number formatting with units).

## Key Insight ✨
Each format in the `formats` array applies to a **specific field/column**, not the entire table:
- `error` field → threshold-based color formatting (red/yellow/green)
- `count` field → number formatting with "£" prefix + gradient coloring
- `info` field → categorical coloring (unique values get consistent colors)

## Supported Format Types

### 1. Color Formatting (Cell Backgrounds)

#### Threshold-Based (List Palette)
```json
{
  "field": "error",
  "type": "color",
  "palette": {
    "type": "list",
    "colors": ["#118832", "#1182F3", "#CBA700", "#D94E17", "#D41F1F"]
  },
  "scale": {
    "type": "threshold",
    "values": [0, 30, 70, 100]
  }
}
```
Values 0-30 → Green, 30-70 → Blue, 70-100 → Yellow, 100+ → Red

#### Gradient-Based (MinMidMax Palette)
```json
{
  "field": "count",
  "type": "color",
  "palette": {
    "type": "minMidMax",
    "minColor": "#FFFFFF",
    "maxColor": "#118832"
  }
}
```
Interpolates from white (low values) to green (high values)

#### Categorical (SharedList Palette)
```json
{
  "field": "info",
  "type": "color",
  "palette": {
    "type": "sharedList"
  },
  "scale": {
    "type": "sharedCategory"
  }
}
```
Each unique value gets a consistent color (same value → same color everywhere)

### 2. Number Formatting (Cell Text)

```json
{
  "field": "count",
  "type": "number",
  "unit": "£",
  "unitPosition": "before",
  "precision": "2"
}
```
Displays as: "£ 123.45" with proper spacing

## Implementation Details

### Per-Field Application Flow
When rendering a cell for field "count" with value 100:
1. Check for format → `format(forField: "count")` finds format with `"field": "count"`
2. Apply number formatting → "£ 100"
3. Apply color formatting → gradient color based on value
4. Render cell with formatted text and colored background

### Priority Order

**Cell Background Colors:**
1. Custom cell background (user override) - HIGHEST
2. Change highlight (value changed between executions)
3. **Splunk color formatting (per-field)** ✨
4. Zebra striping - LOWEST

**Cell Text:**
- **Splunk number formatting** applies to display value
- Text color controlled by user settings (not Splunk)

## Code Changes

### VisualizationFormatting.swift

Added support for all palette types:
- ✅ `list` - Threshold-based colors
- ✅ `minMidMax` - Gradient colors
- ✅ `sharedList` / `sharedCategory` - Categorical colors (NEW)

Added `applySharedCategoryColorFormat()` method:
- Uses hash-based color assignment for consistency
- Same values always get the same color
- Supports custom or default color palettes

Enhanced number formatting with proper spacing:
- "£ 100" instead of "£100"
- "100 USD" instead of "100USD"

### DashboardMonitorView.swift

Corrected color application target:
- ❌ **Before:** Splunk colors applied to text color
- ✅ **After:** Splunk colors applied to cell background

Maintained proper priority for backgrounds.

## Testing

### Debug Console Output
```
🎨 Color formatting applied to field 'error': 75 → color (type: list)
🎨 Color formatting applied to field 'info': "WARNING" → color (type: sharedList)
💰 Number formatting applied to field 'count': 100 → '£ 100' (unit: '£', position: before, precision: 0)
```

### Visual Verification
- **Threshold colors:** Different background colors based on value ranges
- **Gradient colors:** Smooth color transitions across value range
- **Categorical colors:** Same values → same color, different values → different colors
- **Number formatting:** Currency symbols with proper spacing

## Notes
- All Splunk color formatting goes to **backgrounds only**, never text
- Number formatting with units applies to **text only**, never backgrounds
- Each field/column has independent formatting rules
- Background opacity (0.7) ensures text readability
- Debug logging only in DEBUG builds
- Hash-based categorical coloring ensures consistency across refreshes
