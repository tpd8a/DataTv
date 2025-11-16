# Table Appearance Settings Redesign

## Summary

Redesigned the Table Appearance settings with a cleaner, more Apple-like interface following Apple Human Interface Guidelines. Removed redundant section titles, grouped related options, and added comprehensive font customization controls.

## Changes Made

### 1. **Added Font Customization to `TableAppearanceSettings`**

New properties added:
```swift
var fontDesign: Font.Design = .default
var fontSize: Double = 13 // Default system size
var fontWeight: Font.Weight = .regular
var isItalic: Bool = false
```

### 2. **Persistence Layer Updates**

Added save/load logic for font settings in UserDefaults:
- `tableFontDesign` (default/serif/rounded/monospaced)
- `tableFontSize` (9-24pt range)
- `tableFontWeight` (ultraLight through black)
- `tableFontIsItalic` (boolean)

### 3. **UI Redesign - Settings View**

#### **Before:**
- Multiple separate sections with redundant headers and footers
- Verbose "Enable/Disable" buttons
- Text color options spread across multiple sections
- No font customization

#### **After:**

**Section 1: Table Appearance (Font Settings)**
- Font Design Picker (Default, Serif, Rounded, Monospaced)
- Font Size Slider (9-24pt with live preview)
- Font Weight Picker (9 weight options)
- Italic Toggle

**Section 2: Text & Cell Options (Consolidated)**
- Custom Text Color with inline toggle and reset button
- Changed Cell Text Color with inline toggle and reset button
- Custom Cell Background toggle and color picker
- All grouped together for easier comparison

**Section 3: Zebra Striping (Standalone)**
- Zebra Striping toggle
- Opacity slider (if enabled)

### 4. **Font Application Throughout Table**

Updated all text rendering to use custom font settings:

- **Data Cells** - Apply all font settings (design, size, weight, italic)
- **Header Cells** - Apply font design and size, always bold
- **Row Number Header** - Apply font design and size, always bold
- **Row Number Cells** - Apply all font settings

### 5. **Apple Design Best Practices**

✅ **Followed Apple HIG Principles:**
- Removed verbose explanatory text (settings are self-explanatory)
- Used inline toggles instead of separate enable/disable buttons
- Added "Reset" buttons for optional settings (subtle, secondary style)
- Grouped related settings logically
- Used `.monospacedDigit()` for numeric displays
- Clean visual hierarchy with dividers
- Consistent spacing and alignment

✅ **System-Native Controls:**
- Standard `Picker` for font design and weight
- `Slider` with live value preview for size and opacity
- `ColorPicker` with `supportsOpacity: false` for solid colors
- `Toggle` for boolean options

✅ **Accessibility:**
- All controls labeled properly
- Font size range (9-24pt) covers accessibility needs
- Color pickers work with system color selection
- Settings persist across app launches

## User Experience Improvements

1. **Cleaner Interface** - Removed 3 section headers and 3 footer descriptions
2. **Faster Workflow** - Related options grouped, less scrolling
3. **Live Preview** - Font size and stripe opacity show current values
4. **Better Feedback** - "Reset" buttons appear only when custom values are set
5. **More Control** - Full font customization (type, size, weight, italic)

## Example Use Cases

### Accessibility Users
- Increase font size to 18-20pt for better readability
- Use bold weight for improved contrast
- Choose monospaced font for data-heavy tables

### Dense Data Tables
- Reduce font size to 10-11pt to fit more information
- Use light/regular weight for cleaner appearance
- Disable zebra striping if using custom backgrounds

### Presentation Mode
- Use rounded font design for friendlier appearance
- Increase font size to 16pt for visibility
- Use semibold weight for emphasis

## Technical Notes

- Font settings persist in UserDefaults
- All settings load on app launch
- Font changes apply immediately to all table elements
- Header cells always bold (overriding weight setting for clarity)
- Compatible with existing color formatting (Splunk colors, change highlighting)

## Migration Path

Existing users will see:
- Default font design (.default)
- Default font size (13pt - equivalent to previous .caption)
- Regular weight
- Not italic

No breaking changes - all existing settings preserved.
