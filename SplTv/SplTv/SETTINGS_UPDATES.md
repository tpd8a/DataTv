# Settings View Updates

## Summary of Changes

This document outlines the updates made to the application settings in `SplTvApp.swift` to improve authentication options and data management.

## Changes Made

### 1. Bearer Token Authentication Support

**Added:**
- New `@AppStorage` property: `splunkAuthType` (either "basic" or "token")
- State variables for token management: `splunkToken`, `showingTokenField`
- Segmented picker in the Connection tab to choose between "Basic (Username/Password)" and "Bearer Token"
- Token input field with secure storage in Keychain
- Token-specific keychain operations:
  - `storeToken(server:token:)` - Store token securely
  - `retrieveToken(server:)` - Retrieve stored token
  - `deleteToken(server:)` - Remove stored token

**Updated Functions:**
- `testSplunkConnection()` - Now checks auth type and uses appropriate credentials
- `syncDashboards()` - Now supports both basic and token authentication
- Added `storeTokenInKeychain()` and `loadTokenFromKeychain()` helper methods

**Extension Added:**
- `SplunkCredentialManager` extension with token management methods using Keychain Services

### 2. Reorganized Connection Tab UI

**Changes:**
- Moved "Test Connection" button from its own section into the "Authentication" section
- Button now appears directly below the authentication fields (Password or Token)
- More logical flow: configure server → configure auth → test connection
- Cleaner UI with fewer sections

**New Structure:**
```
Connection Tab
├── Server Connection
│   └── Base URL
├── Authentication
│   ├── Authentication Type (Picker)
│   ├── Username/Password OR Token (based on selection)
│   ├── Test Connection Button ← MOVED HERE
│   └── Connection Test Results
└── Default Settings
    ├── Default App
    └── Default Owner
```

### 3. CoreData Management in Reset Tab

**Added:**
- CoreData database size display (calculated in MB/KB)
- "Refresh Size" button to recalculate database size
- "Clear All CoreData" button with destructive styling
- Confirmation alert before clearing data
- State variables: `coreDataSize`, `showingClearDataAlert`

**New Functions:**
- `calculateCoreDataSize()` - Gets the physical size of the CoreData store file
- `clearAllCoreData()` - Performs batch delete operations on all entities
  - Deletes: DashboardEntity, SearchEntity, SearchExecutionEntity, SearchResultRecordEntity
  - Updates UI after clearing
  - Shows success/failure message

**New UI in Reset Tab:**
```
Reset Tab
├── Settings Reset (existing)
└── Data Management (NEW)
    ├── Database size display
    ├── Refresh Size button
    └── Clear All CoreData button (with confirmation alert)
```

## Usage Instructions

### Using Bearer Token Authentication

1. Open Settings (macOS: ⌘,)
2. Go to the "Connection" tab
3. Select "Bearer Token" from the Authentication Type picker
4. Click "Update" to enter your token
5. Paste your Splunk bearer token
6. Click "Store" to save it securely in Keychain
7. Click "Test Connection" to verify

### Clearing CoreData

1. Open Settings
2. Go to the "Reset" tab
3. Under "Data Management", review the current database size
4. Click "Clear All CoreData"
5. Confirm the action in the alert dialog
6. All dashboards, searches, and results will be permanently deleted

## Technical Details

### Authentication Flow

The app now supports two authentication methods with Splunk:

1. **Basic Authentication** (Username/Password)
   - Uses `SplunkCredentials.basic(username:password:)`
   - Stored in Keychain with service: username/password pair

2. **Bearer Token** (API Token)
   - Uses `SplunkCredentials.token(String)`
   - Stored in Keychain with service: "SplunkToken"
   - Account format: "token_{server}"

### CoreData Operations

The `clearAllCoreData()` function uses `NSBatchDeleteRequest` for efficient deletion:

```swift
let entityNames = ["DashboardEntity", "SearchEntity", 
                   "SearchExecutionEntity", "SearchResultRecordEntity"]

for entityName in entityNames {
    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
    let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
    try viewContext.execute(batchDeleteRequest)
}
```

### Security Considerations

- Passwords and tokens are never stored in `UserDefaults` or `AppStorage`
- All credentials are stored in the system Keychain
- Tokens are stored with a special prefix to avoid conflicts
- Secure input fields are cleared after storage

## Compatibility

- **macOS**: All features fully supported
- **tvOS**: Authentication methods work; CoreData clearing supported

## Testing Checklist

- [ ] Basic authentication with username/password
- [ ] Token authentication with bearer token
- [ ] Switching between auth types
- [ ] Test Connection button works in both modes
- [ ] Dashboard sync works with both auth types
- [ ] CoreData size calculation displays correctly
- [ ] Clear CoreData removes all data
- [ ] Confirmation alert appears before clearing
- [ ] UI updates after clearing data
- [ ] Settings persist across app launches
- [ ] Keychain storage/retrieval works correctly

## Future Enhancements

Potential improvements for future versions:

1. Session key authentication support (already in `SplunkCredentials.sessionKey`)
2. Multiple server profiles
3. Export/Import CoreData backup
4. Selective entity deletion (e.g., only clear results, keep dashboards)
5. CoreData storage optimization tools
6. Token expiration warnings
7. Automatic token refresh
