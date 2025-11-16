# Dashboard Monitor App - Debug Output Guide

## What You Should See When Running the App

When you run the app successfully, you should see console output in this order:

### 1. App Initialization
```
🚀 DashboardMonitorApp.init() called
📱 macOS version: 15.0 (or whatever your version is)
🗂️ Bundle identifier: <your bundle ID or nil>
📦 Bundle path: <path to your app>
```

### 2. Core Data Initialization
```
🔄 DashboardRefreshWorker initialized
```

### 3. Scene Building
```
🎬 DashboardMonitorApp.body called - about to build scene
🏗️ buildScene() called
🖥️ Building macOS scene
🪟 WindowGroup body called - creating DashboardMonitorView
```

### 4. View Initialization
```
🎯 DashboardMonitorView.init() called
```

### 5. View Body Evaluation
```
🎯 DashboardMonitorView.body called, dashboards count: <number>
```

### 6. View Appeared
```
✅ DashboardMonitorView appeared!
   - Dashboards: <count>
   - Active timers: <count>
   - Is running: <true/false>
```

---

## What It Means If You Don't See Certain Output

### If you see NOTHING:
- The executable may not be running at all
- Check that you're running the right target
- Check Xcode's console output tab

### If you see only up to "App Initialization":
- The app is starting but failing somewhere in Core Data setup
- Check CoreDataManager for errors

### If you see up to "Scene Building" but nothing after:
- SwiftUI is unable to build the scene
- There may be a compilation issue with the views
- Check for `@available` attributes blocking the code

### If you see up to "View Initialization" but no "View Appeared":
- The view is being created but not displayed
- Could be a window display issue
- Could be a layout/constraint issue preventing the view from appearing

---

## Removed Issues

✅ **Fixed:** All `@available(macOS 26, tvOS 26, *)` attributes have been removed
- These were preventing the app from running on macOS 15.x (v25)
- The app now uses `#if os(macOS)` compiler directives instead

---

## Additional Debugging Tips

### Check Console Output
- In Xcode: View → Debug Area → Activate Console (⇧⌘C)
- Make sure "All Output" is selected in the filter dropdown

### Set Breakpoints
Good places to set breakpoints:
- Line with `init()` in `DashboardMonitorApp`
- Line with `return buildScene()` in `DashboardMonitorApp.body`
- Line with `print("🎯 DashboardMonitorView.init() called")`

### Check the Target
- Make sure you're running the correct target (DashboardMonitorApp)
- Check Product → Scheme → Edit Scheme to ensure the right executable is selected

### Verify Platform
- Product → Destination → Make sure a Mac destination is selected
- Should say "My Mac" or similar

---

## Next Steps If Still Not Working

If you've verified the console output and still don't see the app:

1. **Check for Core Data issues:** Look for any error messages about the persistent store
2. **Check bundle identifier:** SPM executables sometimes have issues without proper bundle IDs
3. **Try a clean build:** Product → Clean Build Folder (⇧⌘K), then rebuild
4. **Check Xcode version:** Make sure you're on a recent version that supports SwiftUI on macOS
