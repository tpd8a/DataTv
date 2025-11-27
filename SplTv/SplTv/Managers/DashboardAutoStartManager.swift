import Foundation
import SwiftUI
import DashboardKit

/// Manages automatic search execution based on fieldset configuration
/// Implements Splunk dashboard fieldset behavior for autoRun and submitButton
@MainActor
public class DashboardAutoStartManager: ObservableObject {

    // MARK: - Singleton

    public static let shared = DashboardAutoStartManager()

    // MARK: - Published Properties

    @Published private(set) var isEvaluating: Bool = false
    @Published private(set) var lastAutoStartDashboard: UUID?

    // MARK: - Private Properties

    private var fieldsetConfigCache: [UUID: FieldsetConfig] = [:]
    private var initializedDashboards: Set<UUID> = []
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        setupTokenChangeObserver()
    }

    // MARK: - Public Methods

    /// Evaluate and execute auto-start logic for a dashboard
    /// Called when a dashboard is loaded or tokens are initialized
    public func evaluateAutoStart(for dashboard: Dashboard) async {
        guard let dashboardId = dashboard.id else {
            print("⚠️ AutoStart: Dashboard has no ID")
            return
        }

        // Skip if already initialized (prevents duplicate runs)
        guard !initializedDashboards.contains(dashboardId) else {
            print("⏸️ AutoStart: Dashboard '\(dashboard.title ?? "Untitled")' already initialized, skipping")
            return
        }

        isEvaluating = true
        defer { isEvaluating = false }

        print("🚀 AutoStart: Evaluating dashboard '\(dashboard.title ?? "Untitled")' (first time)")

        // Get fieldset configuration
        guard let config = getFieldsetConfig(for: dashboard) else {
            print("⚠️ AutoStart: Could not extract fieldset config")
            return
        }

        print("📋 AutoStart: submitButton=\(config.submitButton), autoRun=\(config.autoRun)")

        // Mark as initialized BEFORE starting (prevents race conditions if called multiple times)
        initializedDashboards.insert(dashboardId)

        // Determine if we should auto-execute on load
        let shouldExecute = shouldAutoExecuteOnLoad(config: config)

        if shouldExecute {
            print("✅ AutoStart: Executing all searches on dashboard load")
            await executeAllSearches(for: dashboard)
            lastAutoStartDashboard = dashboardId

            // Post notification to trigger UI refresh
            NotificationCenter.default.post(
                name: .autoStartCompleted,
                object: nil,
                userInfo: ["dashboardId": dashboardId.uuidString]
            )
        } else {
            print("⏸️ AutoStart: Waiting for manual trigger (autoRun=false)")
        }
    }

    /// Reset initialization state for a dashboard (useful after data sync or manual refresh)
    public func resetInitialization(for dashboardId: UUID) {
        initializedDashboards.remove(dashboardId)
        fieldsetConfigCache.removeValue(forKey: dashboardId)
        print("🔄 AutoStart: Reset initialization state for dashboard \(dashboardId)")
    }

    /// Clear all initialization state (useful for debugging or full data reset)
    public func clearAllInitializedDashboards() {
        let count = initializedDashboards.count
        initializedDashboards.removeAll()
        fieldsetConfigCache.removeAll()
        print("🔄 AutoStart: Cleared initialization state for \(count) dashboard(s)")
    }

    /// Handle token value changes and trigger searches if needed
    public func handleTokenChange(tokenName: String, in dashboard: Dashboard) async {
        guard let dashboardId = dashboard.id else { return }

        print("🔄 AutoStart: Token '\(tokenName)' changed in dashboard '\(dashboard.title ?? "Untitled")'")

        // Get fieldset configuration
        guard let config = getFieldsetConfig(for: dashboard) else {
            print("⚠️ AutoStart: Could not extract fieldset config for token change")
            return
        }

        // Check if the changed input should trigger searches
        guard let inputs = dashboard.inputs?.allObjects as? [DashboardInput],
              let changedInput = inputs.first(where: { $0.token == tokenName }) else {
            print("⚠️ AutoStart: Could not find input for token '\(tokenName)'")
            return
        }

        let shouldExecute = shouldAutoExecuteOnTokenChange(
            config: config,
            input: changedInput
        )

        if shouldExecute {
            print("✅ AutoStart: Executing searches due to token change")
            await executeAllSearches(for: dashboard)
        } else {
            print("⏸️ AutoStart: Token change doesn't trigger auto-execution")
        }
    }

    // MARK: - Private Methods - Configuration

    /// Extract fieldset configuration from dashboard
    private func getFieldsetConfig(for dashboard: Dashboard) -> FieldsetConfig? {
        // Check cache first
        if let dashboardId = dashboard.id,
           let cached = fieldsetConfigCache[dashboardId] {
            return cached
        }

        // Parse from rawXML
        guard let rawXML = dashboard.rawXML else {
            print("⚠️ AutoStart: Dashboard has no rawXML")
            return nil
        }

        let config = parseFieldsetConfig(from: rawXML)

        // Cache the result
        if let dashboardId = dashboard.id {
            fieldsetConfigCache[dashboardId] = config
        }

        return config
    }

    /// Parse fieldset configuration from XML
    private func parseFieldsetConfig(from xml: String) -> FieldsetConfig {
        // Default values per Splunk spec
        var submitButton = true  // Default to true
        var autoRun = false       // Default to false

        // Simple XML parsing to extract fieldset attributes
        // Look for <fieldset submitButton="..." autoRun="...">
        if let fieldsetRange = xml.range(of: #"<fieldset[^>]*>"#, options: .regularExpression) {
            let fieldsetTag = String(xml[fieldsetRange])

            // Extract submitButton attribute
            if let submitMatch = fieldsetTag.range(of: #"submitButton\s*=\s*"([^"]*)"#, options: .regularExpression) {
                let submitValue = String(fieldsetTag[submitMatch])
                    .replacingOccurrences(of: #"submitButton\s*=\s*""#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: "\"", with: "")
                submitButton = submitValue.lowercased() != "false"
            }

            // Extract autoRun attribute
            if let autoRunMatch = fieldsetTag.range(of: #"autoRun\s*=\s*"([^"]*)"#, options: .regularExpression) {
                let autoRunValue = String(fieldsetTag[autoRunMatch])
                    .replacingOccurrences(of: #"autoRun\s*=\s*""#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: "\"", with: "")
                autoRun = autoRunValue.lowercased() == "true"
            }
        }

        return FieldsetConfig(submitButton: submitButton, autoRun: autoRun)
    }

    // MARK: - Private Methods - Logic Rules

    /// Determine if searches should auto-execute on dashboard load
    private func shouldAutoExecuteOnLoad(config: FieldsetConfig) -> Bool {
        // Rule 1: If submitButton is false, autoRun is ignored and behaves as true
        if !config.submitButton {
            print("📌 AutoStart: submitButton=false → forcing auto-execution")
            return true
        }

        // Rule 2: Otherwise, respect autoRun attribute
        print("📌 AutoStart: submitButton=true → following autoRun=\(config.autoRun)")
        return config.autoRun
    }

    /// Determine if searches should auto-execute on token change
    private func shouldAutoExecuteOnTokenChange(config: FieldsetConfig, input: DashboardInput) -> Bool {
        // Rule 1: If submitButton is false, searchWhenChanged is ignored and behaves as true
        if !config.submitButton {
            print("📌 AutoStart: submitButton=false → forcing search on token change")
            return true
        }

        // Rule 2: Otherwise, check input's searchWhenChanged attribute
        let searchWhenChanged = getSearchWhenChanged(for: input)
        print("📌 AutoStart: submitButton=true → following searchWhenChanged=\(searchWhenChanged)")
        return searchWhenChanged
    }

    /// Extract searchWhenChanged from input's optionsJSON
    private func getSearchWhenChanged(for input: DashboardInput) -> Bool {
        // Default is false per Splunk spec
        guard let optionsJSON = input.optionsJSON,
              let data = optionsJSON.data(using: .utf8),
              let options = try? JSONDecoder().decode([String: AnyCodable].self, from: data),
              let searchWhenChanged = options["searchWhenChanged"]?.value as? Bool else {
            return false
        }
        return searchWhenChanged
    }

    // MARK: - Private Methods - Search Execution

    /// Execute all searches for a dashboard
    private func executeAllSearches(for dashboard: Dashboard) async {
        guard let dashboardId = dashboard.id else {
            print("❌ AutoStart: Dashboard has no ID")
            return
        }

        // Get all DataSources for this dashboard
        guard let dataSources = dashboard.dataSources?.allObjects as? [DataSource] else {
            print("⚠️ AutoStart: No data sources found")
            return
        }

        // Get current token values from TokenManager
        let tokenValues = DashboardTokenManager.shared.getAllValues()

        print("🔍 AutoStart: Executing \(dataSources.count) searches with \(tokenValues.count) tokens")

        // Separate input searches from regular searches
        let inputSearches = dataSources.filter { $0.sourceId?.hasPrefix("input_search_") == true }
        let regularSearches = dataSources.filter { $0.sourceId?.hasPrefix("input_search_") == false }

        // Execute input searches first (they populate dropdown choices)
        if !inputSearches.isEmpty {
            print("📥 AutoStart: Executing \(inputSearches.count) input searches first")
            for dataSource in inputSearches {
                await executeSingleSearch(dataSource, dashboardId: dashboardId, tokenValues: tokenValues, isInputSearch: true)
            }
        }

        // Execute regular searches
        if !regularSearches.isEmpty {
            print("📊 AutoStart: Executing \(regularSearches.count) regular searches")
            for dataSource in regularSearches {
                await executeSingleSearch(dataSource, dashboardId: dashboardId, tokenValues: tokenValues, isInputSearch: false)
            }
        }
    }

    /// Execute a single search
    private func executeSingleSearch(_ dataSource: DataSource, dashboardId: UUID, tokenValues: [String: String], isInputSearch: Bool) async {
        guard let searchId = dataSource.sourceId else { return }

        let prefix = isInputSearch ? "🎯" : "▶️"
        let type = isInputSearch ? "input search" : "search"

        do {
            print("\(prefix) AutoStart: Starting \(type) '\(searchId)'")

            let executionId = try await CoreDataManager.shared.startSearchExecution(
                searchId: searchId,
                in: dashboardId,
                userTokenValues: tokenValues,
                timeRange: nil,
                parameterOverrides: [:],
                credentials: nil
            )

            print("✅ AutoStart: Started execution \(executionId) for \(type) '\(searchId)'")

        } catch {
            print("❌ AutoStart: Failed to start \(type) '\(searchId)': \(error)")
        }
    }

    // MARK: - Private Methods - Token Change Observer

    /// Setup observer for token value changes
    private func setupTokenChangeObserver() {
        NotificationCenter.default.publisher(for: .tokenValueChanged)
            .sink { [weak self] notification in
                Task { @MainActor in
                    guard let self = self else { return }

                    // Extract token name and dashboard ID from notification
                    guard let userInfo = notification.userInfo,
                          let tokenName = userInfo["tokenName"] as? String,
                          let dashboardIdString = userInfo["dashboardId"] as? String,
                          let dashboardId = UUID(uuidString: dashboardIdString) else {
                        return
                    }

                    // Find the dashboard
                    // Note: This requires access to the managed object context
                    // For now, we'll skip auto-execution on token change until we have proper context access
                    print("🔔 AutoStart: Token '\(tokenName)' changed (dashboard ID: \(dashboardId))")
                    print("⚠️ AutoStart: Token change auto-execution not yet implemented")
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Helper Types

    /// Fieldset configuration extracted from dashboard XML
    private struct FieldsetConfig {
        let submitButton: Bool
        let autoRun: Bool
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when auto-start completes executing searches
    static let autoStartCompleted = Notification.Name("autoStartCompleted")
}

// MARK: - Imports

import Combine
