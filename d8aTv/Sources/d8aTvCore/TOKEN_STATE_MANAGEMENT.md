# Token State Management Implementation

## Overview

We've implemented a comprehensive token state management system that tracks token values, integrates with CoreDataManager's search execution, and provides real-time visibility into token state.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  User Interaction Layer                                      │
│  ┌──────────────────┐                                        │
│  │  TokenInputView  │  ← User changes dropdown, text, etc.  │
│  └────────┬─────────┘                                        │
│           │                                                   │
│           ↓ saveTokenValue()                                │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  DashboardTokenManager (Singleton @Published)        │   │
│  │  ┌─────────────────────────────────────────────────┐ │   │
│  │  │ @Published tokenValues: [String: TokenValue]    │ │   │
│  │  │ @Published tokenDefinitions: [String: TokenEntity] │   │
│  │  │ @Published activeDashboardId: String?           │ │   │
│  │  └─────────────────────────────────────────────────┘ │   │
│  │                                                        │   │
│  │  • Tracks current values with metadata               │   │
│  │  • Manages token lifecycle                           │   │
│  │  • Posts notifications on changes                    │   │
│  │  • Integrates with CoreDataManager                   │   │
│  └──────────────────────────────────────────────────────┘   │
│           │                                                   │
│           ↓ getAllValues()                                  │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  CoreDataManager.shared                               │   │
│  │  • resolveTokens(userProvidedValues:)                │   │
│  │  • buildSearchParameters()                           │   │
│  │  • startSearchExecution()                            │   │
│  └──────────────────────────────────────────────────────┘   │
│           │                                                   │
│           ↓                                                   │
│  ┌──────────────────┐                                        │
│  │  Splunk Search    │                                        │
│  └──────────────────┘                                        │
└─────────────────────────────────────────────────────────────┘
```

## Key Components

### 1. **DashboardTokenManager** (`DashboardTokenManager.swift`)

**Purpose:** Central state management for all dashboard tokens

**Properties:**
```swift
@Published var tokenValues: [String: TokenValue]          // Current values
@Published var tokenDefinitions: [String: TokenEntity]    // CoreData defs
@Published var activeDashboardId: String?                 // Active dashboard
```

**Key Methods:**
```swift
// Load tokens from dashboard
func loadTokens(for dashboard: DashboardEntity)

// Set token value with source tracking
func setTokenValue(_ value: String, forToken name: String, source: TokenValueSource)

// Get current value
func getValue(forToken name: String) -> String?

// Get all values for CoreDataManager
func getAllValues() -> [String: String]

// Execute search with current token state
func executeSearch(searchId: String, in dashboardId: String) -> String

// Get statistics
func getStatistics() -> TokenStatistics
```

### 2. **TokenValue** (Value + Metadata)

```swift
struct TokenValue {
    let name: String           // Token name
    let value: String          // Current value
    let source: TokenValueSource  // How was it set?
    let lastUpdated: Date      // When was it changed?
}
```

### 3. **TokenValueSource** (Tracking)

```swift
enum TokenValueSource {
    case user        // 🟢 User changed via input
    case default     // ⚪ From token default/initial
    case calculated  // 🔵 Computed value
    case search      // 🟠 Populated from search
}
```

### 4. **TokenDebugView** (Visualization)

Collapsible debug panel showing:
- ✅ Total token count
- ✅ User-modified count
- ✅ Default values count
- ✅ Last update time
- ✅ List of all tokens with:
  - Source indicator icon
  - Current value
  - Last updated time
  - Color-coded background

## Integration Points

### Loading Tokens

```swift
// DashboardMainView.swift
.onAppear {
    if let dashboard = selectedDashboard, selectedMode == .render {
        tokenManager.loadTokens(for: dashboard)
    }
}

.onChange(of: selectedDashboard) { _, newDashboard in
    if let dashboard = newDashboard, selectedMode == .render {
        tokenManager.loadTokens(for: dashboard)
    }
}
```

### Updating Tokens

```swift
// TokenInputView.swift
private func saveTokenValue(_ value: String) {
    // Update TokenManager (tracks source, posts notifications)
    tokenManager.setTokenValue(value, forToken: token.name, source: .user)
}
```

### Executing Searches

```swift
// From TokenManager
let executionId = tokenManager.executeSearch(
    searchId: "my_search",
    in: dashboardId
)

// Internally calls CoreDataManager with current values:
CoreDataManager.shared.startSearchExecution(
    searchId: searchId,
    in: dashboardId,
    userTokenValues: getAllValues(),  // ← Current token state
    // ...
)
```

## Visual Flow

### Sidebar Layout

```
┌─────────────────────────────────────┐
│  View Mode: [Monitor] [Dashboard]  │
├─────────────────────────────────────┤
│  Dashboards                         │
│  • Security Dashboard 🟣3           │  ← Shows input count
│  • Network Monitor ✓                │  ← Selected
├─────────────────────────────────────┤
│  🎚️ Dashboard Inputs                │
│  ┌─────────────────────────────────┐│
│  │ File Chooser                    ││
│  │ [all              ▼]            ││  ← User selects "all"
│  │                                 ││
│  │ Time Range                      ││
│  │ [Last 24 hours    ▼]            ││
│  │                                 ││
│  │ [Submit ➤]                      ││
│  └─────────────────────────────────┘│
├─────────────────────────────────────┤
│  📋 Token Registry         [▼]      │  ← Collapsible
│  ┌─────────────────────────────────┐│
│  │ Statistics:                     ││
│  │ Total: 3  User: 2  Default: 1  ││
│  │ Last update: 2:34 PM            ││
│  │                                 ││
│  │ 🟢 filename                     ││  ← User-set
│  │    File Chooser                 ││
│  │    "*.log"           2:34 PM    ││
│  │                                 ││
│  │ 🟢 time_range                   ││  ← User-set
│  │    Time Range                   ││
│  │    "-24h to now"     2:33 PM    ││
│  │                                 ││
│  │ ⚪ environment                   ││  ← Default
│  │    Environment                  ││
│  │    "prod"            2:30 PM    ││
│  └─────────────────────────────────┘│
└─────────────────────────────────────┘
```

## Token Lifecycle

### 1. Dashboard Load
```
loadTokens(for: dashboard)
  ↓
Read all TokenEntity from CoreData
  ↓
Initialize TokenValue for each with default/initial
  ↓
Store in tokenValues dictionary
  ↓
Publish updates → SwiftUI re-renders
```

### 2. User Changes Value
```
User interacts with TokenInputView
  ↓
onChange handler triggered
  ↓
saveTokenValue(newValue) called
  ↓
tokenManager.setTokenValue(..., source: .user)
  ↓
Update tokenValues[name]
  ↓
Post .tokenValueChanged notification
  ↓
Publish updates → SwiftUI re-renders
```

### 3. Execute Search
```
User clicks Submit or search auto-triggers
  ↓
tokenManager.executeSearch(searchId, dashboardId)
  ↓
getAllValues() → [String: String]
  ↓
CoreDataManager.startSearchExecution(
    searchId, dashboardId,
    userTokenValues: values  ← Current state
)
  ↓
CoreDataManager.resolveTokens(
    userProvidedValues: values  ← Priority 1
)
  ↓
Token substitution in query
  ↓
Execute on Splunk
```

## Benefits

### ✅ Real-Time Visibility
- See all token values at a glance
- Track who/what set each value
- Monitor update timestamps

### ✅ State Persistence
- Values maintained across view changes
- Dashboard-scoped state
- Source tracking

### ✅ Integration with CoreDataManager
- Seamless pass-through to existing search execution
- No changes needed to CoreDataManager API
- Uses existing `userProvidedValues` parameter

### ✅ Debug/Development
- Token Registry shows complete state
- Color-coded by source
- Statistics for quick overview
- Can be hidden in production

### ✅ Notifications
- External components can listen for token changes
- Refresh triggers can respond to token updates
- Analytics/logging can track usage

## Usage Examples

### Setting Up in a View

```swift
struct MyDashboardView: View {
    @ObservedObject private var tokenManager = DashboardTokenManager.shared
    let dashboard: DashboardEntity
    
    var body: some View {
        VStack {
            // Your dashboard UI
        }
        .onAppear {
            tokenManager.loadTokens(for: dashboard)
        }
    }
}
```

### Listening for Changes

```swift
let observer = NotificationCenter.default.addObserver(
    forName: .tokenValueChanged,
    object: nil,
    queue: .main
) { notification in
    if let tokenName = notification.userInfo?["tokenName"] as? String,
       let tokenValue = notification.userInfo?["tokenValue"] as? String {
        print("Token '\(tokenName)' changed to '\(tokenValue)'")
    }
}
```

### Manual Token Updates

```swift
// Set a calculated token value
tokenManager.setTokenValue(
    "calculated_result_123",
    forToken: "my_calculated_token",
    source: .calculated
)

// Set a value from search results
tokenManager.setTokenValue(
    "192.168.1.1",
    forToken: "selected_ip",
    source: .search
)
```

### Getting Current Values

```swift
// Get single value
if let filename = tokenManager.getValue(forToken: "filename") {
    print("Current file: \(filename)")
}

// Get all values
let allValues = tokenManager.getAllValues()
print("Current state: \(allValues)")

// Get statistics
let stats = tokenManager.getStatistics()
print("Total tokens: \(stats.totalTokens)")
print("User modified: \(stats.userModified)")
```

## Future Enhancements

### 1. **Persistence**
- Save token state to UserDefaults
- Restore last-used values on app restart
- Per-dashboard preferences

### 2. **Validation**
- Required field validation
- Custom regex patterns
- Cross-token dependencies

### 3. **History**
- Track value change history
- Undo/redo functionality
- Audit trail

### 4. **Search Triggers**
- Auto-execute on `searchWhenChanged`
- Debounce rapid changes
- Conditional execution based on token state

### 5. **Dynamic Population**
- Populate dropdown choices from searches
- Cache search results
- Refresh on schedule

## Testing Checklist

- [ ] Load dashboard with tokens
- [ ] Change token value in UI
- [ ] Verify TokenManager updates
- [ ] Check Token Registry shows change
- [ ] Execute search with tokens
- [ ] Verify tokens passed to CoreDataManager
- [ ] Check notification posted
- [ ] Switch dashboards
- [ ] Verify tokens reload
- [ ] Check statistics accurate
- [ ] Collapse/expand Token Registry
- [ ] Multiple token types work

## Files Modified/Created

- ✅ **Created:** `DashboardTokenManager.swift` - Core token state management
- ✅ **Modified:** `DashboardMainView.swift` - Added TokenManager integration
- ✅ **Modified:** `TokenInputView` - Calls TokenManager on changes
- ✅ **Added:** `TokenDebugView` - Visual token state inspector
