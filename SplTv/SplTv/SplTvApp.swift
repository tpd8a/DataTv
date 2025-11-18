//
//  SplTvApp.swift
//  SplTv
//
//  Created by Peter Moore on 08/11/2025.
//

import SwiftUI
import CoreData
import DashboardKit
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
    
    // Credential manager (DashboardKit)
    
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

    /// Create a URLSession configured with SSL settings
    private func createURLSession() -> URLSession {
        if splunkAllowInsecure || !splunkValidateSSL {
            // Use a delegate that bypasses SSL validation
            let delegate = InsecureURLSessionDelegate()
            return URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        } else {
            return URLSession.shared
        }
    }

    private func testSplunkConnection() async {
        isTestingConnection = true
        connectionTestResult = nil

        do {
            // Validate URL
            guard let baseURL = URL(string: splunkBaseURL),
                  let host = baseURL.host else {
                connectionTestResult = .failure(message: "Invalid URL format")
                isTestingConnection = false
                return
            }

            let port = baseURL.port ?? 8089
            let useSSL = baseURL.scheme == "https"
            let scheme = useSSL ? "https" : "http"

            // Build URL for server info endpoint
            let testURL = URL(string: "\(scheme)://\(host):\(port)/services/server/info")!
            var urlComponents = URLComponents(url: testURL, resolvingAgainstBaseURL: true)!
            urlComponents.queryItems = [URLQueryItem(name: "output_mode", value: "json")]

            var request = URLRequest(url: urlComponents.url!)
            request.timeoutInterval = splunkTimeout

            // Add authentication
            if splunkAuthType == "token" {
                // Token authentication
                let authToken: String
                do {
                    authToken = try await CredentialManager.shared.retrieveAuthToken(host: host)
                } catch {
                    if !splunkToken.isEmpty {
                        authToken = splunkToken
                    } else {
                        connectionTestResult = .failure(message: "No token found. Please enter and store a token first.")
                        isTestingConnection = false
                        return
                    }
                }
                request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            } else {
                // Basic authentication
                let password: String
                do {
                    password = try await CredentialManager.shared.retrieveCredentials(host: host, username: splunkUsername)
                } catch {
                    if !splunkPassword.isEmpty {
                        password = splunkPassword
                    } else {
                        connectionTestResult = .failure(message: "No password found. Please enter and store a password first.")
                        isTestingConnection = false
                        return
                    }
                }

                let credentials = "\(splunkUsername):\(password)"
                if let credentialsData = credentials.data(using: .utf8) {
                    let base64Credentials = credentialsData.base64EncodedString()
                    request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
                }
            }

            // Use custom URLSession with SSL settings
            let urlSession = createURLSession()
            let (_, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                connectionTestResult = .failure(message: "Invalid response from server")
                isTestingConnection = false
                return
            }

            if (200...299).contains(httpResponse.statusCode) {
                let authTypeDisplay = splunkAuthType == "token" ? "token" : "username/password"
                connectionTestResult = .success(message: "Successfully connected to \(host):\(port) using \(authTypeDisplay)")
            } else if httpResponse.statusCode == 401 {
                connectionTestResult = .failure(message: "Authentication failed - check credentials")
            } else {
                connectionTestResult = .failure(message: "Connection failed - server returned status \(httpResponse.statusCode)")
            }
        } catch {
            connectionTestResult = .failure(message: "Connection failed: \(error.localizedDescription)")
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

        Task {
            do {
                try await CredentialManager.shared.storeCredentials(
                    host: serverHost,
                    username: splunkUsername,
                    password: splunkPassword
                )
                await MainActor.run {
                    connectionTestResult = .success(message: "Password stored securely in Keychain")
                    splunkPassword = "" // Clear the password field
                }
            } catch {
                await MainActor.run {
                    connectionTestResult = .failure(message: "Failed to store password: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func loadPasswordFromKeychain() {
        guard let baseURL = URL(string: splunkBaseURL),
              let serverHost = baseURL.host else {
            connectionTestResult = .failure(message: "Invalid base URL")
            return
        }

        Task {
            do {
                let password = try await CredentialManager.shared.retrieveCredentials(
                    host: serverHost,
                    username: splunkUsername
                )
                await MainActor.run {
                    splunkPassword = password
                    connectionTestResult = .success(message: "Password loaded from Keychain")
                }
            } catch {
                await MainActor.run {
                    splunkPassword = ""
                    connectionTestResult = .failure(message: "No password found in Keychain for this server/username")
                }
            }
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

        Task {
            do {
                try await CredentialManager.shared.storeAuthToken(
                    host: serverHost,
                    token: splunkToken
                )
                await MainActor.run {
                    connectionTestResult = .success(message: "Token stored securely in Keychain")
                    splunkToken = "" // Clear the token field
                }
            } catch {
                await MainActor.run {
                    connectionTestResult = .failure(message: "Failed to store token: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func loadTokenFromKeychain() {
        guard let baseURL = URL(string: splunkBaseURL),
              let serverHost = baseURL.host else {
            connectionTestResult = .failure(message: "Invalid base URL")
            return
        }

        Task {
            do {
                let token = try await CredentialManager.shared.retrieveAuthToken(host: serverHost)
                await MainActor.run {
                    splunkToken = token
                    connectionTestResult = .success(message: "Token loaded from Keychain")
                }
            } catch {
                await MainActor.run {
                    splunkToken = ""
                    connectionTestResult = .failure(message: "No token found in Keychain for this server")
                }
            }
        }
    }
    
    private func syncDashboards() async {
        isSyncing = true
        syncResult = nil

        do {
            // Validate URL
            guard let baseURL = URL(string: splunkBaseURL),
                  let host = baseURL.host else {
                syncResult = .failure(message: "Invalid URL format")
                isSyncing = false
                return
            }

            // Build REST API URL for dashboard listing
            let port = baseURL.port ?? 8089
            let useSSL = baseURL.scheme == "https"
            let scheme = useSSL ? "https" : "http"

            // Use Splunk REST API to list views (dashboards)
            let restURL = URL(string: "\(scheme)://\(host):\(port)/servicesNS/-/\(splunkDefaultApp)/data/ui/views")!
            var urlComponents = URLComponents(url: restURL, resolvingAgainstBaseURL: true)!
            urlComponents.queryItems = [
                URLQueryItem(name: "output_mode", value: "json"),
                URLQueryItem(name: "count", value: String(min(syncMaxDashboards, 1000)))
            ]

            var request = URLRequest(url: urlComponents.url!)
            request.timeoutInterval = splunkTimeout

            // Add authentication
            if splunkAuthType == "token" {
                // Token authentication
                let authToken: String
                do {
                    authToken = try await CredentialManager.shared.retrieveAuthToken(host: host)
                } catch {
                    syncResult = .failure(message: "No token found. Please store a token first.")
                    isSyncing = false
                    return
                }
                request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            } else {
                // Basic authentication
                let password: String
                do {
                    password = try await CredentialManager.shared.retrieveCredentials(host: host, username: splunkUsername)
                } catch {
                    syncResult = .failure(message: "No password found. Please store password first.")
                    isSyncing = false
                    return
                }

                let credentials = "\(splunkUsername):\(password)"
                if let credentialsData = credentials.data(using: .utf8) {
                    let base64Credentials = credentialsData.base64EncodedString()
                    request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
                }
            }

            // Use custom URLSession with SSL settings
            let urlSession = createURLSession()
            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                syncResult = .failure(message: "Failed to fetch dashboards from Splunk")
                isSyncing = false
                return
            }

            // Parse the dashboard list response
            let dashboardList = try JSONDecoder().decode(SplunkViewsResponse.self, from: data)

            var syncedCount = 0
            let maxToSync = min(dashboardList.entry.count, syncMaxDashboards)

            // Process each dashboard
            for entry in dashboardList.entry.prefix(maxToSync) {
                // Apply filters
                if !syncIncludePrivate && entry.author != splunkDefaultOwner {
                    continue
                }

                // Get the dashboard XML/JSON content
                guard let dashboardXML = entry.content.eaiData else {
                    continue
                }

                // Determine dashboard format
                let formatType: String
                if let rootNode = entry.content.rootNode {
                    formatType = rootNode == "dashboard" || rootNode == "form" ? "simpleXML" : "dashboardStudio"
                } else {
                    formatType = "simpleXML"
                }

                // Save to CoreData using CoreDataManager
                do {
                    let manager = await CoreDataManager.shared

                    if formatType == "dashboardStudio" {
                        // Parse as Dashboard Studio JSON
                        let parser = await DashboardStudioParser()
                        let studioConfig = try await parser.parse(dashboardXML)
                        _ = try await manager.saveDashboard(studioConfig)
                        syncedCount += 1
                    } else {
                        // Parse as Simple XML
                        let parser = SimpleXMLParser()
                        let simpleXMLConfig = try parser.parse(dashboardXML)
                        _ = try await manager.saveDashboard(simpleXMLConfig)
                        syncedCount += 1
                    }
                } catch {
                    print("⚠️ Failed to save dashboard '\(entry.name)': \(error.localizedDescription)")
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
        // Use PersistenceController.shared (which uses DashboardKit model)
        guard let storeURL = PersistenceController.shared.container.persistentStoreCoordinator.persistentStores.first?.url else {
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
        let context = PersistenceController.shared.context

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

        // Extract all data from Core Data BEFORE async operations
        // Core Data objects are not thread-safe and must be accessed from their context
        let exportId = dashboard.id?.uuidString ?? "unknown"
        let exportTitle = dashboard.title ?? "Untitled"
        let exportFormatType = dashboard.formatType ?? "dashboardStudio"
        let exportCreatedAt = dashboard.createdAt?.ISO8601Format() ?? ""
        let exportUpdatedAt = dashboard.updatedAt?.ISO8601Format() ?? ""
        let exportDescription = dashboard.dashboardDescription
        let exportRawJSON = dashboard.rawJSON

        // Extract data sources
        let exportDataSources: [[String: String]]? = {
            if let dataSources = dashboard.dataSources?.allObjects as? [DataSource] {
                return dataSources.map { ds in
                    [
                        "sourceId": ds.sourceId ?? "",
                        "name": ds.name ?? "",
                        "type": ds.type ?? "",
                        "query": ds.query ?? ""
                    ]
                }
            }
            return nil
        }()

        // Create save panel
        let savePanel = NSSavePanel()
        savePanel.title = "Export Dashboard"
        savePanel.message = "Choose where to save the dashboard export"
        let dashboardName = exportTitle.replacingOccurrences(of: " ", with: "_")
        savePanel.nameFieldStringValue = "\(dashboardName)_export.json"
        savePanel.allowedContentTypes = [.json]
        savePanel.canCreateDirectories = true
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                Task { @MainActor in
                    do {
                        // Create export data structure using pre-extracted data
                        var exportData: [String: Any] = [
                            "id": exportId,
                            "title": exportTitle,
                            "formatType": exportFormatType,
                            "createdAt": exportCreatedAt,
                            "updatedAt": exportUpdatedAt
                        ]

                        if let description = exportDescription {
                            exportData["description"] = description
                        }

                        if let rawJSON = exportRawJSON {
                            exportData["rawJSON"] = rawJSON
                        }

                        if let dataSources = exportDataSources {
                            exportData["dataSources"] = dataSources
                        }

                        // Convert to JSON
                        let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: [.prettyPrinted, .sortedKeys])
                        try jsonData.write(to: url)

                        self.exportStatus = "Success: Dashboard exported to \(url.lastPathComponent)"
                        self.isExporting = false
                    } catch {
                        self.exportStatus = "Error: \(error.localizedDescription)"
                        self.isExporting = false
                    }
                }
            } else {
                self.exportStatus = "Export cancelled"
                self.isExporting = false
            }
        }
    }
}

// MARK: - Splunk REST API Response Models

/// Response from Splunk /data/ui/views endpoint
private struct SplunkViewsResponse: Codable {
    let entry: [SplunkViewEntry]
}

private struct SplunkViewEntry: Codable {
    let name: String
    let author: String
    let content: SplunkViewContent
}

private struct SplunkViewContent: Codable {
    let eaiData: String?
    let rootNode: String?

    enum CodingKeys: String, CodingKey {
        case eaiData = "eai:data"
        case rootNode
    }
}

// MARK: - Insecure URLSession Delegate

/// URLSession delegate that bypasses SSL certificate validation
/// Used when user has enabled "Allow Insecure Connections" or disabled "Validate SSL Certificates"
private class InsecureURLSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Bypass SSL certificate validation
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            let credential = URLCredential(trust: trust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

#endif

#endif
