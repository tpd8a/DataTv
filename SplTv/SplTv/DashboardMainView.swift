import SwiftUI
import CoreData
import DashboardKit

#if os(macOS) || os(tvOS)

/// Main view that provides navigation between Monitor and Render views
@available(macOS 26, tvOS 26, *)
struct DashboardMainView: View {
    
    // MARK: - Environment
    @Environment(\.managedObjectContext) private var viewContext
    
    // MARK: - State
    enum ViewMode: String, CaseIterable {
        case monitor = "Monitor"
        case render = "Dashboard"
        
        var icon: String {
            switch self {
            case .monitor: return "gauge"
            case .render: return "square.grid.2x2"
            }
        }
    }
    
    @State private var selectedMode: ViewMode = .monitor
    @State private var selectedDashboard: DashboardEntity?
    @State private var showTokenDebug = false // Toggle for token debug view
    
    // MARK: - Token Manager
    @StateObject private var tokenManager = DashboardTokenManager.shared
    
    // MARK: - Fetch Requests
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \DashboardEntity.title, ascending: true)],
        animation: .default)
    private var dashboards: FetchedResults<DashboardEntity>
    
    // MARK: - Body
    var body: some View {
        NavigationSplitView {
            // Sidebar
            sidebarContent
        } detail: {
            // Main content area
            mainContent
        }
        .onAppear {
            // Auto-select first dashboard if none selected
            if selectedDashboard == nil, let first = dashboards.first {
                selectedDashboard = first
                // Load tokens for the first dashboard
                if selectedMode == .render {
                    tokenManager.loadTokens(for: first)
                }
            }
        }
        .onChange(of: selectedDashboard) { _, newDashboard in
            // Load tokens when dashboard changes
            if let dashboard = newDashboard, selectedMode == .render {
                tokenManager.loadTokens(for: dashboard)
            }
        }
        .onChange(of: selectedMode) { _, newMode in
            // Load tokens when switching to render mode
            if newMode == .render, let dashboard = selectedDashboard {
                tokenManager.loadTokens(for: dashboard)
            }
        }
        .sheet(isPresented: $showingSettings) {
            DashboardSettingsView()
        }
    }
    
    // MARK: - Sidebar
    
    private var sidebarContent: some View {
        List {
            // View Mode Picker
            Section("View Mode") {
                Picker("Mode", selection: $selectedMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Label(mode.rawValue, systemImage: mode.icon)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Dashboard Selector
            Section("Dashboards") {
                if dashboards.isEmpty {
                    Text("No dashboards found")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    ForEach(dashboards, id: \.id) { dashboard in
                        Button {
                            selectedDashboard = dashboard
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(dashboard.title ?? dashboard.id)
                                        .font(.headline)
                                        .foregroundStyle(selectedDashboard?.id == dashboard.id ? .primary : .primary)
                                    
                                    HStack(spacing: 8) {
                                        if let appName = dashboard.appName {
                                            Text(appName)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        
                                        // Show input indicator if dashboard has fieldsets
                                        if selectedMode == .render && !dashboard.fieldsetsArray.isEmpty {
                                            let totalInputs = dashboard.fieldsetsArray.reduce(0) { $0 + $1.tokensArray.count }
                                            if totalInputs > 0 {
                                                HStack(spacing: 2) {
                                                    Image(systemName: "slider.horizontal.3")
                                                        .font(.caption2)
                                                    Text("\(totalInputs)")
                                                        .font(.caption2)
                                                }
                                                .foregroundStyle(.purple)
                                            }
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                if selectedDashboard?.id == dashboard.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Dashboard Inputs (Fieldsets) - Only shown in Dashboard mode
            if selectedMode == .render, let dashboard = selectedDashboard {
                dashboardInputsSection(for: dashboard)
                
                // Token Debug View
                Section {
                    TokenDebugView()
                }
            }
        }
        #if os(macOS)
        .listStyle(.sidebar)
        .frame(minWidth: 280)
        #endif
        .navigationTitle("Dashboards")
    }
    
    // MARK: - Dashboard Inputs Section
    
    @ViewBuilder
    private func dashboardInputsSection(for dashboard: DashboardEntity) -> some View {
        let fieldsets = dashboard.fieldsetsArray
        
        if !fieldsets.isEmpty {
            ForEach(fieldsets, id: \.id) { fieldset in
                Section {
                    if fieldset.tokensArray.isEmpty {
                        Text("No inputs defined")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(fieldset.tokensArray, id: \.name) { token in
                            TokenInputView(token: token)
                        }
                    }
                } header: {
                    HStack {
                        Label("Dashboard Inputs", systemImage: "slider.horizontal.3")
                        
                        if fieldset.submitButton {
                            Image(systemName: "paperplane.circle")
                                .font(.caption)
                                .foregroundStyle(.blue)
                                .help("Has submit button")
                        }
                    }
                } footer: {
                    if fieldset.submitButton {
                        Button {
                            // TODO: Implement submit action
                            print("Submit dashboard inputs")
                        } label: {
                            Label("Submit", systemImage: "paperplane.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            }
        }
    }
    
    // MARK: - Main Content
    
    @ViewBuilder
    private var mainContent: some View {
        if let dashboard = selectedDashboard {
            switch selectedMode {
            case .monitor:
                DashboardDetailView(dashboard: dashboard)
                    .id(dashboard.id) // Force recreation when dashboard changes
                    .toolbar {
                        ToolbarItemGroup(placement: .automatic) {
                            monitorToolbarButtons
                        }
                    }
                
            case .render:
                DashboardRenderView(dashboard: dashboard)
                    .id(dashboard.id) // Force recreation when dashboard changes
                    .toolbar {
                        ToolbarItemGroup(placement: .automatic) {
                            renderToolbarButtons
                        }
                    }
            }
        } else {
            emptyState
        }
    }
    
    // MARK: - Toolbar Buttons
    
    @ViewBuilder
    private var monitorToolbarButtons: some View {
        Button {
            // Settings for table view
            showingSettings = true
        } label: {
            Label("Settings", systemImage: "gear")
        }
        .help("Table and cell display settings")
    }
    
    @ViewBuilder
    private var renderToolbarButtons: some View {
        Button {
            // Refresh all visualizations
            print("🔄 Refresh all visualizations for dashboard")
        } label: {
            Label("Refresh All", systemImage: "arrow.clockwise")
        }
        .help("Refresh all visualizations")
        
        Button {
            // Dashboard settings
            showingSettings = true
        } label: {
            Label("Settings", systemImage: "gear")
        }
        .help("Dashboard settings")
    }
    
    @State private var showingSettings = false
    
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Dashboard Selected", systemImage: "square.dashed")
        } description: {
            if dashboards.isEmpty {
                Text("Import or create a dashboard to get started")
            } else {
                Text("Select a dashboard from the sidebar")
            }
        }
    }
}

// MARK: - Token Input View

/// Renders an individual token input control
struct TokenInputView: View {
    let token: TokenEntity
    
    @State private var textValue: String = ""
    @State private var selectedChoice: String = ""
    @State private var selectedChoices: Set<String> = [] // For multiselect
    @State private var isExpanded: Bool = false // For collapsible inputs
    
    // Integration with TokenManager
    @ObservedObject private var tokenManager = DashboardTokenManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Label
            if let label = token.label, !label.isEmpty {
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
            } else {
                Text(token.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            
            // Input control based on type from rawAttributes
            inputControl
        }
        .onAppear {
            initializeValues()
        }
    }
    
    // MARK: - Actual Token Type Detection
    
    /// Get the actual token type from rawAttributes["type"]
    private var actualTokenType: String {
        // token.type is always "input" - we need to parse rawAttributes for the real type
        guard let data = token.rawAttributes else {
            print("⚠️ Token '\(token.name)': rawAttributes is nil, using fallback")
            // Check if we can infer from choices
            if !token.choicesArray.isEmpty {
                print("   → Inferring 'dropdown' from presence of choices")
                return "dropdown"
            }
            return "text"
        }
        
        print("🔍 Token '\(token.name)': Parsing rawAttributes (size: \(data.count) bytes)")
        
        do {
            guard let rawAttrs = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("⚠️ Token '\(token.name)': rawAttributes is not a dictionary")
                print("   Data: \(String(data: data, encoding: .utf8) ?? "not UTF8")")
                return "text"
            }
            
            print("   Keys in rawAttributes: \(rawAttrs.keys.joined(separator: ", "))")
            
            guard let typeString = rawAttrs["type"] as? String else {
                print("⚠️ Token '\(token.name)': No 'type' key found")
                print("   Full rawAttributes: \(rawAttrs)")
                // Fallback: infer from choices
                if !token.choicesArray.isEmpty {
                    print("   → Inferring 'dropdown' from presence of choices")
                    return "dropdown"
                }
                return "text"
            }
            
            print("✅ Token '\(token.name)': type = '\(typeString)'")
            return typeString.lowercased()
            
        } catch {
            print("❌ Token '\(token.name)': JSON parsing error: \(error)")
            if !token.choicesArray.isEmpty {
                print("   → Inferring 'dropdown' from presence of choices")
                return "dropdown"
            }
            return "text"
        }
    }
    
    @ViewBuilder
    private var inputControl: some View {
        let tokenType = actualTokenType
        
        switch tokenType {
        case "text":
            textInput
            
        case "dropdown":
            dropdownInput
            
        case "radio":
            radioInput
            
        case "checkbox":
            checkboxInput
            
        case "multiselect":
            multiselectInput
            
        case "time":
            timeInput
            
        case "link":
            linkInput
            
        default:
            // Unknown or unsupported type
            unknownInput(typeString: tokenType)
        }
    }
    
    // MARK: - Text Input
    
    private var textInput: some View {
        TextField(token.name, text: $textValue)
            .textFieldStyle(.roundedBorder)
            .font(.caption)
            .onChange(of: textValue) { _, newValue in
                saveTokenValue(newValue)
            }
    }
    
    // MARK: - Dropdown Input
    
    private var dropdownInput: some View {
        Picker(selection: $selectedChoice) {
            if token.choicesArray.isEmpty {
                Text("No choices available")
                    .tag("")
            } else {
                ForEach(token.choicesArray, id: \.value) { choice in
                    Text(choice.label)
                        .tag(choice.value)
                }
            }
        } label: {
            EmptyView()
        }
        .pickerStyle(.menu)
        .font(.caption)
        .disabled(token.choicesArray.isEmpty)
        .onChange(of: selectedChoice) { _, newValue in
            saveTokenValue(newValue)
        }
    }
    
    // MARK: - Radio Input
    
    private var radioInput: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(token.choicesArray, id: \.value) { choice in
                Button {
                    selectedChoice = choice.value
                    saveTokenValue(choice.value)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: selectedChoice == choice.value ? "circle.circle.fill" : "circle")
                            .foregroundStyle(selectedChoice == choice.value ? .blue : .secondary)
                            .imageScale(.small)
                        
                        Text(choice.label)
                            .font(.caption)
                            .foregroundStyle(.primary)
                        
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .disabled(choice.disabled)
            }
        }
    }
    
    // MARK: - Checkbox Input
    
    private var checkboxInput: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(token.choicesArray, id: \.value) { choice in
                Toggle(isOn: Binding(
                    get: { selectedChoices.contains(choice.value) },
                    set: { isSelected in
                        if isSelected {
                            selectedChoices.insert(choice.value)
                        } else {
                            selectedChoices.remove(choice.value)
                        }
                        saveTokenValue(Array(selectedChoices).joined(separator: ","))
                    }
                )) {
                    Text(choice.label)
                        .font(.caption)
                }
                .toggleStyle(.checkbox)
                .disabled(choice.disabled)
            }
        }
    }
    
    // MARK: - Multiselect Input
    
    private var multiselectInput: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Collapsible header
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("\(selectedChoices.count) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                ForEach(token.choicesArray, id: \.value) { choice in
                    Toggle(isOn: Binding(
                        get: { selectedChoices.contains(choice.value) },
                        set: { isSelected in
                            if isSelected {
                                selectedChoices.insert(choice.value)
                            } else {
                                selectedChoices.remove(choice.value)
                            }
                            saveTokenValue(Array(selectedChoices).joined(separator: ","))
                        }
                    )) {
                        Text(choice.label)
                            .font(.caption)
                    }
                    .toggleStyle(.checkbox)
                    .disabled(choice.disabled)
                }
            }
        }
    }
    
    // MARK: - Time Input
    
    private var timeInput: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Simple time range picker
            Menu {
                Button("Last 15 minutes") { setTimeRange("-15m", "now") }
                Button("Last hour") { setTimeRange("-1h", "now") }
                Button("Last 4 hours") { setTimeRange("-4h", "now") }
                Button("Last 24 hours") { setTimeRange("-24h", "now") }
                Button("Last 7 days") { setTimeRange("-7d", "now") }
                Button("Last 30 days") { setTimeRange("-30d", "now") }
            } label: {
                HStack {
                    Text(textValue.isEmpty ? "Select time range" : textValue)
                        .font(.caption)
                        .foregroundStyle(textValue.isEmpty ? .secondary : .primary)
                    
                    Spacer()
                    
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
        }
    }
    
    // MARK: - Link Input
    
    private var linkInput: some View {
        Menu {
            ForEach(token.choicesArray, id: \.value) { choice in
                Button(choice.label) {
                    selectedChoice = choice.value
                    saveTokenValue(choice.value)
                }
            }
        } label: {
            HStack {
                Text(selectedChoice.isEmpty ? "Select..." : selectedChoiceLabel)
                    .font(.caption)
                    .foregroundStyle(selectedChoice.isEmpty ? .secondary : .primary)
                
                Spacer()
                
                Image(systemName: "link")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
        .disabled(token.choicesArray.isEmpty)
    }
    
    // MARK: - Unknown Input Type
    
    private func unknownInput(typeString: String) -> some View {
        HStack {
            Image(systemName: "questionmark.circle")
                .foregroundStyle(.orange)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Unsupported type: \(typeString)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if !token.choicesArray.isEmpty {
                    Text("\(token.choicesArray.count) choices defined")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .help("Token '\(token.name)' has unsupported type '\(typeString)'")
    }
    
    // MARK: - Helper Properties
    
    private var isEditable: Bool {
        // All input types are editable in this context
        return true
    }
    
    private var selectedChoiceLabel: String {
        token.choicesArray.first(where: { $0.value == selectedChoice })?.label ?? selectedChoice
    }
    
    // MARK: - Helper Methods
    
    private func initializeValues() {
        // Priority: initialValue > defaultValue > first choice
        var initialValue: String? = nil
        
        if let initial = token.initialValue, !initial.isEmpty {
            initialValue = initial
        } else if let defaultVal = token.defaultValue, !defaultVal.isEmpty {
            initialValue = defaultVal
        } else if !token.choicesArray.isEmpty {
            // Use first choice if no default specified
            initialValue = token.choicesArray.first?.value
        }
        
        // Set the value
        if let value = initialValue {
            textValue = value
            selectedChoice = value
            
            // For multiselect/checkbox, parse comma-separated values
            if actualTokenType == "multiselect" || actualTokenType == "checkbox" {
                let values = value.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                selectedChoices = Set(values)
            }
            
            print("🎛️ Initialized token '\(token.name)' with value: \(value)")
        }
    }
    
    private func saveTokenValue(_ value: String) {
        // Update local state
        textValue = value
        
        // Update TokenManager (this will notify listeners and track changes)
        tokenManager.setTokenValue(value, forToken: token.name, source: .user)
        
        print("🎛️ Token '\(token.name)' set to: '\(value)' via TokenManager")
    }
    
    private func setTimeRange(_ earliest: String, _ latest: String) {
        let rangeText = "\(earliest) to \(latest)"
        textValue = rangeText
        saveTokenValue(rangeText)
    }
}

// MARK: - Preview

#if DEBUG
@available(macOS 26, tvOS 26, *)
struct DashboardMainView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardMainView()
            .environment(\.managedObjectContext, CoreDataManager.shared.context)
    }
}
#endif

#endif
