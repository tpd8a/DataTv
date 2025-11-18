//
//  SplTvApp.swift
//  SplTv
//
//  Created by Peter Moore on 08/11/2025.
//

import SwiftUI
import CoreData
import DashboardKit
import d8aTvCore  // Legacy entity support (DashboardEntity, SplunkCredentialManager)
import UniformTypeIdentifiers

#if os(macOS) || os(tvOS)

/// Dashboard Monitor App
/// Provides a GUI for monitoring and controlling dashboard refresh timers
@available(macOS 26, tvOS 26, *)
@main
struct SplTvApp: App {
    
    // MARK: - Core Data Context
    
    public let persistenceController = PersistenceController.shared
    
    
    // MARK: - Scene
    var body: some Scene {
        #if os(macOS)
        WindowGroup {
            DashboardMainView()
                .environment(\.managedObjectContext, persistenceController.context)
                .frame(minWidth: 800, minHeight: 600)
        }
        .commands {
            // Add custom menu commands
            CommandGroup(replacing: .newItem) { }
            
            // Refresh timer commands disabled until DashboardRefreshWorker migrated
            /*
            CommandGroup(after: .toolbar) {
                Button("Start All Timers") {
                    DashboardRefreshWorker.shared.startAllRefreshTimers()
                }
                .keyboardShortcut("r", modifiers: [.command])

                Button("Stop All Timers") {
                    DashboardRefreshWorker.shared.stopAllTimers()
                }
                .keyboardShortcut("s", modifiers: [.command])

                Divider()
            }
            */
        }
        
        Settings {
            SettingsView()
                .environment(\.managedObjectContext, persistenceController.context)
        }
        
        #elseif os(tvOS)
        WindowGroup {
            DashboardMainView()
                .environment(\.managedObjectContext, persistenceController.context)
        }
        #endif
    }
}

// MARK: - Settings View (macOS only)

#if os(macOS)
@available(macOS 26, *)
struct SettingsView: View {
    
    // MARK: - Refresh Timer Settings
    @AppStorage("autoStartTimers") private var autoStartTimers = false
    @AppStorage("showNotifications") private var showNotifications = true
    @AppStorage("logRefreshActivity") private var logRefreshActivity = true
    
    // MARK: - Splunk Connection Settings
    @AppStorage("splunkBaseURL") private var splunkBaseURL = "https://localhost:8089"
    @AppStorage("splunkUsername") private var splunkUsername = "admin"
    @AppStorage("splunkAuthType") private var splunkAuthType = "basic" // "basic" or "token"
    @AppStorage("splunkDefaultApp") private var splunkDefaultApp = "search"
    @AppStorage("splunkDefaultOwner") private var splunkDefaultOwner = "admin"
    
    // MARK: - Network Settings
    @AppStorage("splunkTimeout") private var splunkTimeout = 30.0
    @AppStorage("splunkMaxRetries") private var splunkMaxRetries = 3
    @AppStorage("splunkRetryDelay") private var splunkRetryDelay = 2.0
    
    // MARK: - SSL Settings
    @AppStorage("splunkAllowInsecure") private var splunkAllowInsecure = false
    @AppStorage("splunkValidateSSL") private var splunkValidateSSL = true
    
    // MARK: - Dashboard Sync Settings
    @AppStorage("syncBatchSize") private var syncBatchSize = 50
    @AppStorage("syncMaxDashboards") private var syncMaxDashboards = 1000
    @AppStorage("syncIncludePrivate") private var syncIncludePrivate = false
    @AppStorage("syncExcludeSystemApps") private var syncExcludeSystemApps = true
    
    // State for password and token (not persisted in AppStorage for security)
    @State private var splunkPassword = ""
    @State private var splunkToken = ""
    @State private var selectedTab = 0
    @State private var showingPasswordField = false
    @State private var showingTokenField = false
    
    // Connection test state
    @State private var isTestingConnection = false
    @State private var connectionTestResult: ConnectionTestResult?
    
    // Sync state
    @State private var isSyncing = false
    @State private var syncResult: SyncResult?
    @State private var dashboardCount: Int = 0
    @State private var lastSyncDate: Date?
    
    // CoreData state
    @State private var coreDataSize: String = "Calculating..."
    @State private var showingClearDataAlert = false
    
    // Dashboard export state
    @State private var showingDashboardExportSheet = false
    
    // Credential manager
    private let credentialManager = SplunkCredentialManager()
    
    // Core Data context
    @Environment(\.managedObjectContext) private var viewContext
    
    enum ConnectionTestResult {
        case success(message: String)
        case failure(message: String)
    }
    
    enum SyncResult {
        case success(message: String)
        case failure(message: String)
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // MARK: - Splunk Connection Tab
            Form {
                Section("Server Connection") {
                    LabeledContent("Base URL:") {
                        TextField("https://localhost:8089", text: $splunkBaseURL)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 300)
                    }
                    .help("Splunk server URL including port (e.g., https://splunk.example.com:8089)")
                }
                
                Section("Authentication") {
                    Picker("Authentication Type:", selection: $splunkAuthType) {
                        Text("Basic (Username/Password)").tag("basic")
                        Text("Bearer Token").tag("token")
                    }
                    .pickerStyle(.segmented)
                    .help("Choose authentication method")
                    
                    if splunkAuthType == "basic" {
                        LabeledContent("Username:") {
                            TextField("admin", text: $splunkUsername)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 200)
                        }
                        .help("Splunk username for authentication")
                        
                        LabeledContent("Password:") {
                            HStack {
                                if showingPasswordField {
                                    SecureField("Password", text: $splunkPassword)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 200)
                                } else {
                                    Text("Stored in Keychain")
                                        .foregroundStyle(.secondary)
                                }
                                
                                Button(showingPasswordField ? "Store" : "Update") {
                                    if showingPasswordField {
                                        storePasswordInKeychain()
                                        showingPasswordField = false
                                    } else {
                                        loadPasswordFromKeychain()
                                        showingPasswordField = true
                                    }
                                }
                            }
                        }
                        .help("Splunk password (stored securely in Keychain)")
                    } else {
                        LabeledContent("Bearer Token:") {
                            HStack {
                                if showingTokenField {
                                    SecureField("Token", text: $splunkToken)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 300)
                                } else {
                                    Text("Stored in Keychain")
                                        .foregroundStyle(.secondary)
                                }
                                
                                Button(showingTokenField ? "Store" : "Update") {
                                    if showingTokenField {
                                        storeTokenInKeychain()
                                        showingTokenField = false
                                    } else {
                                        loadTokenFromKeychain()
                                        showingTokenField = true
                                    }
                                }
                            }
                        }
                        .help("Splunk bearer token (stored securely in Keychain)")
                    }
                    
                    // Test Connection button moved here
                    HStack {
                        Spacer()
                        
                        Button("Test Connection") {
                            Task {
                                await testSplunkConnection()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isTestingConnection)
                        
                        if isTestingConnection {
                            ProgressView()
                                .scaleEffect(0.8)
                                .padding(.leading, 8)
                        }
                    }
                    
                    if let result = connectionTestResult {
                        switch result {
                        case .success(let message):
                            Label(message, systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        case .failure(let message):
                            Label(message, systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }
                
                Section("Default Settings") {
                    LabeledContent("Default App:") {
                        TextField("search", text: $splunkDefaultApp)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                    }
                    .help("Default Splunk app to use for dashboard searches")
                    
                    LabeledContent("Default Owner:") {
                        TextField("admin", text: $splunkDefaultOwner)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                    }
                    .help("Default owner for dashboard queries")
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("Connection", systemImage: "network")
            }
            .tag(0)
            
            // MARK: - Network & SSL Tab
            Form {
                Section("Network Settings") {
                    LabeledContent("Timeout:") {
                        HStack {
                            TextField("30", value: $splunkTimeout, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                            Text("seconds")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .help("Connection timeout in seconds")
                    
                    LabeledContent("Max Retries:") {
                        Stepper("\(splunkMaxRetries)", value: $splunkMaxRetries, in: 0...10)
                            .frame(width: 120)
                    }
                    .help("Maximum number of retry attempts for failed requests")
                    
                    LabeledContent("Retry Delay:") {
                        HStack {
                            TextField("2", value: $splunkRetryDelay, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                            Text("seconds")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .help("Delay between retry attempts")
                }
                
                Section("SSL/TLS Settings") {
                    Toggle("Validate SSL Certificates", isOn: $splunkValidateSSL)
                        .help("Verify SSL certificates when connecting to Splunk")
                    
                    Toggle("Allow Insecure Connections", isOn: $splunkAllowInsecure)
                        .help("Allow HTTP connections (not recommended for production)")
                }
                .foregroundStyle(splunkAllowInsecure || !splunkValidateSSL ? .orange : .primary)
                
                if splunkAllowInsecure || !splunkValidateSSL {
                    Section {
                        Label("Warning: Insecure settings enabled", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("Network & SSL", systemImage: "lock.shield")
            }
            .tag(1)
            
            // MARK: - Dashboard Sync Tab
            Form {
                Section("Sync Settings") {
                    LabeledContent("Batch Size:") {
                        Stepper("\(syncBatchSize)", value: $syncBatchSize, in: 10...200, step: 10)
                            .frame(width: 120)
                    }
                    .help("Number of dashboards to sync in each batch")
                    
                    LabeledContent("Max Dashboards:") {
                        Stepper("\(syncMaxDashboards)", value: $syncMaxDashboards, in: 100...10000, step: 100)
                            .frame(width: 120)
                    }
                    .help("Maximum total number of dashboards to sync")
                    
                    Toggle("Include Private Dashboards", isOn: $syncIncludePrivate)
                        .help("Include private/user dashboards in sync")
                    
                    Toggle("Exclude System Apps", isOn: $syncExcludeSystemApps)
                        .help("Exclude built-in Splunk system apps from sync")
                }
                
                Section("Statistics") {
                    LabeledContent("Dashboards Loaded:") {
                        Text("\(dashboardCount)")
                            .foregroundStyle(dashboardCount > 0 ? .primary : .secondary)
                    }
                    
                    LabeledContent("Last Sync:") {
                        if let lastSync = lastSyncDate {
                            Text(lastSync, style: .relative)
                        } else {
                            Text("Never")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section {
                    HStack {
                        Spacer()
                        
                        Button("Sync Now") {
                            Task {
                                await syncDashboards()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isSyncing)
                        
                        if isSyncing {
                            ProgressView()
                                .scaleEffect(0.8)
                                .padding(.leading, 8)
                        }
                    }
                    
                    if let result = syncResult {
                        switch result {
                        case .success(let message):
                            Label(message, systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        case .failure(let message):
                            Label(message, systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("Dashboard Sync", systemImage: "arrow.triangle.2.circlepath")
            }
            .tag(2)
            
            // MARK: - Refresh Timers Tab
            Form {
                Section("Automatic Refresh") {
                    Toggle("Auto-start timers on launch", isOn: $autoStartTimers)
                        .help("Automatically start refresh timers when the app launches")
                }
                
                Section("Notifications") {
                    Toggle("Show notifications for refresh errors", isOn: $showNotifications)
                        .help("Display notifications when a search refresh fails")
                }
                
                Section("Logging") {
                    Toggle("Log refresh activity", isOn: $logRefreshActivity)
                        .help("Write refresh activity to console logs")
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("Refresh Timers", systemImage: "timer")
            }
            .tag(3)
            
            // MARK: - Reset Tab
            Form {
                Section("Settings Reset") {
                    Button("Reset Connection Settings") {
                        resetConnectionSettings()
                    }
                    
                    Button("Reset Network Settings") {
                        resetNetworkSettings()
                    }
                    
                    Button("Reset Sync Settings") {
                        resetSyncSettings()
                    }
                    
                    Divider()
                    
                    Button("Reset All Settings") {
                        resetAllSettings()
                    }
                    .foregroundStyle(.red)
                }
                
                Section("Data Management") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("CoreData Database")
                                    .font(.headline)
                                Text(coreDataSize)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("Refresh Size") {
                                calculateCoreDataSize()
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        Divider()
                        
                        // Export Dashboard Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Export Dashboard")
                                .font(.headline)
                            
                            Button("Export Dashboard Details...") {
                                showDashboardExportPanel()
                            }
                            .buttonStyle(.bordered)
                            .help("Export dashboard configuration and searches to JSON file")
                        }
                        
                        Divider()
                        
                        Button("Clear All CoreData") {
                            showingClearDataAlert = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                    .padding(.vertical, 4)
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .tag(4)
            .alert("Clear All Data?", isPresented: $showingClearDataAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear Data", role: .destructive) {
                    clearAllCoreData()
                }
            } message: {
                Text("This will permanently delete all dashboards, searches, and results from the database. This action cannot be undone.")
            }
        }
        .frame(width: 600, height: 500)
        .padding()
        .onAppear {
            updateDashboardCount()
            calculateCoreDataSize()
        }
        .sheet(isPresented: $showingDashboardExportSheet) {
            DashboardExportView()
                .environment(\.managedObjectContext, viewContext)
        }
    }
    
    // MARK: - Helper Functions
    
    private func testSplunkConnection() async {
        isTestingConnection = true
        connectionTestResult = nil
        
        do {
            // Validate URL
            guard let baseURL = URL(string: splunkBaseURL) else {
                connectionTestResult = .failure(message: "Invalid URL format")
                isTestingConnection = false
                return
            }
            
            // Try to get credentials from keychain based on auth type
            let credentials: SplunkCredentials
            
            if splunkAuthType == "token" {
                // Token authentication
                do {
                    let serverHost = baseURL.host ?? "localhost"
                    let token = try credentialManager.retrieveToken(server: serverHost)
                    credentials = .token(token)
                } catch {
                    // If no token in keychain, use the token field if available
                    if !splunkToken.isEmpty {
                        credentials = .token(splunkToken)
                    } else {
                        connectionTestResult = .failure(message: "No token found. Please enter and store a token first.")
                        isTestingConnection = false
                        return
                    }
                }
            } else {
                // Basic authentication
                do {
                    let serverHost = baseURL.host ?? "localhost"
                    let password = try credentialManager.retrieveCredentials(server: serverHost, username: splunkUsername)
                    credentials = .basic(username: splunkUsername, password: password)
                } catch {
                    // If no credentials in keychain, use the password field if available
                    if !splunkPassword.isEmpty {
                        credentials = .basic(username: splunkUsername, password: splunkPassword)
                    } else {
                        connectionTestResult = .failure(message: "No password found. Please enter and store a password first.")
                        isTestingConnection = false
                        return
                    }
                }
            }
            
            // Create configuration
            let config = SplunkConfiguration(
                baseURL: baseURL,
                credentials: credentials,
                defaultApp: splunkDefaultApp,
                defaultOwner: splunkDefaultOwner,
                timeout: splunkTimeout,
                maxRetries: splunkMaxRetries,
                retryDelay: splunkRetryDelay,
                allowInsecureConnections: splunkAllowInsecure,
                validateSSLCertificate: splunkValidateSSL
            )
            
            // Create REST client and test connectivity
            let restClient = SplunkRestClient(configuration: config)
            
            do {
                try await restClient.testConnectivity()
                let authTypeDisplay = splunkAuthType == "token" ? "token" : "username/password"
                connectionTestResult = .success(message: "Successfully connected to \(baseURL.host ?? splunkBaseURL) using \(authTypeDisplay)")
            } catch {
                connectionTestResult = .failure(message: "Connection failed: \(error.localizedDescription)")
            }
            
        } catch {
            connectionTestResult = .failure(message: "Error: \(error.localizedDescription)")
        }
        
        isTestingConnection = false
    }
    
    private func storePasswordInKeychain() {
        guard !splunkPassword.isEmpty else {
            connectionTestResult = .failure(message: "Password cannot be empty")
            return
        }
        
        guard let baseURL = URL(string: splunkBaseURL),
              let serverHost = baseURL.host else {
            connectionTestResult = .failure(message: "Invalid base URL")
            return
        }
        
        do {
            try credentialManager.storeCredentials(
                server: serverHost,
                username: splunkUsername,
                password: splunkPassword
            )
            connectionTestResult = .success(message: "Password stored securely in Keychain")
            splunkPassword = "" // Clear the password field
        } catch {
            connectionTestResult = .failure(message: "Failed to store password: \(error.localizedDescription)")
        }
    }
    
    private func loadPasswordFromKeychain() {
        guard let baseURL = URL(string: splunkBaseURL),
              let serverHost = baseURL.host else {
            connectionTestResult = .failure(message: "Invalid base URL")
            return
        }
        
        do {
            splunkPassword = try credentialManager.retrieveCredentials(
                server: serverHost,
                username: splunkUsername
            )
            connectionTestResult = .success(message: "Password loaded from Keychain")
        } catch {
            splunkPassword = ""
            connectionTestResult = .failure(message: "No password found in Keychain for this server/username")
        }
    }
    
    private func storeTokenInKeychain() {
        guard !splunkToken.isEmpty else {
            connectionTestResult = .failure(message: "Token cannot be empty")
            return
        }
        
        guard let baseURL = URL(string: splunkBaseURL),
              let serverHost = baseURL.host else {
            connectionTestResult = .failure(message: "Invalid base URL")
            return
        }
        
        do {
            try credentialManager.storeToken(
                server: serverHost,
                token: splunkToken
            )
            connectionTestResult = .success(message: "Token stored securely in Keychain")
            splunkToken = "" // Clear the token field
        } catch {
            connectionTestResult = .failure(message: "Failed to store token: \(error.localizedDescription)")
        }
    }
    
    private func loadTokenFromKeychain() {
        guard let baseURL = URL(string: splunkBaseURL),
              let serverHost = baseURL.host else {
            connectionTestResult = .failure(message: "Invalid base URL")
            return
        }
        
        do {
            splunkToken = try credentialManager.retrieveToken(server: serverHost)
            connectionTestResult = .success(message: "Token loaded from Keychain")
        } catch {
            splunkToken = ""
            connectionTestResult = .failure(message: "No token found in Keychain for this server")
        }
    }
    
    private func syncDashboards() async {
        isSyncing = true
        syncResult = nil
        
        do {
            // Validate URL
            guard let baseURL = URL(string: splunkBaseURL) else {
                syncResult = .failure(message: "Invalid URL format")
                isSyncing = false
                return
            }
            
            // Try to get credentials from keychain based on auth type
            let credentials: SplunkCredentials
            
            if splunkAuthType == "token" {
                do {
                    let serverHost = baseURL.host ?? "localhost"
                    let token = try credentialManager.retrieveToken(server: serverHost)
                    credentials = .token(token)
                } catch {
                    syncResult = .failure(message: "No token found. Please store a token first.")
                    isSyncing = false
                    return
                }
            } else {
                do {
                    let serverHost = baseURL.host ?? "localhost"
                    let password = try credentialManager.retrieveCredentials(server: serverHost, username: splunkUsername)
                    credentials = .basic(username: splunkUsername, password: password)
                } catch {
                    syncResult = .failure(message: "No credentials found. Please store password first.")
                    isSyncing = false
                    return
                }
            }
            
            // Create configuration
            let config = SplunkConfiguration(
                baseURL: baseURL,
                credentials: credentials,
                defaultApp: splunkDefaultApp,
                defaultOwner: splunkDefaultOwner,
                timeout: splunkTimeout,
                maxRetries: splunkMaxRetries,
                retryDelay: splunkRetryDelay,
                allowInsecureConnections: splunkAllowInsecure,
                validateSSLCertificate: splunkValidateSSL
            )
            
            // Create REST client and dashboard service
            let restClient = SplunkRestClient(configuration: config)
            let dashboardService = SplunkDashboardService(restClient: restClient)
            
            // Fetch dashboards from Splunk
            do {
                let dashboardList = try await dashboardService.listDashboards(
                    owner: splunkDefaultOwner, app: splunkDefaultApp
                )
                
                var syncedCount = 0
                let maxToSync = min(dashboardList.entry.count, syncMaxDashboards)
                
                // Load each dashboard and store in Core Data
                for dashboard in dashboardList.entry.prefix(maxToSync) {
                    // Apply filters - check author instead of owner
                    if !syncIncludePrivate && dashboard.author != splunkDefaultOwner {
                        continue
                    }
                    
                    // The XML content is already in the dashboard's content.eaiData
                    let xmlContent = dashboard.content.eaiData
                    
                    // Parse and load into Core Data using DashboardLoader
                    let loader = DashboardLoader()
                    do {
                        try loader.loadDashboard(
                            xmlContent: xmlContent,
                            dashboardId: dashboard.name,
                            appName: splunkDefaultApp
                        )
                        syncedCount += 1
                    } catch {
                        print("⚠️ Failed to load dashboard '\(dashboard.name)': \(error.localizedDescription)")
                    }
                }
                
                // Update statistics
                await MainActor.run {
                    lastSyncDate = Date()
                    updateDashboardCount()
                }
                
                syncResult = .success(message: "Synced \(syncedCount) of \(maxToSync) dashboards from '\(splunkDefaultApp)' app")
            } catch {
                syncResult = .failure(message: "Sync failed: \(error.localizedDescription)")
            }
            
        }
        
        isSyncing = false
    }

    private func updateDashboardCount() {
        // Use new Dashboard entity from DashboardKit
        let fetchRequest: NSFetchRequest<Dashboard> = Dashboard.fetchRequest()
        do {
            dashboardCount = try viewContext.count(for: fetchRequest)
        } catch {
            print("Failed to fetch dashboard count: \(error)")
            dashboardCount = 0
        }
    }
    
    private func calculateCoreDataSize() {
        // Use persistenceController (which uses DashboardKit model)
        guard let storeURL = persistenceController.container.persistentStoreCoordinator.persistentStores.first?.url else {
            coreDataSize = "Unable to determine size"
            return
        }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: storeURL.path)
            if let fileSize = attributes[FileAttributeKey.size] as? UInt64 {
                let formatter = ByteCountFormatter()
                formatter.countStyle = .file
                coreDataSize = formatter.string(fromByteCount: Int64(fileSize))
            } else {
                coreDataSize = "Unknown size"
            }
        } catch {
            coreDataSize = "Error: \(error.localizedDescription)"
        }
    }
    
    private func clearAllCoreData() {
        let context = persistenceController.context

        // Delete all DashboardKit entities
        let entityNames = [
            "Dashboard",
            "DataSource",
            "SearchExecution",
            "SearchResult",
            "Visualization",
            "DashboardInput",
            "DashboardLayout",
            "LayoutItem",
            "DataSourceConfig"
        ]

        do {
            for entityName in entityNames {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                deleteRequest.resultType = .resultTypeObjectIDs

                let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
                if let objectIDArray = result?.result as? [NSManagedObjectID] {
                    let changes = [NSDeletedObjectsKey: objectIDArray]
                    NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
                }
            }

            try context.save()

            // Update UI
            updateDashboardCount()
            calculateCoreDataSize()

            // Show success message
            connectionTestResult = .success(message: "All data cleared successfully")
        } catch {
            print("❌ Failed to clear CoreData: \(error)")
            connectionTestResult = .failure(message: "Failed to clear data: \(error.localizedDescription)")
        }
    }
    
    private func showDashboardExportPanel() {
        showingDashboardExportSheet = true
    }
    
    private func isSystemApp(_ appName: String) -> Bool {
        let systemApps = ["splunk_httpinput", "launcher", "legacy", "sample_app", "search", "system"]
        return systemApps.contains(appName)
    }
    
    
    private func resetConnectionSettings() {
        splunkBaseURL = "https://localhost:8089"
        splunkUsername = "admin"
        splunkDefaultApp = "search"
        splunkDefaultOwner = "admin"
    }
    
    private func resetNetworkSettings() {
        splunkTimeout = 30.0
        splunkMaxRetries = 3
        splunkRetryDelay = 2.0
        splunkAllowInsecure = false
        splunkValidateSSL = true
    }
    
    private func resetSyncSettings() {
        syncBatchSize = 50
        syncMaxDashboards = 1000
        syncIncludePrivate = false
        syncExcludeSystemApps = true
    }
    
    private func resetAllSettings() {
        resetConnectionSettings()
        resetNetworkSettings()
        resetSyncSettings()
        autoStartTimers = false
        showNotifications = true
        logRefreshActivity = true
    }
}

// MARK: - SplunkCredentialManager Extension for Token Support

extension SplunkCredentialManager {
    /// Store a bearer token in the Keychain for a given server
    func storeToken(server: String, token: String) throws {
        let account = "token_\(server)" // Use a special prefix to distinguish from username/password
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "SplunkToken",
            kSecAttrAccount as String: account,
            kSecValueData as String: token.data(using: .utf8)!
        ]
        
        // Delete any existing token first
        SecItemDelete(query as CFDictionary)
        
        // Add the new token
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [
                NSLocalizedDescriptionKey: "Failed to store token in Keychain"
            ])
        }
    }
    
    /// Retrieve a bearer token from the Keychain for a given server
    func retrieveToken(server: String) throws -> String {
        let account = "token_\(server)"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "SplunkToken",
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [
                NSLocalizedDescriptionKey: "Failed to retrieve token from Keychain"
            ])
        }
        
        return token
    }
    
    /// Delete a bearer token from the Keychain for a given server
    func deleteToken(server: String) throws {
        let account = "token_\(server)"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "SplunkToken",
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [
                NSLocalizedDescriptionKey: "Failed to delete token from Keychain"
            ])
        }
    }
}

// MARK: - Dashboard Export View

struct DashboardExportView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    // Fetch all dashboards using new Dashboard entity from DashboardKit
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Dashboard.title, ascending: true)],
        animation: .default)
    private var allDashboards: FetchedResults<Dashboard>

    @State private var selectedDashboardId: UUID? = nil
    @State private var exportStatus: String = ""
    @State private var isExporting = false

    // Computed properties
    private var dashboardList: [Dashboard] {
        return Array(allDashboards)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Select a dashboard to export its configuration, data sources, and visualizations to a JSON file.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Label("Export Dashboard Details", systemImage: "square.and.arrow.up")
                }

                Section("Select Dashboard") {
                    if dashboardList.isEmpty {
                        Text("No dashboards found. Please sync dashboards first.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Dashboard:", selection: $selectedDashboardId) {
                            Text("Choose a dashboard...").tag(nil as UUID?)
                            ForEach(dashboardList, id: \.id) { dashboard in
                                VStack(alignment: .leading) {
                                    Text(dashboard.title ?? "Untitled Dashboard")
                                        .font(.body)
                                    if let description = dashboard.dashboardDescription, !description.isEmpty {
                                        Text(description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .tag(dashboard.id as UUID?)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedDashboardId) { oldValue, newValue in
                            exportStatus = ""
                        }
                    }
                }

                if selectedDashboardId != nil {
                    Section {
                        Button("Export Dashboard...") {
                            exportDashboard()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isExporting)
                        
                        if isExporting {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Exporting...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if !exportStatus.isEmpty {
                            Text(exportStatus)
                                .font(.caption)
                                .foregroundStyle(exportStatus.contains("Success") ? .green : .red)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Export Dashboard")
            .frame(width: 500, height: 400)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func exportDashboard() {
        guard let dashboardId = selectedDashboardId else {
            exportStatus = "Error: No dashboard selected"
            return
        }

        guard let dashboard = allDashboards.first(where: { $0.id == dashboardId }) else {
            exportStatus = "Error: Dashboard not found"
            return
        }

        isExporting = true
        exportStatus = "Preparing export..."

        // Create save panel
        let savePanel = NSSavePanel()
        savePanel.title = "Export Dashboard"
        savePanel.message = "Choose where to save the dashboard export"
        let dashboardName = dashboard.title?.replacingOccurrences(of: " ", with: "_") ?? "dashboard"
        savePanel.nameFieldStringValue = "\(dashboardName)_export.json"
        savePanel.allowedContentTypes = [.json]
        savePanel.canCreateDirectories = true
        savePanel.begin { [self] response in
            if response == .OK, let url = savePanel.url {
                Task {
                    do {
                        // Create export data structure
                        var exportData: [String: Any] = [
                            "id": dashboard.id?.uuidString ?? "unknown",
                            "title": dashboard.title ?? "Untitled",
                            "formatType": dashboard.formatType ?? "dashboardStudio",
                            "createdAt": dashboard.createdAt?.ISO8601Format() ?? "",
                            "updatedAt": dashboard.updatedAt?.ISO8601Format() ?? ""
                        ]

                        if let description = dashboard.dashboardDescription {
                            exportData["description"] = description
                        }

                        // Include raw JSON if available (contains full Studio configuration)
                        if let rawJSON = dashboard.rawJSON {
                            exportData["rawJSON"] = rawJSON
                        }

                        // Include data sources
                        if let dataSources = dashboard.dataSources?.allObjects as? [DataSource] {
                            let dsExport = dataSources.map { ds in
                                [
                                    "sourceId": ds.sourceId ?? "",
                                    "name": ds.name ?? "",
                                    "type": ds.type ?? "",
                                    "query": ds.query ?? ""
                                ]
                            }
                            exportData["dataSources"] = dsExport
                        }

                        // Convert to JSON
                        let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: [.prettyPrinted, .sortedKeys])
                        try jsonData.write(to: url)

                        await MainActor.run {
                            exportStatus = "Success: Dashboard exported to \(url.lastPathComponent)"
                            isExporting = false
                        }
                    } catch {
                        await MainActor.run {
                            exportStatus = "Error: \(error.localizedDescription)"
                            isExporting = false
                        }
                    }
                }
            } else {
                exportStatus = "Export cancelled"
                isExporting = false
            }
        }
    }
}
#endif

#endif
