import Foundation
import CoreData
import CryptoKit
import DashboardKit

/// Splunk SimpleXML dashboard loader for Core Data
@MainActor
public class DashboardLoader {
    
    private let coreDataManager: CoreDataManager
    private let context: NSManagedObjectContext
    
    public init(coreDataManager: CoreDataManager = CoreDataManager.shared) {
        self.coreDataManager = coreDataManager
        self.context = coreDataManager.context
    }
    
    // MARK: - Public Interface
    
    /// Load a SimpleXML dashboard from file path
    public func loadDashboard(from filePath: String, dashboardId: String? = nil, appName: String? = nil) throws {
        let xmlContent = try String(contentsOfFile: filePath, encoding: .utf8)
        let finalId = dashboardId ?? URL(fileURLWithPath: filePath).deletingPathExtension().lastPathComponent
        try loadDashboard(xmlContent: xmlContent, dashboardId: finalId, appName: appName)
    }
    
    /// Load a SimpleXML dashboard from XML content string
    /// Now uses the new Dashboard Studio format (data source-centric)
    public func loadDashboard(xmlContent: String, dashboardId: String, appName: String? = nil) throws {
        // Use the new Studio format loader
        try loadDashboardAsStudio(xmlContent: xmlContent, dashboardId: dashboardId, appName: appName)
    }
    
    // MARK: - Dashboard Parsing
    
    private func parseDashboardAttributes(from root: SimpleXMLElement, into dashboard: DashboardEntity) throws {
        dashboard.title = root.element(named: "label")?.value ?? root.attribute("title")
        dashboard.dashboardDescription = root.element(named: "description")?.value
        dashboard.version = root.attribute("version")
        dashboard.theme = root.attribute("theme")
        dashboard.stylesheet = root.attribute("stylesheet") 
        dashboard.script = root.attribute("script")
        
        // Parse boolean attributes
        dashboard.hideEdit = root.attribute("hideEdit") == "true"
        dashboard.hideExport = root.attribute("hideExport") == "true"
        
        // Parse refresh settings
        if let refreshStr = root.attribute("refresh"),
           let refreshInt = Int32(refreshStr) {
            dashboard.refreshInterval = refreshInt
        }
        dashboard.refreshType = root.attribute("refreshType")
        
        // Parse global time settings
        dashboard.globalEarliestTime = root.attribute("earliestTime")
        dashboard.globalLatestTime = root.attribute("latestTime")
    }
    
    private func parseForm(from root: SimpleXMLElement, into dashboard: DashboardEntity) throws {
        // Look for fieldset elements directly under the root (whether it's <form> or <dashboard>)
        let fieldsetElements = root.elements(named: "fieldset")
        
        // Parse fieldsets
        for (index, fieldsetElement) in fieldsetElements.enumerated() {
            let fieldset = FieldsetEntity(context: context)
            fieldset.id = fieldsetElement.attribute("id") ?? "fieldset_\(index)"
            fieldset.submitButton = fieldsetElement.attribute("submitButton") != "false"
            fieldset.autoRun = fieldsetElement.attribute("autoRun") == "true"
            fieldset.depends = fieldsetElement.attribute("depends")
            fieldset.rejects = fieldsetElement.attribute("rejects")
            fieldset.dashboard = dashboard
            
            // Store raw attributes
            fieldset.rawAttributes = try encodeAttributes(fieldsetElement.attributes)
            
            // Parse tokens within fieldset
            try parseTokens(from: fieldsetElement, into: fieldset, panel: nil)
        }
    }
    
    private func parseTokens(from parent: SimpleXMLElement, into fieldset: FieldsetEntity?, panel: PanelEntity?) throws {
        let inputElements = parent.children.filter { element in
            ["input", "text", "dropdown", "time", "radio", "checkbox", "multiselect", "link"].contains(element.name)
        }
        
        for inputElement in inputElements {
            guard let tokenName = inputElement.attribute("token") else { continue }
            
            let token = TokenEntity(context: context)
            token.name = tokenName
            token.type = inputElement.name
            token.label = inputElement.element(named: "label")?.value
            token.defaultValue = inputElement.element(named: "default")?.value
            token.depends = inputElement.attribute("depends")
            token.rejects = inputElement.attribute("rejects")
            token.prefix = inputElement.element(named: "prefix")?.value
            token.suffix = inputElement.element(named: "suffix")?.value
            token.delimiter = inputElement.attribute("delimiter")
            token.searchWhenChanged = inputElement.attribute("searchWhenChanged") == "true"
            token.submitOnChange = inputElement.attribute("submitOnChange") == "true"
            token.selectFirstChoice = inputElement.attribute("selectFirstChoice") == "true"
            token.required = inputElement.attribute("required") == "true"
            token.validation = inputElement.attribute("validation")
            token.initialValue = inputElement.element(named: "initialValue")?.value
            
            // Parse time-specific attributes
            token.earliestTime = inputElement.element(named: "earliest")?.value
            token.latestTime = inputElement.element(named: "latest")?.value
            
            // Parse populating search
            if let searchElement = inputElement.element(named: "search") ?? inputElement.element(named: "populatingSearch") {
                token.populatingSearch = searchElement.value ?? searchElement.attribute("query")
                token.populatingFieldForValue = inputElement.attribute("valueField") ?? searchElement.attribute("valueField")
                token.populatingFieldForLabel = inputElement.attribute("labelField") ?? searchElement.attribute("labelField")
            }
            
            // Store raw attributes and content
            token.rawAttributes = try encodeAttributes(inputElement.attributes)
            token.rawContent = inputElement.value
            
            // Set relationships
            token.fieldset = fieldset
            token.panel = panel
            
            // Parse choices
            try parseTokenChoices(from: inputElement, into: token)
            
            // Parse conditions and actions
            try parseTokenConditions(from: inputElement, into: token)
        }
    }
    
    private func parseTokenChoices(from inputElement: SimpleXMLElement, into token: TokenEntity) throws {
        for choiceElement in inputElement.elements(named: "choice") {
            guard let value = choiceElement.attribute("value") else { continue }
            
            let choice = TokenChoiceEntity(context: context)
            choice.value = value
            choice.label = choiceElement.value ?? value
            choice.isDefault = choiceElement.attribute("default") == "true"
            choice.disabled = choiceElement.attribute("disabled") == "true"
            choice.depends = choiceElement.attribute("depends")
            choice.rejects = choiceElement.attribute("rejects")
            choice.rawAttributes = try encodeAttributes(choiceElement.attributes)
            choice.token = token
        }
    }
    
    private func parseTokenConditions(from inputElement: SimpleXMLElement, into token: TokenEntity) throws {
        for (index, conditionElement) in inputElement.elements(named: "condition").enumerated() {
            let condition = TokenConditionEntity(context: context)
            condition.id = conditionElement.attribute("id") ?? "condition_\(index)_\(token.name)"
            condition.match = conditionElement.attribute("match")
            condition.label = conditionElement.attribute("label")
            condition.value = conditionElement.attribute("value")
            condition.rawAttributes = try encodeAttributes(conditionElement.attributes)
            condition.token = token
            
            // Parse actions within condition
            for (actionIndex, actionElement) in conditionElement.children.enumerated() {
                if ["set", "unset", "eval"].contains(actionElement.name) {
                    let action = TokenActionEntity(context: context)
                    action.id = "action_\(actionIndex)_\(condition.id)"
                    action.action = actionElement.name
                    action.targetToken = actionElement.attribute("token") ?? ""
                    action.value = actionElement.attribute("value")
                    action.expression = actionElement.value
                    action.rawAttributes = try encodeAttributes(actionElement.attributes)
                    action.condition = condition
                }
            }
        }
    }
    
    private func parseRows(from root: SimpleXMLElement, into dashboard: DashboardEntity) throws {
        for (rowIndex, rowElement) in root.elements(named: "row").enumerated() {
            let row = RowEntity(context: context)
            row.id = rowElement.attribute("id") ?? "row_\(rowIndex)"
            row.xmlId = rowElement.attribute("id")
            row.orderIndex = Int32(rowIndex)
            row.depends = rowElement.attribute("depends")
            row.rejects = rowElement.attribute("rejects")
            row.grouping = rowElement.attribute("grouping")
            row.rawAttributes = try encodeAttributes(rowElement.attributes)
            row.dashboard = dashboard
            
            // Parse panels within row
            try parsePanels(from: rowElement, into: row)
        }
        
        // Handle dashboard without explicit rows (direct panels)
        let directPanels = root.children.filter { ["panel", "single", "table", "chart", "viz", "map", "html"].contains($0.name) }
        if !directPanels.isEmpty {
            let defaultRow = RowEntity(context: context)
            defaultRow.id = "default_row"
            defaultRow.orderIndex = 0
            defaultRow.dashboard = dashboard
            
            for (panelIndex, panelElement) in directPanels.enumerated() {
                try parsePanel(from: panelElement, into: defaultRow, index: panelIndex)
            }
        }
    }
    
    private func parsePanels(from rowElement: SimpleXMLElement, into row: RowEntity) throws {
        let panelElements = rowElement.children.filter { ["panel", "single", "table", "chart", "viz", "map", "html"].contains($0.name) }
        
        for (index, panelElement) in panelElements.enumerated() {
            try parsePanel(from: panelElement, into: row, index: index)
        }
    }
    
    private func parsePanel(from panelElement: SimpleXMLElement, into row: RowEntity, index: Int) throws {
        let panel = PanelEntity(context: context)
        panel.id = panelElement.attribute("id") ?? "panel_\(row.orderIndex)_\(index)"
        panel.xmlId = panelElement.attribute("id")
        panel.title = panelElement.element(named: "title")?.value
        panel.orderIndex = Int32(index)
        panel.depends = panelElement.attribute("depends")
        panel.rejects = panelElement.attribute("rejects")
        panel.ref = panelElement.attribute("ref")
        panel.width = panelElement.attribute("width")
        panel.height = panelElement.attribute("height")
        panel.rawAttributes = try encodeAttributes(panelElement.attributes)
        panel.row = row
        
        // Parse searches within panel
        try parseSearches(from: panelElement, into: panel)
        
        // Parse visualizations
        try parseVisualizations(from: panelElement, into: panel)
        
        // Parse panel-specific inputs
        try parseTokens(from: panelElement, into: nil, panel: panel)
    }
    
    private func parseSearches(from parent: SimpleXMLElement, into panel: PanelEntity) throws {
        for (index, searchElement) in parent.elements(named: "search").enumerated() {
            let search = SearchEntity(context: context)
            search.id = searchElement.attribute("id") ?? "search_\(panel.id)_\(index)"
            search.xmlId = searchElement.attribute("id")
            search.ref = searchElement.attribute("ref")
            search.base = searchElement.attribute("base")
            search.query = searchElement.element(named: "query")?.value ?? searchElement.value
            search.earliestTime = searchElement.element(named: "earliest")?.value
            search.latestTime = searchElement.element(named: "latest")?.value
            search.sampleRatio = searchElement.attribute("sampleRatio")
            search.refresh = searchElement.element(named: "refresh")?.value
            search.refreshType = searchElement.attribute("refreshType")
            search.refreshDisplay = searchElement.attribute("refreshDisplay")
            search.autostart = searchElement.attribute("autostart") != "false"
            search.depends = searchElement.attribute("depends")
            search.rejects = searchElement.attribute("rejects")
            search.rawAttributes = try encodeAttributes(searchElement.attributes)
            search.panel = panel
            
            // Extract and store token references
            if let query = search.query {
                let tokenRefs = TokenValidator.extractTokenReferences(from: query)
                search.tokenReferences = try JSONSerialization.data(withJSONObject: Array(tokenRefs))
            }
        }
    }
    
    private func parseVisualizations(from panelElement: SimpleXMLElement, into panel: PanelEntity) throws {
        let vizElements = panelElement.children.filter { 
            ["viz", "single", "table", "chart", "map", "html"].contains($0.name) 
        }
        
        for (index, vizElement) in vizElements.enumerated() {
            let viz = VisualizationEntity(context: context)
            viz.id = "\(panel.id)_viz_\(index)"
            viz.type = vizElement.name
            viz.title = vizElement.element(named: "title")?.value
            viz.depends = vizElement.attribute("depends")
            viz.rejects = vizElement.attribute("rejects")
            viz.drilldown = vizElement.element(named: "drilldown")?.value ?? vizElement.attribute("drilldown")
            viz.rawAttributes = try encodeAttributes(vizElement.attributes)
            viz.rawContent = vizElement.value
            viz.panel = panel
            
            // Parse visualization-specific properties
            // Extract ALL options including those in format elements
            let allOptionsData = vizElement.extractAllOptions()
            try viz.setOptions(allOptionsData)
            
            // Also populate legacy fields from options
            if let options = allOptionsData["options"] as? [String: String] {
                viz.chartType = options["charting.chart"] ?? options["type"]
                viz.stackMode = options["charting.chart.stackMode"]
                viz.legend = options["charting.legend.placement"]
                viz.drilldown = options["drilldown"] ?? viz.drilldown
                viz.showDataLabels = options["charting.chart.showDataLabels"] == "true"
                viz.showLegend = options["charting.legend.show"] == "true"
                viz.showTooltip = options["charting.tooltip.show"] == "true"
            }
            
            // Parse searches nested within visualizations
            for (searchIndex, searchElement) in vizElement.elements(named: "search").enumerated() {
                // For simplicity, only handle the first search per visualization 
                // since the Core Data model has a one-to-one relationship
                if searchIndex == 0 {
                    let search = SearchEntity(context: context)
                    search.id = searchElement.attribute("id") ?? "search_\(panel.id)_viz_\(index)"
                    search.xmlId = searchElement.attribute("id")
                    search.ref = searchElement.attribute("ref")
                    search.base = searchElement.attribute("base")
                    search.query = searchElement.element(named: "query")?.value ?? searchElement.value
                    search.earliestTime = searchElement.element(named: "earliest")?.value
                    search.latestTime = searchElement.element(named: "latest")?.value
                    search.sampleRatio = searchElement.attribute("sampleRatio")
                    search.refresh = searchElement.element(named: "refresh")?.value
                    search.refreshType = searchElement.attribute("refreshType")
                    search.refreshDisplay = searchElement.attribute("refreshDisplay")
                    search.autostart = searchElement.attribute("autostart") != "false"
                    search.depends = searchElement.attribute("depends")
                    search.rejects = searchElement.attribute("rejects")
                    search.rawAttributes = try encodeAttributes(searchElement.attributes)
                    search.visualization = viz
                    search.panel = panel
                    
                    // Extract and store token references
                    if let query = search.query {
                        let tokenRefs = TokenValidator.extractTokenReferences(from: query)
                        search.tokenReferences = try JSONSerialization.data(withJSONObject: Array(tokenRefs))
                    }
                }
            }
        }
    }
    
    private func parseGlobalSearches(from root: SimpleXMLElement, into dashboard: DashboardEntity) throws {
        // Parse searches that are direct children of dashboard/form
        for (index, searchElement) in root.elements(named: "search").enumerated() {
            let search = SearchEntity(context: context)
            search.id = searchElement.attribute("id") ?? "global_search_\(index)"
            search.xmlId = searchElement.attribute("id")
            search.ref = searchElement.attribute("ref")
            search.base = searchElement.attribute("base")
            search.query = searchElement.element(named: "query")?.value ?? searchElement.value
            search.earliestTime = searchElement.element(named: "earliest")?.value
            search.latestTime = searchElement.element(named: "latest")?.value
            search.sampleRatio = searchElement.attribute("sampleRatio")
            search.refresh = searchElement.element(named: "refresh")?.value
            search.refreshType = searchElement.attribute("refreshType")
            search.refreshDisplay = searchElement.attribute("refreshDisplay")
            search.autostart = searchElement.attribute("autostart") != "false"
            search.rawAttributes = try encodeAttributes(searchElement.attributes)
            search.dashboard = dashboard
            
            // Extract token references
            if let query = search.query {
                let tokenRefs = TokenValidator.extractTokenReferences(from: query)
                search.tokenReferences = try JSONSerialization.data(withJSONObject: Array(tokenRefs))
            }
        }
    }
    
    private func parseCustomContent(from root: SimpleXMLElement, into dashboard: DashboardEntity) throws {
        let customElements = root.children.filter { 
            !["label", "description", "form", "row", "panel", "search", "init"].contains($0.name) 
        }
        
        for (index, element) in customElements.enumerated() {
            let customContent = CustomContentEntity(context: context)
            customContent.id = "custom_\(index)_\(element.name)"
            customContent.contentType = element.name
            customContent.content = element.value ?? ""
            customContent.depends = element.attribute("depends")
            customContent.rejects = element.attribute("rejects")
            customContent.rawAttributes = try encodeAttributes(element.attributes)
            customContent.dashboard = dashboard
            
            // Extract token references from content
            let tokenRefs = TokenValidator.extractTokenReferences(from: customContent.content)
            if !tokenRefs.isEmpty {
                customContent.tokenReferences = try JSONSerialization.data(withJSONObject: Array(tokenRefs))
            }
        }
    }
    
    private func parseGlobalTokenOps(from root: SimpleXMLElement, into dashboard: DashboardEntity) throws {
        for initElement in root.elements(named: "init") {
            for (index, opElement) in initElement.children.enumerated() {
                if ["set", "unset", "eval"].contains(opElement.name) {
                    let tokenOp = GlobalTokenOpEntity(context: context)
                    tokenOp.id = "global_op_\(index)_\(opElement.name)"
                    tokenOp.operation = opElement.name
                    tokenOp.targetToken = opElement.attribute("token") ?? ""
                    tokenOp.value = opElement.attribute("value") ?? opElement.value
                    tokenOp.expression = opElement.value
                    tokenOp.depends = opElement.attribute("depends")
                    tokenOp.rawAttributes = try encodeAttributes(opElement.attributes)
                    tokenOp.dashboard = dashboard
                }
            }
        }
    }
    
    private func parseNamespaces(from root: SimpleXMLElement, into dashboard: DashboardEntity) throws {
        // Extract namespace declarations from root attributes
        for (key, value) in root.attributes {
            if key.hasPrefix("xmlns:") {
                let prefix = String(key.dropFirst(6)) // Remove "xmlns:" prefix
                
                let namespace = NamespaceEntity(context: context)
                namespace.prefix = prefix
                namespace.uri = value
                namespace.dashboard = dashboard
            }
        }
    }
    
    // MARK: - Utility Methods
    
    /// Create a unique composite ID that safely separates app name and dashboard ID
    /// Uses Unicode section symbol (§) which is extremely rare in Splunk app/dashboard names
    private func createCompositeId(appName: String?, dashboardId: String) -> String {
        guard let appName = appName, !appName.isEmpty else {
            return dashboardId
        }
        return "\(appName)§\(dashboardId)"
    }
    
    /// Extract app name and dashboard ID from composite ID
    /// Returns tuple of (appName, dashboardId) or (nil, originalId) if not a composite ID
    public static func extractFromCompositeId(_ compositeId: String) -> (appName: String?, dashboardId: String) {
        let parts = compositeId.components(separatedBy: "§")
        if parts.count == 2 {
            return (appName: parts[0], dashboardId: parts[1])
        } else {
            return (appName: nil, dashboardId: compositeId)
        }
    }
    
    private func encodeAttributes(_ attributes: [String: String]) throws -> Data {
        return try JSONSerialization.data(withJSONObject: attributes)
    }
    
    // MARK: - Debug Methods
    
    /// Print comprehensive debug information about a dashboard
    public func debugDashboard(_ dashboardId: String) {
        guard let dashboard = coreDataManager.findDashboard(by: dashboardId) else {
            print("❌ Dashboard '\(dashboardId)' not found")
            return
        }
        
        print("🔍 COMPLETE DASHBOARD DEBUG: \(dashboardId)")
        print("═" * 80)
        
        // Basic dashboard info
        print("📊 DASHBOARD ENTITY:")
        print("   ID: \(dashboard.id)")
        print("   App Name: \(dashboard.appName ?? "nil")")
        print("   Dashboard Name: \(dashboard.dashboardName ?? "nil")")
        print("   Title: \(dashboard.title ?? "nil")")
        print("   Description: \(dashboard.dashboardDescription ?? "nil")")
        print("   Version: \(dashboard.version ?? "nil")")
        print("   Theme: \(dashboard.theme ?? "nil")")
        print("   XML Hash: \(dashboard.xmlHash ?? "nil")")
        print("   Last Parsed: \(dashboard.lastParsed)")
        print("   Created At: \(dashboard.createdAt)")
        print("   Hide Edit: \(dashboard.hideEdit)")
        print("   Hide Export: \(dashboard.hideExport)")
        print("   Refresh Interval: \(dashboard.refreshInterval)")
        print("   Refresh Type: \(dashboard.refreshType ?? "nil")")
        print()
        
        // Raw XML content (truncated)
        print("📄 XML CONTENT (first 500 chars):")
        if let xmlContent = dashboard.xmlContent {
            let truncated = xmlContent.count > 500 ? String(xmlContent.prefix(500)) + "..." : xmlContent
            print("   \(truncated)")
        } else {
            print("   nil")
        }
        print()
        
        // Rows and Panels
        print("📐 ROWS (\(dashboard.rowsArray.count)):")
        for row in dashboard.rowsArray {
            print("   🔹 Row: \(row.id)")
            print("      XML ID: \(row.xmlId ?? "nil")")
            print("      Order Index: \(row.orderIndex)")
            print("      Depends: \(row.depends ?? "nil")")
            print("      Rejects: \(row.rejects ?? "nil")")
            print("      Grouping: \(row.grouping ?? "nil")")
            
            print("      📊 PANELS (\(row.panelsArray.count)):")
            for panel in row.panelsArray {
                print("         🔸 Panel: \(panel.id)")
                print("            XML ID: \(panel.xmlId ?? "nil")")
                print("            Title: \(panel.title ?? "nil")")
                print("            Order Index: \(panel.orderIndex)")
                print("            Ref: \(panel.ref ?? "nil")")
                print("            Width: \(panel.width ?? "nil")")
                print("            Height: \(panel.height ?? "nil")")
                
                // Panel Searches
                print("            🔍 PANEL SEARCHES (\(panel.searchesArray.count)):")
                for search in panel.searchesArray {
                    print("               • Search: \(search.id)")
                    print("                 Query: \(search.query ?? "nil")")
                    print("                 Ref: \(search.ref ?? "nil")")
                    print("                 Refresh: \(search.refresh ?? "nil")")
                    print("                 Autostart: \(search.autostart)")
                    print("                 Token Refs: \(search.tokenReferencesArray)")
                }
                
                // Panel Visualizations
                print("            🎨 VISUALIZATIONS (\(panel.visualizationsArray.count)):")
                for viz in panel.visualizationsArray {
                    print("               • Viz: \(viz.id)")
                    print("                 Type: \(viz.type)")
                    print("                 Title: \(viz.title ?? "nil")")
                    print("                 Chart Type: \(viz.chartType ?? "nil")")
                    print("                 Drilldown: \(viz.drilldown ?? "nil")")
                    
                    // Visualization Search
                    if let vizSearch = viz.search {
                        print("                 🔍 VIZ SEARCH:")
                        print("                    ID: \(vizSearch.id)")
                        print("                    Query: \(vizSearch.query ?? "nil")")
                        print("                    Refresh: \(vizSearch.refresh ?? "nil")")
                        print("                    Token Refs: \(vizSearch.tokenReferencesArray)")
                    } else {
                        print("                 🔍 VIZ SEARCH: none")
                    }
                }
                
                // Panel Tokens
                print("            🏷️ PANEL TOKENS (\(panel.inputsArray.count)):")
                for token in panel.inputsArray {
                    print("               • Token: \(token.name)")
                    print("                 Type: \(token.type)")
                    print("                 Default: \(token.defaultValue ?? "nil")")
                }
            }
            print()
        }
        
        // Fieldsets and Tokens
        print("📝 FIELDSETS (\(dashboard.fieldsetsArray.count)):")
        for fieldset in dashboard.fieldsetsArray {
            print("   🔹 Fieldset: \(fieldset.id)")
            print("      Submit Button: \(fieldset.submitButton)")
            print("      Auto Run: \(fieldset.autoRun)")
            print("      Depends: \(fieldset.depends ?? "nil")")
            
            print("      🏷️ TOKENS (\(fieldset.tokensArray.count)):")
            for token in fieldset.tokensArray {
                print("         • Token: \(token.name)")
                print("           Type: \(token.type)")
                print("           Label: \(token.label ?? "nil")")
                print("           Default: \(token.defaultValue ?? "nil")")
                print("           Required: \(token.required)")
                print("           Search When Changed: \(token.searchWhenChanged)")
                print("           Populating Search: \(token.populatingSearch ?? "nil")")
                
                print("           CHOICES (\(token.choicesArray.count)):")
                for choice in token.choicesArray {
                    print("              - \(choice.value): \(choice.label) (default: \(choice.isDefault))")
                }
                
                print("           CONDITIONS (\(token.conditionsArray.count)):")
                for condition in token.conditionsArray {
                    print("              * Condition: \(condition.id)")
                    print("                Match: \(condition.match ?? "nil")")
                    print("                Actions: \(condition.actionsArray.count)")
                }
            }
        }
        print()
        
        // Global Searches
        print("🔍 GLOBAL SEARCHES (\(dashboard.globalSearchesArray.count)):")
        for search in dashboard.globalSearchesArray {
            print("   • Search: \(search.id)")
            print("     Query: \(search.query ?? "nil")")
            print("     Ref: \(search.ref ?? "nil")")
            print("     Refresh: \(search.refresh ?? "nil")")
            print("     Autostart: \(search.autostart)")
            print("     Token Refs: \(search.tokenReferencesArray)")
        }
        print()
        
        // Custom Content
        print("🎨 CUSTOM CONTENT (\(dashboard.customContentArray.count)):")
        for content in dashboard.customContentArray {
            print("   • Content: \(content.id)")
            print("     Type: \(content.contentType)")
            print("     Content: \(String(content.content.prefix(100)))\(content.content.count > 100 ? "..." : "")")
        }
        print()
        
        // Global Token Operations
        print("⚙️ GLOBAL TOKEN OPS (\(dashboard.globalTokenOpsArray.count)):")
        for tokenOp in dashboard.globalTokenOpsArray {
            print("   • Op: \(tokenOp.id)")
            print("     Operation: \(tokenOp.operation)")
            print("     Target Token: \(tokenOp.targetToken)")
            print("     Value: \(tokenOp.value ?? "nil")")
        }
        print()
        
        // Namespace Declarations
        print("🌐 NAMESPACES (\(dashboard.namespacesArray.count)):")
        for namespace in dashboard.namespacesArray {
            print("   • \(namespace.prefix): \(namespace.uri)")
        }
        print()
        
        // Summary
        let allTokens = dashboard.allTokens
        let allSearches = dashboard.allSearches
        print("📋 SUMMARY:")
        print("   Total Rows: \(dashboard.rowsArray.count)")
        print("   Total Panels: \(dashboard.rowsArray.reduce(0) { $0 + $1.panelsArray.count })")
        print("   Total Visualizations: \(dashboard.rowsArray.flatMap { $0.panelsArray }.reduce(0) { $0 + $1.visualizationsArray.count })")
        print("   Total Tokens: \(allTokens.count)")
        print("   Total Searches: \(allSearches.count)")
        print("   Total Fieldsets: \(dashboard.fieldsetsArray.count)")
        print("   Total Custom Content: \(dashboard.customContentArray.count)")
        
        print("═" * 80)
    }
    
    /// Export complete CoreData object graph for a dashboard as JSON
    public func exportDashboardAsJSON(_ dashboardId: String) {
        // First try to find the new Dashboard (Studio format)
        let fetchRequest: NSFetchRequest<Dashboard> = Dashboard.fetchRequest()

        // Try multiple matching strategies:
        // 1. Exact match on dashboardId (for composite IDs like "search§my_another")
        // 2. ENDSWITH match (for when user passes just "my_another")
        // 3. Exact match on title
        fetchRequest.predicate = NSPredicate(
            format: "dashboardId == %@ OR dashboardId ENDSWITH %@ OR title == %@",
            dashboardId,
            "§" + dashboardId,
            dashboardId
        )

        do {
            let dashboards = try context.fetch(fetchRequest)
            if let dashboard = dashboards.first {
                // Found Studio format dashboard
                print("📊 Exporting Dashboard (Studio Format)")
                print("   Dashboard ID: \(dashboard.dashboardId ?? "N/A")")
                print("   Title: \(dashboard.title ?? "N/A")")
                print("")

                // For Studio format, output the clean rawJSON instead of CoreData object graph
                if let rawJSON = dashboard.rawJSON {
                    // Pretty print the JSON
                    if let jsonData = rawJSON.data(using: .utf8),
                       let jsonObject = try? JSONSerialization.jsonObject(with: jsonData),
                       let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys]),
                       let prettyString = String(data: prettyData, encoding: .utf8) {
                        print(prettyString)
                    } else {
                        print(rawJSON)
                    }
                } else {
                    print("⚠️ No rawJSON found for Studio dashboard, falling back to CoreData graph")
                    let jsonData = try serializeCoreDataObjectToJSON(dashboard)
                    if let jsonString = String(data: jsonData, encoding: .utf8) {
                        print(jsonString)
                    } else {
                        print("❌ Failed to convert JSON data to string")
                    }
                }
                return
            }
        } catch {
            print("⚠️ Error searching for Studio format dashboard: \(error)")
        }

        // Fall back to old DashboardEntity format
        guard let oldDashboard = coreDataManager.findDashboard(by: dashboardId) else {
            print("❌ Dashboard '\(dashboardId)' not found in either format")
            return
        }

        print("📊 Exporting DashboardEntity (Legacy Format)")
        do {
            let jsonData = try serializeCoreDataObjectToJSON(oldDashboard)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            } else {
                print("❌ Failed to convert JSON data to string")
            }
        } catch {
            print("❌ Failed to serialize dashboard to JSON: \(error)")
        }
    }
    
    /// Recursively serialize any CoreData NSManagedObject to JSON
    private func serializeCoreDataObjectToJSON(_ object: NSManagedObject) throws -> Data {
        let dictionary = try serializeObjectToDictionary(object, visited: NSMutableSet())
        return try JSONSerialization.data(withJSONObject: dictionary, options: [.prettyPrinted, .sortedKeys])
    }
    
    /// Convert NSManagedObject to dictionary recursively with cycle detection
    private func serializeObjectToDictionary(_ object: NSManagedObject, visited: NSMutableSet) throws -> [String: Any] {
        // Prevent infinite recursion on circular references
        let objectID = object.objectID
        if visited.contains(objectID) {
            return [
                "_objectID": objectID.uriRepresentation().absoluteString,
                "_entityName": object.entity.name ?? "Unknown",
                "_note": "Circular reference - see above"
            ]
        }
        visited.add(objectID)
        
        var result: [String: Any] = [:]
        let entity = object.entity
        
        // Add metadata
        result["_entityName"] = entity.name
        result["_objectID"] = objectID.uriRepresentation().absoluteString
        
        // Process all attributes
        for attribute in entity.attributesByName {
            let attributeName = attribute.key
            let value = object.value(forKey: attributeName)
            
            if let value = value {
                result[attributeName] = serializeAttributeValue(value)
            } else {
                result[attributeName] = nil
            }
        }
        
        // Process all relationships
        for relationship in entity.relationshipsByName {
            let relationshipName = relationship.key
            let relationshipDescription = relationship.value
            let value = object.value(forKey: relationshipName)
            
            if let value = value {
                if relationshipDescription.isToMany {
                    // Handle to-many relationships (NSSet)
                    if let set = value as? NSSet {
                        var arrayResult: [[String: Any]] = []
                        for relatedObject in set {
                            if let managedObject = relatedObject as? NSManagedObject {
                                try arrayResult.append(serializeObjectToDictionary(managedObject, visited: visited))
                            }
                        }
                        result[relationshipName] = arrayResult
                    }
                } else {
                    // Handle to-one relationships
                    if let managedObject = value as? NSManagedObject {
                        result[relationshipName] = try serializeObjectToDictionary(managedObject, visited: visited)
                    }
                }
            } else {
                result[relationshipName] = nil
            }
        }
        
        return result
    }
    
    /// Convert various CoreData attribute types to JSON-serializable values
    private func serializeAttributeValue(_ value: Any) -> Any {
        switch value {
        case let data as Data:
            // Try to deserialize JSON data back to objects for readability
            if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) {
                return jsonObject
            } else {
                // If not JSON, return as base64 string
                return [
                    "_dataType": "Data",
                    "_base64": data.base64EncodedString(),
                    "_size": data.count
                ]
            }
        case let date as Date:
            return [
                "_dataType": "Date",
                "_iso8601": ISO8601DateFormatter().string(from: date),
                "_timestamp": date.timeIntervalSince1970
            ]
        case let url as URL:
            return [
                "_dataType": "URL",
                "_absoluteString": url.absoluteString
            ]
        case let uuid as UUID:
            return [
                "_dataType": "UUID",
                "_uuidString": uuid.uuidString
            ]
        default:
            // For basic types (String, Int, Bool, Double, etc.)
            return value
        }
    }

    // MARK: - Studio Format Loading

    /// Load dashboard using the new Dashboard Studio format (data source-centric)
    public func loadDashboardAsStudio(xmlContent: String, dashboardId: String, appName: String? = nil) throws {
        print("🔄 Loading dashboard '\(dashboardId)' as Studio format...")

        // Parse XML to generic element tree for version checking
        let genericParser = GenericXMLParser()
        let root = try genericParser.parse(xmlString: xmlContent)

        // Validate it's a dashboard
        guard root.name == "dashboard" || root.name == "form" else {
            throw DashboardLoadingError.notADashboard(rootElement: root.name)
        }

        // Check if this is a native Dashboard Studio format (version 2.x)
        let studioConfig: DashboardStudioConfiguration
        if let version = root.attribute("version"), version == "2" {
            // Native Dashboard Studio format - extract JSON from <definition> CDATA
            print("📊 Detected native Dashboard Studio format (version 2.x)")
            studioConfig = try parseNativeStudioFormat(root: root)
        } else {
            // SimpleXML format - convert to Studio format
            print("📄 Detected SimpleXML format - converting to Studio format")
            // Use DashboardKit's SimpleXMLParser which properly extracts format elements
            let dashboardParser = SimpleXMLParser()
            let simpleXMLConfig = try dashboardParser.parse(xmlContent)
            let converter = DashboardConverter()
            studioConfig = converter.convertToStudio(simpleXMLConfig)
        }

        // Generate hash for change detection
        let xmlHash = SHA256.hash(data: xmlContent.data(using: .utf8) ?? Data())
        let hashString = xmlHash.compactMap { String(format: "%02x", $0) }.joined()

        // Create unique composite ID
        let compositeId = createCompositeId(appName: appName, dashboardId: dashboardId)

        // Check if dashboard exists
        let fetchRequest: NSFetchRequest<Dashboard> = Dashboard.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "dashboardId == %@", compositeId)

        let existingDashboards = try context.fetch(fetchRequest)
        if let existingDashboard = existingDashboards.first {
            // Check if changed (compare hash from rawXML)
            // For now, just delete and recreate
            print("🔄 Dashboard exists, updating...")
            context.delete(existingDashboard)
        }

        // Create new Dashboard entity (Studio format)
        try saveDashboardStudioConfig(studioConfig, dashboardId: compositeId, appName: appName, xmlContent: xmlContent, xmlHash: hashString)

        // Save to Core Data
        coreDataManager.saveContext()

        print("✅ Dashboard '\(dashboardId)' loaded in Studio format successfully")
    }

    /// Save DashboardStudioConfiguration to CoreData
    private func saveDashboardStudioConfig(
        _ config: DashboardStudioConfiguration,
        dashboardId: String,
        appName: String?,
        xmlContent: String,
        xmlHash: String
    ) throws {
        // Create Dashboard entity
        let dashboard = Dashboard(context: context)
        dashboard.id = UUID()
        dashboard.dashboardId = dashboardId  // Store composite ID for lookups
        dashboard.title = config.title
        dashboard.dashboardDescription = config.description
        dashboard.formatType = "studio"
        dashboard.rawXML = xmlContent
        dashboard.createdAt = Date()
        dashboard.updatedAt = Date()

        // Serialize studio config to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let jsonData = try? encoder.encode(config),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            dashboard.rawJSON = jsonString
        }

        // Create DataSource entities
        var dataSourceMap: [String: DataSource] = [:]
        for (dsId, dsDefinition) in config.dataSources {
            let dataSource = DataSource(context: context)
            dataSource.id = UUID()
            dataSource.sourceId = dsId
            dataSource.name = dsDefinition.name
            dataSource.type = dsDefinition.type
            dataSource.query = dsDefinition.options?.query
            dataSource.refresh = dsDefinition.options?.refresh
            dataSource.refreshType = dsDefinition.options?.refreshType
            dataSource.extendsId = dsDefinition.options?.extend ?? dsDefinition.extends
            dataSource.dashboard = dashboard

            // Serialize options to JSON
            if let options = dsDefinition.options,
               let optionsData = try? encoder.encode(options),
               let optionsString = String(data: optionsData, encoding: .utf8) {
                dataSource.optionsJSON = optionsString
            }

            dataSourceMap[dsId] = dataSource
            dashboard.addToDataSources(dataSource)
        }

        // Create Visualization entities
        for (vizId, vizDefinition) in config.visualizations {
            let visualization = Visualization(context: context)
            visualization.id = UUID()
            visualization.vizId = vizId
            visualization.type = vizDefinition.type
            visualization.title = vizDefinition.title
            visualization.encoding = vizDefinition.encoding
            visualization.dashboard = dashboard

            // Link to data source
            if let primaryDS = vizDefinition.dataSources?.primary,
               let dataSource = dataSourceMap[primaryDS] {
                visualization.dataSource = dataSource
                dataSource.addToVisualizations(visualization)
            }

            // Serialize options to JSON
            if let options = vizDefinition.options,
               let optionsData = try? encoder.encode(options),
               let optionsString = String(data: optionsData, encoding: .utf8) {
                visualization.optionsJSON = optionsString
            }

            // Serialize context to JSON
            if let context = vizDefinition.context,
               let contextData = try? encoder.encode(context),
               let contextString = String(data: contextData, encoding: .utf8) {
                visualization.contextJSON = contextString
            }

            dashboard.addToVisualizations(visualization)
        }

        // Create DashboardInput entities
        if let inputs = config.inputs {
            for (inputId, inputDef) in inputs {
                let input = DashboardInput(context: context)
                input.id = UUID()
                input.inputId = inputId
                input.type = inputDef.type
                input.title = inputDef.title

                // Extract token - check both top-level and options.token
                if let token = inputDef.token {
                    input.token = token
                } else if let options = inputDef.options,
                          let tokenValue = options["token"]?.value as? String {
                    input.token = tokenValue
                }

                // Extract defaultValue - check both top-level and options.defaultValue
                if let defaultValue = inputDef.defaultValue {
                    input.defaultValue = defaultValue
                } else if let options = inputDef.options,
                          let defaultValue = options["defaultValue"]?.value as? String {
                    input.defaultValue = defaultValue
                }

                input.dashboard = dashboard

                // Serialize options to JSON if they exist
                if let options = inputDef.options,
                   let optionsData = try? encoder.encode(options),
                   let optionsString = String(data: optionsData, encoding: .utf8) {
                    input.optionsJSON = optionsString
                }

                dashboard.addToInputs(input)
            }
        }

        // Create DashboardLayout entity
        let layout = DashboardLayout(context: context)
        layout.id = UUID()
        layout.type = config.layout.type?.rawValue ?? "absolute"
        layout.dashboard = dashboard
        dashboard.layout = layout

        // Create LayoutItem entities (if structure exists - for converted SimpleXML)
        if let structure = config.layout.structure {
            for structureItem in structure {
                let layoutItem = LayoutItem(context: context)
                layoutItem.id = UUID()
                layoutItem.type = structureItem.type.rawValue
                layoutItem.x = Int32(structureItem.position.x ?? 0)
                layoutItem.y = Int32(structureItem.position.y ?? 0)
                layoutItem.width = Int32(structureItem.position.w ?? 0)
                layoutItem.height = Int32(structureItem.position.h ?? 0)
                layoutItem.layout = layout
                layout.addToLayoutItems(layoutItem)

                // Link layout item to visualization if it's a block type
                if structureItem.type == .block,
                   let viz = dashboard.visualizations?.first(where: { ($0 as? Visualization)?.vizId == structureItem.item }) as? Visualization {
                    layoutItem.visualization = viz
                    viz.layoutItem = layoutItem
                }
            }
        }
    }

    /// Parse SimpleXML element to SimpleXMLConfiguration
    /// This is a simplified version - you may need to expand this based on your SimpleXML models
    private func parseToSimpleXMLConfig(root: SimpleXMLElement) throws -> SimpleXMLConfiguration {
        // This is a placeholder - you'll need to implement the full parsing
        // For now, return a minimal config
        let label = root.element(named: "label")?.value ?? "Untitled"
        let description = root.element(named: "description")?.value

        var rows: [SimpleXMLRow] = []
        var fieldsets: [SimpleXMLFieldset]? = nil

        // Parse rows and panels (simplified)
        for rowElement in root.elements(named: "row") {
            var panels: [SimpleXMLPanel] = []

            for panelElement in rowElement.elements(named: "panel") {
                // Parse panel
                let title = panelElement.element(named: "title")?.value

                // Find visualization type (table, chart, etc.)
                var vizType: SimpleXMLVisualizationType = .table
                var search: SimpleXMLSearch? = nil

                // Check for different viz types and extract options
                var vizOptions: [String: String] = [:]
                var formatOptions: [String: String] = [:]

                if let tableElement = panelElement.element(named: "table") {
                    vizType = .table
                    if let searchElement = tableElement.element(named: "search") {
                        search = parseSearch(from: searchElement)
                    }
                    let extracted = tableElement.extractAllOptions()
                    (vizOptions, formatOptions) = extractOptionsAndFormatsFromStructure(extracted)
                } else if let chartElement = panelElement.element(named: "chart") {
                    vizType = .chart
                    if let searchElement = chartElement.element(named: "search") {
                        search = parseSearch(from: searchElement)
                    }
                    let extracted = chartElement.extractAllOptions()
                    (vizOptions, formatOptions) = extractOptionsAndFormatsFromStructure(extracted)
                } else if let singleElement = panelElement.element(named: "single") {
                    vizType = .single
                    if let searchElement = singleElement.element(named: "search") {
                        search = parseSearch(from: searchElement)
                    }
                    let extracted = singleElement.extractAllOptions()
                    (vizOptions, formatOptions) = extractOptionsAndFormatsFromStructure(extracted)
                }

                // Convert formatOptions to AnyCodable format
                let formatsAnyCodable: [[String: AnyCodable]] = formatOptions.isEmpty ? [] :
                    formatOptions.map { (key, value) -> [String: AnyCodable] in
                        return ["key": AnyCodable(key), "value": AnyCodable(value)]
                    }

                let visualization = SimpleXMLVisualization(
                    type: vizType,
                    options: vizOptions,
                    formats: formatsAnyCodable
                )
                let panel = SimpleXMLPanel(
                    title: title,
                    visualization: visualization,
                    search: search
                )
                panels.append(panel)
            }

            if !panels.isEmpty {
                rows.append(SimpleXMLRow(panels: panels))
            }
        }

        // Parse fieldsets (inputs)
        let fieldsetElements = root.elements(named: "fieldset")
        if !fieldsetElements.isEmpty {
            var parsedFieldsets: [SimpleXMLFieldset] = []

            for fieldsetElement in fieldsetElements {
                var inputs: [SimpleXMLInput] = []

                for inputElement in fieldsetElement.elements(named: "input") {
                    if let type = inputElement.attribute("type"),
                       let token = inputElement.attribute("token") {
                        let inputType = mapInputType(type)
                        let label = inputElement.element(named: "label")?.value
                        let defaultValue = inputElement.element(named: "default")?.value

                        // Parse choices for dropdown/radio/multiselect
                        var choices: [SimpleXMLInputChoice] = []
                        for choiceElement in inputElement.elements(named: "choice") {
                            if let value = choiceElement.attribute("value") {
                                let choiceLabel = choiceElement.value ?? value
                                choices.append(SimpleXMLInputChoice(value: value, label: choiceLabel))
                            }
                        }

                        let input = SimpleXMLInput(
                            type: inputType,
                            token: token,
                            label: label,
                            defaultValue: defaultValue,
                            choices: choices
                        )
                        inputs.append(input)
                    }
                }

                if !inputs.isEmpty {
                    parsedFieldsets.append(SimpleXMLFieldset(inputs: inputs))
                }
            }

            if !parsedFieldsets.isEmpty {
                fieldsets = parsedFieldsets
            }
        }

        return SimpleXMLConfiguration(
            label: label,
            description: description,
            rows: rows,
            fieldsets: fieldsets
        )
    }

    private func parseSearch(from searchElement: SimpleXMLElement) -> SimpleXMLSearch? {
        let query = searchElement.element(named: "query")?.value
        let earliest = searchElement.element(named: "earliest")?.value
        let latest = searchElement.element(named: "latest")?.value
        let refresh = searchElement.element(named: "refresh")?.value
        let refreshType = searchElement.element(named: "refreshType")?.value

        // Extract search attributes for chaining and referencing
        let id = searchElement.attribute("id")
        let base = searchElement.attribute("base")
        let ref = searchElement.attribute("ref")

        // Saved searches (ref) don't have inline queries
        // Regular searches and chains require a query
        if ref == nil && query == nil {
            return nil
        }

        return SimpleXMLSearch(
            query: query ?? "",  // Empty string for saved searches
            earliest: earliest,
            latest: latest,
            refresh: refresh,
            refreshType: refreshType,
            id: id,
            base: base,
            ref: ref
        )
    }

    /// Parse native Dashboard Studio format (version 2.x) from XML
    /// Extracts JSON definition from <definition> CDATA section
    private func parseNativeStudioFormat(root: SimpleXMLElement) throws -> DashboardStudioConfiguration {
        // Find the <definition> element
        guard let definitionElement = root.element(named: "definition"),
              let jsonString = definitionElement.value else {
            throw DashboardLoadingError.invalidFormat(message: "No <definition> element found in Dashboard Studio format")
        }

        // Parse the JSON
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw DashboardLoadingError.invalidFormat(message: "Failed to convert definition to data")
        }

        let decoder = JSONDecoder()
        do {
            let config = try decoder.decode(DashboardStudioConfiguration.self, from: jsonData)
            return config
        } catch {
            throw DashboardLoadingError.invalidFormat(message: "Failed to parse Dashboard Studio JSON: \(error.localizedDescription)")
        }
    }

    /// Separate flattened options into regular options and format elements
    /// Convert to strings but preserve the original value for better parsing
    /// Extract options and formats from the nested structure returned by extractAllOptions()
    private func extractOptionsAndFormatsFromStructure(_ structure: [String: Any]) -> (options: [String: String], formats: [String: String]) {
        var options: [String: String] = [:]
        var formats: [String: String] = [:]

        // Extract simple options
        if let optionsDict = structure["options"] as? [String: String] {
            options = optionsDict
        }

        // Extract and flatten format elements
        if let formatsArray = structure["formats"] as? [[String: Any]] {
            for (index, formatDict) in formatsArray.enumerated() {
                // Get field name
                let field = formatDict["field"] as? String ?? "field\(index)"

                // Flatten the format dictionary into format.field.property keys
                for (key, value) in formatDict {
                    if key == "field" { continue } // Skip the field key itself

                    let formatKey: String
                    if let nestedDict = value as? [String: Any] {
                        // For nested dictionaries like palette or scale
                        for (nestedKey, nestedValue) in nestedDict {
                            let fullKey = "format.\(field).\(key).\(nestedKey)"
                            // Convert value to proper string representation
                            if let str = nestedValue as? String {
                                formats[fullKey] = str
                            } else if let jsonData = try? JSONSerialization.data(withJSONObject: nestedValue, options: []),
                                      let jsonString = String(data: jsonData, encoding: .utf8) {
                                formats[fullKey] = jsonString
                            } else {
                                formats[fullKey] = String(describing: nestedValue)
                            }
                        }
                    } else {
                        // For simple values
                        formatKey = "format.\(field).\(key)"
                        if let str = value as? String {
                            formats[formatKey] = str
                        } else if let jsonData = try? JSONSerialization.data(withJSONObject: value, options: []),
                                  let jsonString = String(data: jsonData, encoding: .utf8) {
                            formats[formatKey] = jsonString
                        } else {
                            formats[formatKey] = String(describing: value)
                        }
                    }
                }
            }
        }

        return (options, formats)
    }

    private func separateOptionsAndFormats(_ allOptions: [String: Any]) -> (options: [String: String], formats: [String: String]) {
        var options: [String: String] = [:]
        var formats: [String: String] = [:]

        for (key, value) in allOptions {
            // Convert to string representation
            let stringValue: String
            if let strVal = value as? String {
                stringValue = strVal
            } else if let intVal = value as? Int {
                stringValue = String(intVal)
            } else if let doubleVal = value as? Double {
                stringValue = String(doubleVal)
            } else if let boolVal = value as? Bool {
                stringValue = boolVal ? "true" : "false"
            } else {
                // For complex types (arrays, dictionaries), JSON-encode them properly
                if let jsonData = try? JSONSerialization.data(withJSONObject: value, options: []),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    stringValue = jsonString
                } else {
                    // Fallback to string description only if JSON encoding fails
                    stringValue = String(describing: value)
                }
            }

            if key.hasPrefix("format.") {
                formats[key] = stringValue
            } else {
                options[key] = stringValue
            }
        }

        return (options, formats)
    }

    private func mapInputType(_ type: String) -> SimpleXMLInputType {
        switch type.lowercased() {
        case "time": return .time
        case "dropdown": return .dropdown
        case "radio": return .radio
        case "multiselect": return .multiselect
        case "text": return .text
        case "checkbox": return .checkbox
        default: return .text
        }
    }
}

// MARK: - String Extension for Formatting

private extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}


// MARK: - Dashboard Loading Errors

public enum DashboardLoadingError: Error, LocalizedError {
    case fileNotFound(path: String)
    case notADashboard(rootElement: String)
    case parsingFailed(error: Error)
    case saveFailed(error: Error)
    case invalidFormat(message: String)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Dashboard file not found: \(path)"
        case .notADashboard(let rootElement):
            return "Not a Splunk dashboard - root element is '\(rootElement)', expected 'dashboard' or 'form'"
        case .parsingFailed(let error):
            return "Dashboard parsing failed: \(error.localizedDescription)"
        case .saveFailed(let error):
            return "Failed to save dashboard: \(error.localizedDescription)"
        case .invalidFormat(let message):
            return "Invalid dashboard format: \(message)"
        }
    }
}
