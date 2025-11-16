# Dashboard Token Input Implementation

## Overview

We've implemented a smart, context-aware token input system that displays dashboard inputs in appropriate locations based on their scope and usage patterns.

## Architecture

### 1. **Fieldset Tokens (Global Dashboard Inputs)**
**Location:** Sidebar (only visible in Dashboard view mode)

**Why:** 
- ✅ Always visible and accessible
- ✅ Doesn't take space from the main dashboard view
- ✅ Easy to navigate even on tvOS with focus management
- ✅ Contextual - only shown when viewing a dashboard in render mode

**Features:**
- Shows all fieldset tokens in a collapsible section
- Displays submit button if fieldset has `submitButton = true`
- Input count badge shown in dashboard list
- Supports all token types: text, dropdown, radio, checkbox, multiselect, time, link

### 2. **Panel-Level Tokens (Local Panel Inputs)**
**Location:** Within the panel itself (compact summary view)

**Why:**
- ✅ Contextual to specific panel
- ✅ Doesn't clutter global controls
- ✅ Shows only when relevant
- ✅ Compact display saves space

**Features:**
- Shows first 3 inputs with icons and names
- "and X more..." for additional inputs
- Type badges and icons
- Purple accent color to distinguish from other panel content

## Implementation Details

### Token Input Types Supported

| Type | Control | Features |
|------|---------|----------|
| **text** | TextField | Standard text entry |
| **dropdown** | Picker (menu) | Single selection from choices |
| **radio** | Radio buttons | Single selection with custom icons |
| **checkbox** | Checkboxes | Multiple selection |
| **multiselect** | Collapsible checkboxes | Multiple selection, compact |
| **time** | Time range menu | Preset time ranges |
| **link** | Menu | Navigation links |
| **calculated** | Read-only | Auto-computed tokens |

### Token Input Component (`TokenInputView`)

```swift
struct TokenInputView: View {
    let token: TokenEntity
    
    // Automatically renders appropriate control based on token type
    // Handles initialization from default/initial values
    // Supports token choices, validation, dependencies
}
```

**Key Features:**
- ✅ Type-safe rendering based on `CoreDataTokenType`
- ✅ Automatic value initialization from defaults
- ✅ Choice support (from TokenChoiceEntity)
- ✅ Disabled state handling
- ✅ Collapsible multiselect for space efficiency

## Visual Layout

```
┌─────────────────────────────────────────────────────────────────┐
│  Sidebar                    │  Main Dashboard View              │
├─────────────────────────────┼───────────────────────────────────┤
│  [Monitor] [Dashboard]      │  Dashboard Title                  │
│                             │  Description...                   │
│  Dashboards                 │                                   │
│  • Sales App                │  ┌─────────────────────────────┐ │
│  • Security 🟣3             │  │ Row 1                       │ │
│  • Network ✓               │  │                             │ │
│                             │  │ ┌────────────────┐          │ │
│  ┌─────────────────────┐   │  │ │ Panel 1        │          │ │
│  │ 🎚️ Dashboard Inputs │   │  │ │                │          │ │
│  ├─────────────────────┤   │  │ │ 🟣 Panel Inputs (2)     │ │
│  │ Time Range          │   │  │ │ 📝 Source: text         │ │
│  │  └─ Last 24 hours   │   │  │ │ 📋 Status: dropdown     │ │
│  │                      │   │  │ │                │          │ │
│  │ Environment          │   │  │ │ [Viz Icon] Table        │ │
│  │  └─ Production       │   │  │ └────────────────┘          │ │
│  │                      │   │  │                             │ │
│  │ Alert Level         │   │  │ ┌────────────────┐          │ │
│  │  ⚫ All              │   │  │ │ Panel 2        │          │ │
│  │  ○ Critical         │   │  │ │ [Viz Icon] Chart        │ │
│  │  ○ Warning          │   │  │ └────────────────┘          │ │
│  │                      │   │  └─────────────────────────────┘ │
│  │ [Submit Button]     │   │                                   │
│  └─────────────────────┘   │                                   │
└─────────────────────────────┴───────────────────────────────────┘
```

## Benefits

### macOS
- ✅ **Sidebar persistence** - inputs always accessible without scrolling
- ✅ **Space efficiency** - main view dedicated to visualizations
- ✅ **Clear hierarchy** - global vs panel-level inputs visually separated
- ✅ **Keyboard navigation** - tab through sidebar inputs

### tvOS
- ✅ **Focused navigation** - sidebar inputs are focusable group
- ✅ **No clutter** - main view stays clean for remote navigation
- ✅ **Logical grouping** - related inputs together in sidebar
- ✅ **Swipe gestures** - easy sidebar access

## Token State Management

Currently, tokens are rendered but not yet connected to:
- Token value persistence
- Search query token substitution
- Dashboard refresh on token change
- Token dependencies and conditions

### TODO: Next Steps
1. Implement token value storage (in-memory or UserDefaults)
2. Connect token changes to search execution
3. Handle token dependencies (depends/rejects)
4. Implement token conditions and actions
5. Add token validation
6. Support dynamic population from searches
7. Integrate with DashboardRefreshWorker for auto-refresh

## Code Structure

```
DashboardMainView.swift
├── DashboardMainView (main navigation hub)
│   ├── sidebarContent
│   │   ├── View mode picker
│   │   ├── Dashboard selector
│   │   └── dashboardInputsSection() ⭐ NEW
│   │       └── TokenInputView ⭐ NEW
│   │           ├── textInput
│   │           ├── dropdownInput
│   │           ├── radioInput
│   │           ├── checkboxInput
│   │           ├── multiselectInput
│   │           ├── timeInput
│   │           ├── linkInput
│   │           └── calculatedOrUndefinedInput
│   └── mainContent
│       ├── DashboardDetailView (monitor mode)
│       └── DashboardRenderView (dashboard mode)

DashboardRenderView.swift
├── DashboardRenderView
└── DashboardPanelView
    └── panelInputsSection ⭐ UPDATED
        └── Shows compact list of panel inputs
```

## Examples

### Simple Dashboard with Fieldset
```xml
<fieldset submitButton="true" autoRun="false">
  <input type="time" token="time_range">
    <label>Time Range</label>
    <default>
      <earliest>-24h@h</earliest>
      <latest>now</latest>
    </default>
  </input>
  
  <input type="dropdown" token="environment">
    <label>Environment</label>
    <choice value="prod">Production</choice>
    <choice value="stage">Staging</choice>
    <choice value="dev">Development</choice>
    <default>prod</default>
  </input>
</fieldset>
```

**Renders as:**
- Sidebar section "Dashboard Inputs"
- Time range picker with presets
- Environment dropdown
- Submit button at bottom

### Panel with Local Inputs
```xml
<panel>
  <title>Error Logs</title>
  <input type="text" token="search_filter">
    <label>Filter</label>
  </input>
  <input type="dropdown" token="severity">
    <label>Severity</label>
    <choice value="*">All</choice>
    <choice value="ERROR">Error</choice>
    <choice value="WARN">Warning</choice>
  </input>
  <table>
    <search>
      <query>index=logs $search_filter$ severity=$severity$</query>
    </search>
  </table>
</panel>
```

**Renders as:**
- Panel shows compact input summary: "Panel Inputs (2)"
- Lists: "Filter: text", "Severity: dropdown"
- Inputs are part of panel, not global sidebar

## Testing Checklist

- [ ] Fieldset tokens appear in sidebar
- [ ] Panel inputs show in panel content area
- [ ] Token type icons display correctly
- [ ] Input count badges show in dashboard list
- [ ] Submit button appears when fieldset has submitButton="true"
- [ ] All token types render appropriate controls
- [ ] Default values initialize correctly
- [ ] Multiselect collapses/expands
- [ ] tvOS navigation works with Focus Engine
- [ ] Sidebar width accommodates inputs (280pt min)
