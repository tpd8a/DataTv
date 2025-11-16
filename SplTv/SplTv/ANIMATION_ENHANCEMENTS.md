# Enhanced Animation System for Table Results

## Overview
This enhancement improves the animation system for table result changes by using Splunk's `groupby_rank` field metadata to intelligently identify row keys and apply appropriate animations based on whether rows are new, deleted, or simply have changed values.

## Key Features

### 1. **Intelligent Row Matching with `groupby_rank`**
- Extracts `groupby_rank` metadata from Splunk field definitions
- Uses ranked fields (e.g., `source`, `host`) as primary keys for row identification
- Falls back to heuristic detection (non-numeric fields) if metadata is unavailable
- Enables accurate tracking of rows even when they change position or values

### 2. **Granular Animation Based on Row Changes**

#### **Scenario A: Row Key Fields Match (Same Row, Different Values)**
When key fields (e.g., `host=so100`, `source=/opt/splunk/var/log/...`) match between current and previous results:
- **Only changed cells are animated** with highlight/glow effect
- Other cells in the row remain static
- Example: If only the `count` field changed, only that cell glows

#### **Scenario B: Row Key Fields Don't Match (Different Row Identity)**
When key fields change (row represents a different entity):
- **All cells in the row are animated**
- Indicates a fundamental change in what the row represents
- Example: If `host` changed from `so100` to `so200`, entire row animates

#### **Scenario C: New Rows**
When a row appears that wasn't in previous results:
- **Entire row slides in** from the right with a spring animation
- All cells in the row are highlighted
- Provides clear visual feedback for new data entries

#### **Scenario D: Deleted Rows** (Future Enhancement)
Rows that were in previous results but not in current:
- Tracked via `deletedRowSignatures` state
- Ready for fade-out or slide-out animation implementation

## Implementation Details

### New State Variables
```swift
@State private var fieldMetadata: [String: [String: Any]] = [:]  // Stores groupby_rank
@State private var newRowIndices: Set<Int> = []                  // Tracks new rows
@State private var deletedRowSignatures: Set<String> = []        // Tracks deleted rows
```

### Helper Methods

#### `getRowKeyFields(excludingField:)`
Returns key fields for row matching, preferring `groupby_rank` metadata over heuristics.

#### `rowSignature(for:keyFields:)`
Creates a unique signature for a row based on its key field values.

#### `isNewRow(at:)`
Determines if a row at a given index is new by comparing signatures.

#### `convertFieldToDict(_:)`
Extracts metadata dictionary from Splunk field objects.

### Enhanced `triggerCellAnimations()`
The core animation logic now:
1. Detects new rows by comparing row signatures
2. For new rows: animates all cells
3. For existing rows: compares individual cells
4. If key fields changed: animates entire row
5. If only value fields changed: animates specific cells
6. Tracks deleted rows for future animation support

### Row Rendering with Slide-In Animation
```swift
.offset(x: isNewRow ? (isNewRow && !animatingCells.isEmpty ? 0 : 20) : 0)
.opacity(isNewRow ? (isNewRow && !animatingCells.isEmpty ? 1.0 : 0.3) : 1.0)
.scaleEffect(isNewRow ? (isNewRow && !animatingCells.isEmpty ? 1.0 : 0.95) : 1.0, anchor: .leading)
```

## Example Output

When processing results with `groupby_rank` metadata:
```
📊 Field 'source' has groupby_rank: 0
📊 Field 'host' has groupby_rank: 1
🎯 Using groupby_rank fields: source, host

✨ New row detected at index 3
🔄 Row 5 key fields changed - animating entire row
🎬 Animating 24 changed cells and 1 new rows
```

## User Experience Improvements

### Visual Clarity
- **New data** slides in smoothly, catching attention
- **Changed values** glow individually, showing exactly what changed
- **Row identity changes** animate entirely, indicating major shifts

### Performance
- Efficient signature-based matching
- Minimal re-rendering with targeted animations
- Spring physics for natural motion feel

### Flexibility
- Works with any Splunk result set
- Gracefully degrades without `groupby_rank` metadata
- Respects existing animation settings and duration preferences

## Future Enhancements

### Deleted Row Animation
Currently tracked but not animated. Could add:
- Fade out effect for deleted rows
- Slide out animation before removal
- Temporary "ghost" rows showing what was removed

### Advanced Grouping
- Support for hierarchical groupings
- Multi-level animations (group header + row + cell)
- Collapse/expand animations for grouped data

### Custom Animation Profiles
- Different animation styles per field type
- User-configurable animation behaviors
- Per-dashboard animation preferences

## Technical Notes

### Field Metadata Extraction
The system attempts to extract `groupby_rank` from Splunk field objects. The exact structure depends on your Splunk REST API responses and Core Data model. You may need to adjust `convertFieldToDict()` based on actual field object structure.

### Signature Stability
Row signatures use key field values joined with `|` separator. Ensure key fields have stable, unique values across refreshes for accurate matching.

### Animation Timing
- Cell glow animations: 1.5s default (user configurable)
- New row slide-in: 0.6s spring animation
- Animation overlap handled by sequential state updates

## Debugging

Enable detailed logging with print statements:
- `🎯` marks groupby_rank field detection
- `✨` indicates new row detection
- `🔄` shows row identity changes
- `🎬` summarizes animation triggers
- `🗑️` tracks deleted rows

## Compatibility

- **macOS 26+**: Full support with all animations
- **tvOS 26+**: Full support (limited menu interactions)
- Requires `d8aTvCore` module with Splunk result parsing
- Works with existing cell change highlight settings
