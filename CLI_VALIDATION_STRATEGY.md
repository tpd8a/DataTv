# CLI Validation Strategy for DashboardKit

## Overview

Instead of immediately migrating the complex SplTV GUI, we're using the **SplunkDashboardCLI** as a validation tool to confirm DashboardKit's CoreData schema works correctly.

## Why This Approach?

### Benefits
1. **Faster Feedback**: CLI is simpler than GUI with complex views
2. **Schema Validation**: Tests CoreData model works before GUI migration
3. **Incremental**: Can test load, query, and search operations independently
4. **Lower Risk**: If schema issues exist, easier to fix before GUI migration

### What the CLI Can Do

**Load Command:**
```bash
splunk-dashboard load dashboard.xml --id my_dash --app search
```
- Parses SimpleXML files
- Stores in CoreData using DashboardKit schema
- Perfect test of schema integrity

**Query Commands:**
```bash
splunk-dashboard query list                    # List all dashboards
splunk-dashboard query show my_dash            # Show dashboard details
splunk-dashboard query tokens                  # List all tokens
splunk-dashboard query searches                # List all searches
```
- Tests CoreData queries work
- Validates relationships
- Checks data retrieval

**Splunk Sync:**
```bash
splunk-dashboard splunk sync --app search
```
- Fetches dashboards from Splunk REST API
- Parses and stores them
- End-to-end test

## Current Setup

### Package Structure

The Package.swift now includes THREE targets:

```swift
products: [
    .library(name: "DashboardKit", targets: ["DashboardKit"]),
    .library(name: "d8aTvCore", targets: ["d8aTvCore"]),    // Old code
    .executable(name: "splunk-dashboard", targets: ["SplunkDashboardCLI"])
]
```

### Import Strategy

The CLI currently imports **BOTH** packages:

```swift
import DashboardKit  // New: Token models, CredentialManager, parsers
import d8aTvCore     // Old: DashboardLoader, DashboardQueryEngine
```

This allows:
- Use DashboardKit's new CoreData schema
- Use DashboardKit's parsers (SimpleXMLParser, DashboardStudioParser)
- Keep old DashboardLoader/DashboardQueryEngine temporarily for convenience
- Gradually migrate CLI components

## Migration Path for CLI

### Phase 1: Minimal Changes (CURRENT)
- ✅ Re-enable CLI in Package.swift
- ✅ Import both packages
- ⏳ Test basic compilation
- ⏳ Run `query list` command

### Phase 2: Credential Manager
- Replace `SplunkCredentialManager` → `CredentialManager`
- DashboardKit's version is already compatible
- Simple find/replace operation

### Phase 3: CoreData Manager
- `d8aTvCore.CoreDataManager` → `DashboardKit.CoreDataManager`
- Update query methods to use new entities
- Use KVC for entity access

### Phase 4: Dashboard Loading
Two options:
**A. Keep DashboardLoader, update internals** (Faster)
- Update entity creation to use new schema
- Keep XML parsing logic

**B. Use DashboardKit parsers directly** (Cleaner)
- Use `SimpleXMLParser` → get models
- Use `DashboardConverter` → convert to CoreData
- More aligned with DashboardKit design

## Testing Plan

### Test 1: Load SimpleXML Dashboard
```bash
# Get sample dashboard
cd d8aTv/docs/examples/
ls test_dashboard.xml

# Try to load it
.build/release/splunk-dashboard load test_dashboard.xml --id test --verbose
```

**Expected Result:**
- Parses XML ✓
- Creates Dashboard entity ✓
- Creates DataSource entities ✓
- Creates Visualization entities ✓
- Creates DashboardLayout + LayoutItems ✓
- Creates DashboardInput entities ✓

### Test 2: Query Dashboard
```bash
.build/release/splunk-dashboard query list
.build/release/splunk-dashboard query show test
.build/release/splunk-dashboard query tokens
```

**Expected Result:**
- Lists dashboard with correct title ✓
- Shows DataSources (not old SearchEntity) ✓
- Shows Visualizations with layout ✓
- Shows DashboardInputs (not old TokenEntity/FieldsetEntity) ✓

### Test 3: Verify Schema
```bash
.build/release/splunk-dashboard query debug test
```

**Expected Result:**
- JSON export shows new schema structure ✓
- DataSource.type = "ds.search" ✓
- Visualization.optionsJSON contains options ✓
- Layout.type = "bootstrap" or "absolute" ✓

## Success Criteria

✅ CLI compiles without errors
✅ Can load SimpleXML dashboard
✅ Dashboard appears in `query list`
✅ `query show` displays correct structure
✅ DataSources created (not SearchEntity)
✅ Visualizations + LayoutItems created (not Row/Panel)
✅ DashboardInputs created (not Fieldset/Token)
✅ Relationships work correctly

## Next Steps After Validation

Once CLI validates the schema works:

1. **Document findings** - Any schema issues discovered
2. **Fix schema if needed** - Adjust DashboardKit model
3. **Migrate SplTV GUI** - Now with confidence schema works
4. **Remove d8aTvCore dependency** - Fully migrate to DashboardKit

## Current Status

- ✅ CLI re-enabled in Package.swift
- ✅ Imports updated (DashboardKit + d8aTvCore)
- ⏳ Compilation test (requires Swift toolchain)
- ⏳ Load test
- ⏳ Query test

**Branch:** `claude/cli-dashboardkit-validation-01QtZj9aA9W5j7XyoZPFCpQt`

## Files Modified

1. `d8aTv/Package.swift` - Added CLI and d8aTvCore targets
2. `d8aTv/Sources/SplunkDashboardCLI/main.swift` - Updated imports

## Notes

- This is a **temporary validation strategy**
- d8aTvCore will eventually be fully replaced by DashboardKit
- CLI provides fast iteration for schema validation
- GUI migration proceeds after validation
