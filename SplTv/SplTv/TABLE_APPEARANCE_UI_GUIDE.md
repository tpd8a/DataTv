# Table Appearance Settings - UI Guide

## New Settings Layout

### Section 1: Table Appearance (Font Controls)
```
┌─────────────────────────────────────────────────────┐
│ 📋 Table Appearance                                 │
├─────────────────────────────────────────────────────┤
│ Font                             [Default      ▼]   │
│                                                     │
│ Font Size                                    13pt   │
│ ├─────●──────────────────────────────────┤          │
│ 9pt                                      24pt       │
│                                                     │
│ Weight                            [Regular     ▼]   │
│                                                     │
│ ☐ Italic                                           │
└─────────────────────────────────────────────────────┘
```

**Controls:**
- **Font Picker**: Default, Serif, Rounded, Monospaced
- **Font Size Slider**: 9pt to 24pt (default: 13pt)
- **Weight Picker**: 9 options from Ultralight to Black
- **Italic Toggle**: Enable/disable italic styling

---

### Section 2: Text & Cell Options (Consolidated)
```
┌─────────────────────────────────────────────────────┐
│ Text Color                              [Reset]     │
│ [Color Picker]                                      │
│ ☑ Using Custom Text Color                          │
│                                                     │
│ ─────────────────────────────────────────────────   │
│                                                     │
│ Changed Cell Text Color                  [Reset]   │
│ [Color Picker]                                      │
│ ☐ Use Custom Changed Text Color                    │
│                                                     │
│ ─────────────────────────────────────────────────   │
│                                                     │
│ ☐ Custom Cell Background                           │
│                                                     │
└─────────────────────────────────────────────────────┘
```

**Behavior:**
- Toggle controls enable/disable the color pickers
- "Reset" buttons appear only when custom colors are active
- Dividers separate logical groups within the section

---

### Section 3: Zebra Striping (Standalone)
```
┌─────────────────────────────────────────────────────┐
│ ☑ Zebra Striping                                    │
│                                                     │
│ Stripe Opacity                               15%   │
│ ├──────●──────────────────────────────┤            │
│ 1%                                    50%           │
└─────────────────────────────────────────────────────┘
```

**Controls:**
- **Zebra Striping Toggle**: Enable/disable alternate row colors
- **Opacity Slider**: 1% to 50% (only visible when enabled)

---

## Font Design Options

### Default
```
Field1    Field2    Field3
Value1    Value2    Value3
System standard sans-serif font
```

### Serif
```
Field1    Field2    Field3
Value1    Value2    Value3
Classic serif font for formal documents
```

### Rounded
```
Field1    Field2    Field3
Value1    Value2    Value3
Friendly rounded edges
```

### Monospaced
```
Field1    Field2    Field3
Value1    Value2    Value3
Fixed-width for aligned data
```

---

## Font Weight Comparison

| Weight      | Example       | Best Use Case                    |
|-------------|---------------|----------------------------------|
| Ultralight  | **Data**      | Light backgrounds, subtle text   |
| Thin        | **Data**      | Modern minimalist designs        |
| Light       | **Data**      | Large text sizes                 |
| Regular     | **Data**      | Default, general purpose         |
| Medium      | **Data**      | Slightly emphasized              |
| Semibold    | **Data**      | Important values                 |
| Bold        | **Data**      | Headers, key metrics             |
| Heavy       | **Data**      | High contrast displays           |
| Black       | **Data**      | Maximum emphasis                 |

---

## Complete Example Configurations

### Configuration 1: Accessibility Focused
```swift
fontDesign: .default
fontSize: 18
fontWeight: .semibold
isItalic: false
customTextColor: .primary (none)
enableZebraStriping: true
zebraStripeOpacity: 0.25
```
**Result:** Large, bold text with high-contrast zebra striping

---

### Configuration 2: Dense Data Display
```swift
fontDesign: .monospaced
fontSize: 10
fontWeight: .light
isItalic: false
customTextColor: .secondary
enableZebraStriping: true
zebraStripeOpacity: 0.08
```
**Result:** Compact monospaced layout with subtle striping

---

### Configuration 3: Presentation Mode
```swift
fontDesign: .rounded
fontSize: 16
fontWeight: .medium
isItalic: false
customTextColor: .primary (none)
enableZebraStriping: false
useCustomCellBackground: true
customCellBackgroundColor: .white
```
**Result:** Clean, modern look with white cells and no striping

---

### Configuration 4: Professional Report
```swift
fontDesign: .serif
fontSize: 13
fontWeight: .regular
isItalic: false
customTextColor: .black
enableZebraStriping: true
zebraStripeOpacity: 0.12
```
**Result:** Traditional serif font with subtle zebra striping

---

## Interaction Patterns

### Enabling Custom Text Color
1. User toggles "Use Custom Text Color" ON
2. Color picker becomes active
3. "Reset" button appears
4. System applies color to all cells immediately

### Adjusting Font Size
1. User drags slider
2. Value updates in real-time (e.g., "14pt")
3. Table refreshes with new font size
4. All cells, headers, and row numbers update

### Reset Button Behavior
1. Click "Reset" button
2. Custom color is cleared (sets to nil)
3. Toggle automatically switches OFF
4. "Reset" button disappears
5. System color is restored

---

## Keyboard Navigation

- **Tab**: Move between controls
- **Space**: Toggle checkboxes
- **Return**: Open pickers
- **Arrow Keys**: Navigate picker options and slider
- **Esc**: Close pickers

---

## Persistence

All settings automatically save to UserDefaults:

| Setting                    | Key                          | Type    |
|----------------------------|------------------------------|---------|
| Font Design                | `tableFontDesign`            | String  |
| Font Size                  | `tableFontSize`              | Double  |
| Font Weight                | `tableFontWeight`            | String  |
| Italic                     | `tableFontIsItalic`          | Bool    |
| Custom Text Color          | `tableCustomTextColor`       | Data    |
| Changed Text Color         | `tableChangedCellTextColor`  | Data    |
| Custom Cell Background     | `tableCellBackgroundColor`   | Data    |
| Use Custom Background      | `tableUseCustomCellBackground` | Bool  |
| Enable Zebra Striping      | `tableEnableZebraStriping`   | Bool    |
| Zebra Stripe Opacity       | `tableZebraStripeOpacity`    | Double  |

Settings persist across:
- App restarts
- Different visualizations
- Dashboard switches

---

## Design Philosophy

### What Changed
❌ **Removed:**
- Section footers with explanatory text
- Separate "Enable/Disable" buttons
- Redundant section headers
- Multiple isolated sections for related options

✅ **Added:**
- Comprehensive font controls
- Inline toggles with reset buttons
- Grouped related options
- Live value previews
- Cleaner visual hierarchy

### Why It's Better
1. **Less Clutter** - Settings are self-explanatory, no need for verbose descriptions
2. **Faster Access** - Related options grouped logically
3. **More Intuitive** - Standard Apple patterns (inline toggles, reset buttons)
4. **Better Scanning** - Clear visual separation with dividers
5. **More Powerful** - Full font control without overwhelming the user

### Apple HIG Compliance
- ✅ Uses system-standard controls
- ✅ Follows Settings app conventions
- ✅ Clear information hierarchy
- ✅ Appropriate use of color
- ✅ Accessibility-friendly sizing and controls
- ✅ Consistent with macOS preferences patterns
