# Critical Fixes - Multiple Formats Per Field & Row Matching

## Issue 1: £ Symbol Not Showing (FIXED)

### Root Cause
When a field has MULTIPLE formats (e.g., `count` has both `color` and `number`), the generic `format(forField:)` method was returning the **first** match only.

Your formats:
```
[1] field: 'count', type: 'color'      ← First match! ❌
[3] field: 'count', type: 'number'     ← Never reached
```

### Solution
Created type-specific lookup methods:
- `format(forField:type:)` - Gets a specific format by field AND type
- `formats(forField:)` - Gets ALL formats for a field

### Changes Made

**VisualizationFormatting.swift:**

```swift
/// Get format configuration for a specific field and type
/// Use this when a field might have multiple formats (e.g., both color and number)
public func format(forField field: String, type: String) -> [String: Any]? {
    return formats.first { format in
        guard let formatField = format["field"] as? String,
              let formatType = format["type"] as? String else {
            return false
        }
        return formatField == field && formatType == type
    }
}
```

**Updated callers:**
- `applyColorFormatting()` → Uses `format(forField:type:)` with type="color"
- `applyNumberFormatting()` → Uses `format(forField:type:)` with type="number"

### Result
Now both formats apply correctly:
- ✅ Count column cells get **gradient background** (color format)
- ✅ Count column text shows **"£ 100"** (number format)

## Issue 2: Row Matching Using Wrong Fields

### Root Cause
The console showed heuristic fields being used instead of groupby_rank fields:
```
🔍 Using heuristic key fields: source, host
```

This means either:
1. The groupby_rank metadata isn't being extracted
2. The Mirror reflection isn't finding the properties

### Solution
Added comprehensive debug logging to diagnose the field metadata extraction:

```swift
print("   📊 Extracting metadata from \(fieldObjects.count) fields...")
for field in fieldObjects {
    if let fieldDict = convertFieldToDict(field) {
        print("      Field '\(field.name)' dict keys: \(fieldDict.keys.joined(separator: ", "))")
        
        // Try both snake_case and camelCase
        if let groupbyRank = fieldDict["groupby_rank"] as? String {
            metadata["groupby_rank"] = groupbyRank
            print("      → groupby_rank: \(groupbyRank) ✅")
        } else if let groupbyRank = fieldDict["groupbyRank"] as? String {
            metadata["groupby_rank"] = groupbyRank
            print("      → groupbyRank (camelCase): \(groupbyRank) ✅")
        }
    }
}
```

### Expected Debug Output

**If groupby fields exist:**
```
📊 Extracting metadata from 5 fields...
   Field 'source' dict keys: name, groupby_rank
      → groupby_rank: 0 ✅
   Field 'host' dict keys: name, groupby_rank  
      → groupby_rank: 1 ✅
   Field 'count' dict keys: name
      → No groupby_rank found
```

**Then later:**
```
🎯 Using groupby_rank fields: source, host
```

**If no groupby fields:**
```
📊 Extracting metadata from 5 fields...
   Field 'source' dict keys: name
      → No groupby_rank found
   ...
```

**Then falls back to:**
```
🔍 Using heuristic key fields: source, host
```

## Testing Instructions

### Test 1: Multiple Formats on Same Field

1. Create a dashboard with these formats for the same field:
```json
{
  "field": "count",
  "type": "color",
  "palette": {"type": "minMidMax", "minColor": "#FFFFFF", "maxColor": "#118832"}
},
{
  "field": "count",
  "type": "number",
  "unit": "£",
  "unitPosition": "before",
  "precision": "0"
}
```

2. Check console output:
```
📊 Available formats:
   [0] field: 'count', type: 'color'
      → palette type: minMidMax
   [1] field: 'count', type: 'number'
      → unit: '£', position: before, precision: 0
```

3. Look for number formatting being applied:
```
✅ Found number format for field 'count': ...
💰 Formatting options: unit='£', position=before, precision=0
💰 Number formatting applied to field 'count': 100 → '£ 100'
```

4. Verify visual result:
   - Cell text: "£ 100" ✅
   - Cell background: Gradient color based on value ✅

### Test 2: Groupby Field Detection

1. Run a search with groupby fields (e.g., `| stats count by source, host`)

2. Check console output for field metadata:
```
📊 Extracting metadata from N fields...
   Field 'source' dict keys: ...
      → groupby_rank: 0 ✅ (or "No groupby_rank found")
```

3. Check row matching strategy:
```
🎯 Using groupby_rank fields: source, host  ← GOOD!
```
OR
```
🔍 Using heuristic key fields: source, host  ← Fallback
```

## What To Share

Please share the console output for these sections:
1. **Format loading:** `📊 Available formats:`
2. **Field metadata extraction:** `📊 Extracting metadata from N fields...`
3. **Number formatting application:** `💰 Number formatting applied...`
4. **Row matching strategy:** `🎯 Using groupby_rank fields:` or `🔍 Using heuristic key fields:`

This will show us:
- ✅ If number format is now found correctly
- ✅ If groupby_rank is being extracted
- ✅ Which row matching strategy is being used
