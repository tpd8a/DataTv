import Foundation
import d8aTvCore

/// Example demonstrating how to use SplunkConfiguration.plist with CLI
/// This file shows the complete workflow from configuration to dashboard sync


func exampleSplunkIntegrationWorkflow() async throws {
    
    print("🚀 Starting Splunk Integration Example")
    
    // MARK: - Step 1: Load Configuration from Plist
    
    print("\n📝 Step 1: Loading configuration from SplunkConfiguration.plist")
    // Load from main bundle (default behavior)
    let configTemplate = try SplunkConfiguration.loadFromPlist()
    
    // For testing or custom bundles, you can specify a different bundle:
    // let testBundle = Bundle(for: SomeTestClass.self)
    // let configTemplate = try SplunkConfiguration.loadFromPlist(bundle: testBundle)
    
    print("✅ Configuration loaded successfully")
    print("   Base URL: \(configTemplate.baseURL)")
    print("   Default App: \(configTemplate.defaultApp)")
    
    // MARK: - Step 2: Setup Credentials
    
    print("\n🔐 Step 2: Setting up authentication")
    
    // Option A: Using API Token (recommended)
    //let credentials = SplunkCredentials.token("your-api-token-here")
    
    // Option B: Using username/password
    // let credentials = SplunkCredentials.basic(username: "admin", password: "changeme")
    
    // Option C: Using stored credentials (secure)
    let credentialManager = SplunkCredentialManager()
    try credentialManager.storeToken(server: "splunk-server.com", token: "your-token")
    let token = try credentialManager.retrieveToken(server: "splunk-server.com")
    let credentials = SplunkCredentials.token(token)
    
    let configuration = configTemplate.withCredentials(credentials)
    print("✅ Credentials configured")
    
    // MARK: - Step 3: Test Connection and Authentication
    
    print("\n🔗 Step 3: Testing connection to Splunk")
    let restClient = SplunkRestClient(configuration: configuration)
    let authService = SplunkAuthenticationService(restClient: restClient)
    
    do {
        let isValid = try await authService.verifyCredentials()
        if isValid {
            print("✅ Connection successful")
            let user = try await authService.getCurrentUser()
            print("   Authenticated as: \(user.username)")
            print("   Roles: \(user.roles.joined(separator: ", "))")
        } else {
            print("❌ Authentication failed")
            return
        }
    } catch {
        print("❌ Connection failed: \(error.localizedDescription)")
        return
    }
    
    // MARK: - Step 4: List Available Applications
    
    print("\n📱 Step 4: Discovering available applications")
    let dashboardService = SplunkDashboardService(restClient: restClient)
    
    let apps = try await dashboardService.getAvailableApps()
    let visibleApps = apps.filter { $0.visible && !$0.disabled }
    
    print("✅ Found \(visibleApps.count) available applications:")
    for app in visibleApps.prefix(5) {  // Show first 5
        print("   📱 \(app.name) - \(app.label)")
    }
    
    // MARK: - Step 5: List Dashboards in Specific App
    
    print("\n📊 Step 5: Listing dashboards in default app")
    let defaultApp = configuration.defaultApp
    
    let dashboardList = try await dashboardService.listDashboards(
        app: defaultApp,
        count: 10  // Limit to first 10 for example
    )
    
    print("✅ Found \(dashboardList.entry.count) dashboards in '\(defaultApp)':")
    for dashboard in dashboardList.entry.prefix(3) {  // Show first 3
        print("   📊 \(dashboard.name)")
        print("      Author: \(dashboard.author)")
        print("      Updated: \(dashboard.updated)")
    }
    
    // MARK: - Step 6: Sync Dashboards to Core Data
    
    print("\n🔄 Step 6: Syncing dashboards to Core Data")
    let syncService = SplunkDashboardSyncService(
        dashboardService: dashboardService,
        configuration: configuration
    )
    
    // Create Core Data loader adapter
    let coreDataLoader =  await CoreDataLoaderAdapter()
    
    // Sync specific apps (or use default from config)
    let appsToSync = ["search", "SplunkEnterpriseSecuritySuite"]  // Example apps
    
    let syncResult = try await syncService.syncDashboards(
        fromApps: appsToSync,
        toCoreData: coreDataLoader
    )
    
    print("✅ Sync completed!")
    print(syncResult.summary)
    
    if !syncResult.errors.isEmpty {
        print("\n⚠️ Sync errors:")
        for error in syncResult.errors.prefix(3) {  // Show first 3 errors
            print("   • \(error)")
        }
    }
    
    // MARK: - Step 7: Query Synced Data
    
    print("\n🔍 Step 7: Querying synced dashboard data")
    let queryEngine = await DashboardQueryEngine()
    
    // This would use your existing Core Data querying functionality
    await queryEngine.showStatistics()
    
    print("\n🎉 Example workflow completed successfully!")
}

// MARK: - CLI Usage Examples

func showCLIUsageExamples() {
    print("""
    
    📖 CLI Usage Examples:
    
    1. Configure and test connection:
    splunk-dashboard splunk login --username admin --password changeme
    splunk-dashboard splunk config --show
    
    2. Browse available data:
    splunk-dashboard splunk apps
    splunk-dashboard splunk dashboards search
    
    3. Sync specific apps:
    splunk-dashboard splunk sync --apps "search,SplunkEnterpriseSecuritySuite" --verbose
    
    4. Sync all apps:
    splunk-dashboard splunk sync --all
    
    5. Use token authentication:
    splunk-dashboard splunk login --token your-api-token-here
    splunk-dashboard splunk sync --token your-api-token-here --apps search
    
    6. Load local XML files (existing functionality):
    splunk-dashboard load /path/to/dashboard.xml
    splunk-dashboard load /path/to/directory --recursive
    
    7. Query loaded data (existing functionality):
    splunk-dashboard query list
    splunk-dashboard query show dashboard_id
    splunk-dashboard query tokens
    splunk-dashboard query stats
    
    8. Custom configuration file:
    splunk-dashboard splunk sync --config /path/to/custom/config.plist
    
    """)
}

// MARK: - Configuration File Template

func showConfigurationTemplate() {
    print("""
    
    📝 SplunkConfiguration.plist Template:
    
    The configuration file should be included as a resource in your app bundle.
    Add SplunkConfiguration.plist to your Xcode project and ensure it's included
    in your app target's bundle resources.
    
    Key configuration sections:
    • baseURL: Your Splunk server URL
    • defaultApp/defaultOwner: Default context for operations
    • dashboardSyncSettings: Control sync behavior and limits
    • appFilters: Include/exclude apps based on patterns
    • coreDataMapping: Control how data is stored in Core Data
    • debugSettings: Logging and performance monitoring
    
    See SplunkConfiguration.plist for the complete template with all options.
    
    """)
}

// MARK: - Security Best Practices

func showSecurityBestPractices() {
    print("""
    
    🛡️ Security Best Practices:
    
    1. Never store credentials in the plist file
    2. Use API tokens instead of username/password when possible
    3. Store credentials securely using SplunkCredentialManager (Keychain)
    4. Enable SSL certificate validation in production
    5. Use specific user accounts with minimal required permissions
    6. Regularly rotate API tokens
    7. Monitor and log authentication attempts
    
    Example secure credential storage:
    
    ```swift
    let credManager = SplunkCredentialManager()
    try credManager.storeToken(server: "splunk.company.com", token: "your-token")
    
    // Later retrieve and use
    let token = try credManager.retrieveToken(server: "splunk.company.com")
    let credentials = SplunkCredentials.token(token)
    ```
    
    """)
}

// MARK: - Core Data Integration

func showCoreDataIntegration() {
    print("""
    
    💾 Core Data Integration:
    
    The sync process integrates with your existing Core Data model:
    
    1. Dashboard XML is downloaded from Splunk
    2. Temporary XML files are created
    3. Existing DashboardLoader processes the XML
    4. Token extraction and search parsing occurs
    5. Data is stored in your Core Data model
    6. Temporary files are cleaned up
    
    Configuration options (in plist):
    • batchInsertSize: Control Core Data batch operations
    • preserveSourceXML: Keep original XML in database
    • extractTokens: Parse and store dashboard tokens
    • parseSearches: Extract search queries for analysis
    
    The sync service respects your existing Core Data model and
    processing logic while adding Splunk connectivity.
    
    """)
}
