# Splunk Dashboard Integration

This document describes the new Splunk integration capabilities that allow you to connect directly to Splunk servers, authenticate, browse applications and dashboards, and sync dashboard data to Core Data.

## Overview

The Splunk integration extends your existing dashboard CLI with the following capabilities:

- **Configuration Management**: Use `SplunkConfiguration.plist` for server settings
- **Authentication**: Support for tokens, username/password, and secure credential storage
- **Application Discovery**: Browse available Splunk applications
- **Dashboard Discovery**: List dashboards within applications  
- **Automated Sync**: Download dashboard XML and sync to Core Data
- **Security**: Secure credential storage using macOS Keychain

## Quick Start

### 1. Configure Connection

Create or edit `SplunkConfiguration.plist` with your Splunk server details:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>baseURL</key>
    <string>https://your-splunk-server.com:8089</string>
    <key>defaultApp</key>
    <string>search</string>
    <!-- ... other settings ... -->
</dict>
</plist>
```

### 2. Authenticate

```bash
# Using username/password
splunk-dashboard splunk login --username admin --password changeme

# Using API token (recommended)
splunk-dashboard splunk login --token your-api-token-here
```

### 3. Browse Available Data

```bash
# List available applications
splunk-dashboard splunk apps

# List dashboards in an application
splunk-dashboard splunk dashboards search
```

### 4. Sync Dashboards

```bash
# Sync specific applications
splunk-dashboard splunk sync --apps "search,SplunkEnterpriseSecuritySuite"

# Sync all available applications
splunk-dashboard splunk sync --all

# Sync with verbose output
splunk-dashboard splunk sync --verbose
```

## Configuration File

The `SplunkConfiguration.plist` file contains all static configuration data and should be included as a resource in your app bundle. This ensures the configuration is bundled with your application and available at runtime.

### Adding Configuration to Your Project

1. **Create SplunkConfiguration.plist** in your Xcode project
2. **Add to App Bundle**: Ensure the plist is added to your app target's resources
3. **Configure Settings**: Set your Splunk server details and preferences

### Key Configuration Sections

#### Server Connection
- `baseURL`: Splunk server URL and port
- `timeout`: Request timeout in seconds
- `maxRetries`: Number of retry attempts
- `validateSSLCertificate`: Enable SSL validation

#### Authentication
- `authenticationMethods`: Supported auth methods and endpoints
- Never store actual credentials in the plist file

#### Dashboard Sync
- `batchSize`: Number of dashboards to process at once
- `maxDashboards`: Maximum dashboards per application
- `defaultAppsToSync`: Applications to sync by default
- `includePrivate`: Whether to include private dashboards

#### Application Filters
- `excludePatterns`: Regex patterns for apps to exclude
- `includeOnlyVisible`: Only sync visible applications
- `includeOnlyEnabled`: Only sync enabled applications

#### Core Data Mapping  
- `entityName`: Core Data entity name for dashboards
- `batchInsertSize`: Core Data batch insert size
- `preserveSourceXML`: Store original XML in database
- `extractTokens`: Parse and store dashboard tokens
- `parseSearches`: Extract search queries

## CLI Commands

### Authentication Commands

```bash
# Test connection and verify credentials
splunk-dashboard splunk login --username admin --password changeme

# Use API token authentication
splunk-dashboard splunk login --token your-api-token

# Interactive credential entry
splunk-dashboard splunk login
```

### Discovery Commands

```bash
# List all available applications
splunk-dashboard splunk apps

# Include disabled/hidden apps
splunk-dashboard splunk apps --include-disabled --include-invisible  

# List dashboards in specific app
splunk-dashboard splunk dashboards search

# List with count limit
splunk-dashboard splunk dashboards search --count 50
```

### Sync Commands

```bash
# Sync specific applications
splunk-dashboard splunk sync --apps "search,security"

# Sync all available applications  
splunk-dashboard splunk sync --all

# Sync with custom configuration
splunk-dashboard splunk sync --config /path/to/config.plist

# Verbose sync with detailed output
splunk-dashboard splunk sync --verbose
```

### Configuration Commands

```bash
# Show current configuration
splunk-dashboard splunk config --show

# Validate configuration file
splunk-dashboard splunk config --validate

# Use custom configuration file
splunk-dashboard splunk config --config /path/to/config.plist --show
```

## Secure Credential Management

The integration includes `SplunkCredentialManager` for secure credential storage using macOS Keychain.

### Storing Credentials

```swift
let credManager = SplunkCredentialManager()

// Store API token (recommended)
try credManager.storeToken(server: "splunk.company.com", token: "your-api-token")

// Store username/password  
try credManager.storeCredentials(server: "splunk.company.com", 
                               username: "admin", 
                               password: "changeme")
```

### Retrieving Credentials

```swift
// Retrieve API token
let token = try credManager.retrieveToken(server: "splunk.company.com")
let credentials = SplunkCredentials.token(token)

// Retrieve password
let password = try credManager.retrieveCredentials(server: "splunk.company.com", 
                                                 username: "admin")
let credentials = SplunkCredentials.basic(username: "admin", password: password)
```

### List Stored Credentials

```swift
let stored = try credManager.listStoredCredentials()
for credential in stored {
    print(credential.displayString)  // "admin @ splunk.company.com (Password)"
}
```

## Integration with Existing Core Data

The sync process integrates seamlessly with your existing Core Data model:

1. **Download**: Dashboard XML is retrieved from Splunk REST API
2. **Transform**: XML is written to temporary files  
3. **Load**: Your existing `DashboardLoader` processes the XML
4. **Parse**: Token extraction and search parsing occurs as normal
5. **Store**: Data is saved to Core Data using your existing model
6. **Cleanup**: Temporary files are removed

The `SplunkDashboardSyncService` uses the `DashboardLoaderProtocol` to work with your existing Core Data loading logic while adding Splunk connectivity.

## Error Handling

The integration provides comprehensive error handling:

- **Authentication Errors**: Invalid credentials, expired tokens
- **Connection Errors**: Network issues, SSL problems
- **Authorization Errors**: Insufficient permissions
- **Data Errors**: Invalid responses, parsing failures
- **Core Data Errors**: Storage failures, conflicts

All errors include detailed messages and are logged according to configuration settings.

## Performance and Monitoring

### Batch Processing
- Dashboards are processed in configurable batches
- Memory usage is controlled through streaming
- Progress reporting during large syncs

### Performance Metrics
- Sync duration tracking
- Success/failure statistics
- Error reporting and categorization
- Configurable logging levels

### Configuration Options
- `batchSize`: Control memory usage during sync
- `maxDashboards`: Limit total dashboards per app
- `timeout`: Network request timeout
- `enablePerformanceMetrics`: Track performance data

## Security Best Practices

1. **Use API Tokens**: Preferred over username/password
2. **Secure Storage**: Use SplunkCredentialManager for credentials
3. **SSL Validation**: Always validate SSL certificates in production
4. **Minimal Permissions**: Use accounts with only required permissions
5. **Token Rotation**: Regularly rotate API tokens
6. **Configuration Security**: Never store credentials in plist files
7. **Network Security**: Use HTTPS and proper firewall rules

## Troubleshooting

### Connection Issues
```bash
# Test basic connectivity
splunk-dashboard splunk login --username admin --password changeme

# Check configuration
splunk-dashboard splunk config --validate

# Use verbose output
splunk-dashboard splunk sync --verbose
```

### Authentication Problems
- Verify credentials are correct
- Check if account has required permissions
- Ensure token hasn't expired
- Verify SSL certificate trust

### Sync Issues
- Check Core Data permissions
- Verify disk space for temporary files
- Review application filters in configuration
- Check network connectivity during sync

### Common Error Messages

- `Configuration not found`: Place SplunkConfiguration.plist in standard location
- `Authentication failed`: Verify credentials and permissions
- `Dashboard not found`: Check app name and dashboard existence
- `Core Data sync failed`: Review Core Data model and permissions

## API Reference

The integration provides several key classes:

### SplunkConfiguration
- Configuration management and plist loading
- Credential integration and validation
- Settings for sync behavior and filters

### SplunkRestClient
- Low-level REST API communication
- Authentication handling
- Request/response processing

### SplunkDashboardService
- High-level dashboard operations
- Application discovery
- Dashboard listing and retrieval

### SplunkDashboardSyncService
- Automated sync from Splunk to Core Data
- Batch processing and error handling
- Progress reporting and metrics

### SplunkCredentialManager
- Secure credential storage using Keychain
- Token and password management
- Credential listing and cleanup

See the source files for detailed API documentation and usage examples.
