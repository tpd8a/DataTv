import SwiftUI
import CoreData
import d8aTvCore
import Combine
import d8aTvCore
// MARK: - Cell Change Settings

/// Settings for how cell changes are displayed in the results table
struct CellChangeSettings: Equatable {
    enum HighlightStyle: String, CaseIterable, Identifiable {
        case splunkDefault = "Splunk Default"
        case systemColors = "System Colors"
        case customColor = "Custom Color"
        case directional = "Directional (↑Green/↓Red)"
        
        var id: String { rawValue }
        
        var description: String {
            switch self {
            case .splunkDefault: return "Use Splunk's color formatting (no change indicators)"
            case .systemColors: return "Use system accent color for changes"
            case .customColor: return "Choose custom color for changes"
            case .directional: return "Green for increases, red for decreases"
            }
        }
    }
    
    var highlightStyle: HighlightStyle = .customColor
    var customColor: Color = .orange
    var fillOpacity: Double = 0.3
    var frameWidth: Double = 2.0
    var showOverlay: Bool = true
    var animateChanges: Bool = true
    var animationDuration: Double = 1.5
    
    // Directional colors (softer shades)
    var increaseColor: Color = Color(red: 0.2, green: 0.7, blue: 0.3) // Soft green
    var decreaseColor: Color = Color(red: 0.9, green: 0.3, blue: 0.3) // Soft red
    
    // Equatable conformance for change detection
    static func == (lhs: CellChangeSettings, rhs: CellChangeSettings) -> Bool {
        return lhs.highlightStyle == rhs.highlightStyle &&
               lhs.customColor == rhs.customColor &&
               lhs.fillOpacity == rhs.fillOpacity &&
               lhs.frameWidth == rhs.frameWidth &&
               lhs.showOverlay == rhs.showOverlay &&
               lhs.animateChanges == rhs.animateChanges &&
               lhs.animationDuration == rhs.animationDuration &&
               lhs.increaseColor == rhs.increaseColor &&
               lhs.decreaseColor == rhs.decreaseColor
    }
}

// MARK: - Table Appearance Settings

/// Settings for table visual appearance
struct TableAppearanceSettings: Equatable {
    // Text colors
    var customTextColor: Color? = nil // nil means use system default
    var changedCellTextColor: Color? = nil // nil means use same as normal text
    
    // Font settings
    var fontDesign: Font.Design = .default
    var fontSize: Double = 13 // Default system size
    var fontWeight: Font.Weight = .regular
    var isItalic: Bool = false
    
    // Background colors
    var useCustomCellBackground: Bool = false
    var customCellBackgroundColor: Color = Color.clear
    
    // Zebra striping
    var enableZebraStriping: Bool = true
    var zebraStripeOpacity: Double = 0.15 // Increased default for better visibility
    
    // Equatable conformance for change detection
    static func == (lhs: TableAppearanceSettings, rhs: TableAppearanceSettings) -> Bool {
        return lhs.customTextColor == rhs.customTextColor &&
               lhs.changedCellTextColor == rhs.changedCellTextColor &&
               lhs.fontDesign == rhs.fontDesign &&
               lhs.fontSize == rhs.fontSize &&
               lhs.fontWeight == rhs.fontWeight &&
               lhs.isItalic == rhs.isItalic &&
               lhs.useCustomCellBackground == rhs.useCustomCellBackground &&
               lhs.customCellBackgroundColor == rhs.customCellBackgroundColor &&
               lhs.enableZebraStriping == rhs.enableZebraStriping &&
               lhs.zebraStripeOpacity == rhs.zebraStripeOpacity
    }
}

// MARK: - Table View Preferences

/// Stores table view preferences for a specific dashboard/search combination
struct TableViewPreferences: Codable {
    var sortField: String?
    var sortAscending: Bool = true
    var columnWidths: [String: Double] = [:]
    
    var key: String {
        // Generate a stable key for storage
        return "\(sortField ?? "none")_\(sortAscending)_\(columnWidths.count)"
    }
}

// MARK: - Settings Storage

class DashboardMonitorSettings: ObservableObject {
    static let shared = DashboardMonitorSettings()
    
    @Published var cellChangeSettings = CellChangeSettings()
    @Published var tableAppearance = TableAppearanceSettings()
    private var tablePreferences: [String: TableViewPreferences] = [:] // Key is "dashboardId:searchId"
    
    private init() {
        loadSettings()
        loadTablePreferences()
    }
    
    func loadSettings() {
        // Load cell change settings
        if let styleRaw = UserDefaults.standard.string(forKey: "cellHighlightStyle"),
           let style = CellChangeSettings.HighlightStyle(rawValue: styleRaw) {
            cellChangeSettings.highlightStyle = style
        }
        
        if let colorData = UserDefaults.standard.data(forKey: "cellCustomColor"),
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) {
            cellChangeSettings.customColor = Color(color)
        }
        
        let fillOpacity = UserDefaults.standard.double(forKey: "cellFillOpacity")
        cellChangeSettings.fillOpacity = fillOpacity > 0 ? fillOpacity : 0.3
        
        let frameWidth = UserDefaults.standard.double(forKey: "cellFrameWidth")
        cellChangeSettings.frameWidth = frameWidth > 0 ? frameWidth : 2.0
        
        // Check if keys exist, if not use defaults
        if UserDefaults.standard.object(forKey: "cellShowOverlay") != nil {
            cellChangeSettings.showOverlay = UserDefaults.standard.bool(forKey: "cellShowOverlay")
        } else {
            cellChangeSettings.showOverlay = true // Default to true
        }
        
        if UserDefaults.standard.object(forKey: "cellAnimateChanges") != nil {
            cellChangeSettings.animateChanges = UserDefaults.standard.bool(forKey: "cellAnimateChanges")
        } else {
            cellChangeSettings.animateChanges = true // Default to true
        }
        
        let animationDuration = UserDefaults.standard.double(forKey: "cellAnimationDuration")
        cellChangeSettings.animationDuration = animationDuration > 0 ? animationDuration : 1.5
        
        // Load table appearance settings
        #if os(macOS)
        if let textColorData = UserDefaults.standard.data(forKey: "tableCustomTextColor"),
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: textColorData) {
            tableAppearance.customTextColor = Color(color)
        }
        
        if let changedTextColorData = UserDefaults.standard.data(forKey: "tableChangedCellTextColor"),
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: changedTextColorData) {
            tableAppearance.changedCellTextColor = Color(color)
        }
        
        if let bgColorData = UserDefaults.standard.data(forKey: "tableCellBackgroundColor"),
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: bgColorData) {
            tableAppearance.customCellBackgroundColor = Color(color)
        }
        #endif
        
        if UserDefaults.standard.object(forKey: "tableUseCustomCellBackground") != nil {
            tableAppearance.useCustomCellBackground = UserDefaults.standard.bool(forKey: "tableUseCustomCellBackground")
        }
        
        if UserDefaults.standard.object(forKey: "tableEnableZebraStriping") != nil {
            tableAppearance.enableZebraStriping = UserDefaults.standard.bool(forKey: "tableEnableZebraStriping")
        } else {
            tableAppearance.enableZebraStriping = true // Default to true
        }
        
        let zebraOpacity = UserDefaults.standard.double(forKey: "tableZebraStripeOpacity")
        tableAppearance.zebraStripeOpacity = zebraOpacity > 0 ? zebraOpacity : 0.15
        
        // Load font settings
        if let fontDesignRaw = UserDefaults.standard.string(forKey: "tableFontDesign") {
            switch fontDesignRaw {
            case "default": tableAppearance.fontDesign = .default
            case "serif": tableAppearance.fontDesign = .serif
            case "rounded": tableAppearance.fontDesign = .rounded
            case "monospaced": tableAppearance.fontDesign = .monospaced
            default: tableAppearance.fontDesign = .default
            }
        }
        
        let fontSize = UserDefaults.standard.double(forKey: "tableFontSize")
        tableAppearance.fontSize = fontSize > 0 ? fontSize : 13
        
        if let fontWeightRaw = UserDefaults.standard.string(forKey: "tableFontWeight") {
            switch fontWeightRaw {
            case "ultraLight": tableAppearance.fontWeight = .ultraLight
            case "thin": tableAppearance.fontWeight = .thin
            case "light": tableAppearance.fontWeight = .light
            case "regular": tableAppearance.fontWeight = .regular
            case "medium": tableAppearance.fontWeight = .medium
            case "semibold": tableAppearance.fontWeight = .semibold
            case "bold": tableAppearance.fontWeight = .bold
            case "heavy": tableAppearance.fontWeight = .heavy
            case "black": tableAppearance.fontWeight = .black
            default: tableAppearance.fontWeight = .regular
            }
        }
        
        if UserDefaults.standard.object(forKey: "tableFontIsItalic") != nil {
            tableAppearance.isItalic = UserDefaults.standard.bool(forKey: "tableFontIsItalic")
        }
    }
    
    func saveSettings() {
        // Force a refresh of the published properties to trigger UI updates
        // This MUST be called BEFORE modifying the structs because @Published
        // needs to see that the value is about to change
        print("💾 Saving settings and triggering UI update...")
        
        // Create copies with the current values to force @Published to detect changes
        let updatedCellSettings = cellChangeSettings
        let updatedTableAppearance = tableAppearance
        
        // Save cell change settings
        UserDefaults.standard.set(cellChangeSettings.highlightStyle.rawValue, forKey: "cellHighlightStyle")
        
        #if os(macOS)
        if let colorData = try? NSKeyedArchiver.archivedData(withRootObject: NSColor(cellChangeSettings.customColor), requiringSecureCoding: false) {
            UserDefaults.standard.set(colorData, forKey: "cellCustomColor")
        }
        #endif
        
        UserDefaults.standard.set(cellChangeSettings.fillOpacity, forKey: "cellFillOpacity")
        UserDefaults.standard.set(cellChangeSettings.frameWidth, forKey: "cellFrameWidth")
        UserDefaults.standard.set(cellChangeSettings.showOverlay, forKey: "cellShowOverlay")
        UserDefaults.standard.set(cellChangeSettings.animateChanges, forKey: "cellAnimateChanges")
        UserDefaults.standard.set(cellChangeSettings.animationDuration, forKey: "cellAnimationDuration")
        
        // Save table appearance settings
        #if os(macOS)
        if let textColor = tableAppearance.customTextColor {
            if let colorData = try? NSKeyedArchiver.archivedData(withRootObject: NSColor(textColor), requiringSecureCoding: false) {
                UserDefaults.standard.set(colorData, forKey: "tableCustomTextColor")
            }
        } else {
            UserDefaults.standard.removeObject(forKey: "tableCustomTextColor")
        }
        
        if let changedTextColor = tableAppearance.changedCellTextColor {
            if let colorData = try? NSKeyedArchiver.archivedData(withRootObject: NSColor(changedTextColor), requiringSecureCoding: false) {
                UserDefaults.standard.set(colorData, forKey: "tableChangedCellTextColor")
            }
        } else {
            UserDefaults.standard.removeObject(forKey: "tableChangedCellTextColor")
        }
        
        if let bgColor = tableAppearance.customCellBackgroundColor as Color? {
            if let colorData = try? NSKeyedArchiver.archivedData(withRootObject: NSColor(bgColor), requiringSecureCoding: false) {
                UserDefaults.standard.set(colorData, forKey: "tableCellBackgroundColor")
            }
        }
        #endif
        
        UserDefaults.standard.set(tableAppearance.useCustomCellBackground, forKey: "tableUseCustomCellBackground")
        UserDefaults.standard.set(tableAppearance.enableZebraStriping, forKey: "tableEnableZebraStriping")
        UserDefaults.standard.set(tableAppearance.zebraStripeOpacity, forKey: "tableZebraStripeOpacity")
        
        // Save font settings
        let fontDesignString: String
        switch tableAppearance.fontDesign {
        case .default: fontDesignString = "default"
        case .serif: fontDesignString = "serif"
        case .rounded: fontDesignString = "rounded"
        case .monospaced: fontDesignString = "monospaced"
        @unknown default: fontDesignString = "default"
        }
        UserDefaults.standard.set(fontDesignString, forKey: "tableFontDesign")
        
        UserDefaults.standard.set(tableAppearance.fontSize, forKey: "tableFontSize")
        
        let fontWeightString: String
        switch tableAppearance.fontWeight {
        case .ultraLight: fontWeightString = "ultraLight"
        case .thin: fontWeightString = "thin"
        case .light: fontWeightString = "light"
        case .regular: fontWeightString = "regular"
        case .medium: fontWeightString = "medium"
        case .semibold: fontWeightString = "semibold"
        case .bold: fontWeightString = "bold"
        case .heavy: fontWeightString = "heavy"
        case .black: fontWeightString = "black"
        default: fontWeightString = "regular"
        }
        UserDefaults.standard.set(fontWeightString, forKey: "tableFontWeight")
        
        UserDefaults.standard.set(tableAppearance.isItalic, forKey: "tableFontIsItalic")
        
        // Now reassign the structs to trigger @Published
        // This forces SwiftUI to recognize that the values have changed
        cellChangeSettings = updatedCellSettings
        tableAppearance = updatedTableAppearance
        
        print("✅ Settings saved and UI update triggered")
    }
    
    // MARK: - Table Preferences Management
    
    private func loadTablePreferences() {
        guard let data = UserDefaults.standard.data(forKey: "tableViewPreferences"),
              let decoded = try? JSONDecoder().decode([String: TableViewPreferences].self, from: data) else {
            print("📊 No saved table preferences found")
            return
        }
        tablePreferences = decoded
        print("📊 Loaded table preferences for \(tablePreferences.count) search(es)")
    }
    
    private func saveTablePreferences() {
        guard let encoded = try? JSONEncoder().encode(tablePreferences) else {
            print("❌ Failed to encode table preferences")
            return
        }
        UserDefaults.standard.set(encoded, forKey: "tableViewPreferences")
        print("💾 Saved table preferences for \(tablePreferences.count) search(es)")
    }
    
    func getTablePreferences(dashboardId: String, searchId: String) -> TableViewPreferences {
        let key = "\(dashboardId):\(searchId)"
        return tablePreferences[key] ?? TableViewPreferences()
    }
    
    func setTablePreferences(_ preferences: TableViewPreferences, dashboardId: String, searchId: String) {
        let key = "\(dashboardId):\(searchId)"
        tablePreferences[key] = preferences
        saveTablePreferences()
    }
    
    func clearTablePreferences(dashboardId: String, searchId: String) {
        let key = "\(dashboardId):\(searchId)"
        tablePreferences.removeValue(forKey: key)
        saveTablePreferences()
    }
}


#if os(macOS) || os(tvOS)

/// Main dashboard monitoring view
/// Displays dashboards with active refresh timers and allows control
public struct DashboardMonitorView: View {
    
    // MARK: - Environment
    @Environment(\.managedObjectContext) private var viewContext
    
    // MARK: - State
    @StateObject private var refreshWorker = DashboardRefreshWorker.shared
    @StateObject private var settings = DashboardMonitorSettings.shared
    @State private var selectedDashboardId: String?
    @State private var showingSettings = false
    
    // MARK: - Fetch Requests
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \DashboardEntity.title, ascending: true)],
        animation: .default)
    private var dashboards: FetchedResults<DashboardEntity>
    
    // MARK: - Initialization
    
    public init() {
        print("🎯 DashboardMonitorView.init() called")
    }
    
    // MARK: - Body
    public var body: some View {
        print("🎯 DashboardMonitorView.body called, dashboards count: \(dashboards.count)")
        return NavigationSplitView {
            // Sidebar - List of dashboards
            dashboardList
        } detail: {
            // Detail - Selected dashboard info and controls
            if let dashboardId = selectedDashboardId,
               let dashboard = dashboards.first(where: { $0.id == dashboardId }) {
                DashboardDetailView(dashboard: dashboard)
            } else {
                emptyDetailView
            }
        }
        .navigationTitle("Dashboard Monitor")
        .onAppear {
            print("✅ DashboardMonitorView.onAppear called")
            print("   - Dashboards: \(dashboards.count)")
            print("   - Active timers: \(refreshWorker.activeTimerCount)")
            print("   - Is running: \(refreshWorker.isRunning)")
        }
        #if os(macOS)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                controlButtons
            }
        }
        #elseif os(tvOS)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                controlButtons
            }
        }
        #endif
        .sheet(isPresented: $showingSettings) {
            DashboardSettingsView()
        }
    }
    
    // MARK: - Sidebar Content
    
    private var dashboardList: some View {
        List(selection: $selectedDashboardId) {
            Section {
                statusSummary
            }
            
            Section("Dashboards") {
                ForEach(dashboards, id: \.id) { dashboard in
                    DashboardRowView(dashboard: dashboard)
                        .tag(dashboard.id)
                }
            }
        }
        #if os(macOS)
        .listStyle(.sidebar)
        #endif
        .frame(minWidth: 250)
    }
    
    private var statusSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: refreshWorker.isRunning ? "play.circle.fill" : "pause.circle")
                    .foregroundStyle(refreshWorker.isRunning ? .green : .secondary)
                    .imageScale(.large)
                
                Text(refreshWorker.isRunning ? "Running" : "Stopped")
                    .font(.headline)
            }
            
            if refreshWorker.activeTimerCount > 0 {
                Text("\(refreshWorker.activeTimerCount) active timer(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if let lastRefresh = refreshWorker.lastRefreshTime {
                Text("Last refresh: \(lastRefresh, formatter: timeFormatter)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Control Buttons
    
    private var controlButtons: some View {
        Group {
            if refreshWorker.isRunning {
                Button {
                    refreshWorker.stopAllTimers()
                } label: {
                    Label("Stop All", systemImage: "stop.circle")
                }
                .help("Stop all refresh timers")
            } else {
                Button {
                    refreshWorker.startAllRefreshTimers()
                } label: {
                    Label("Start All", systemImage: "play.circle")
                }
                .help("Start all refresh timers")
            }
            
            Button {
                showingSettings = true
            } label: {
                Label("Settings", systemImage: "gear")
            }
            .help("Settings")
        }
    }
    
    // MARK: - Empty State
    
    private var emptyDetailView: some View {
        ContentUnavailableView {
            Label("No Dashboard Selected", systemImage: "square.dashed")
        } description: {
            Text("Select a dashboard from the sidebar to view details")
        }
    }
    
    // MARK: - Formatters
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }
}

// MARK: - Dashboard Row View

struct DashboardRowView: View {
    let dashboard: DashboardEntity
    @StateObject private var refreshWorker = DashboardRefreshWorker.shared
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(dashboard.title ?? dashboard.id)
                    .font(.headline)
                
                if let appName = dashboard.appName {
                    Text(appName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Show active timer count for this dashboard
                if let timerCount = activeTimerCount, timerCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .imageScale(.small)
                        Text("\(timerCount) timer(s)")
                    }
                    .font(.caption2)
                    .foregroundStyle(.green)
                }
            }
            
            Spacer()
            
            // Timer control buttons - always show both buttons
            HStack(spacing: 4) {
                Button {
                    refreshWorker.startRefreshTimers(for: dashboard.id)
                } label: {
                    Image(systemName: "play.circle.fill")
                        .foregroundStyle(hasActiveTimers ? Color.secondary : Color.purple)
                        .imageScale(.medium)
                }
                .buttonStyle(.plain)
                .help("Start timers for this dashboard")
                .disabled(hasActiveTimers)
                
                Button {
                    refreshWorker.stopRefreshTimers(for: dashboard.id)
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .foregroundStyle(hasActiveTimers ? Color.purple : Color.secondary)
                        .imageScale(.medium)
                }
                .buttonStyle(.plain)
                .help("Stop timers for this dashboard")
                .disabled(!hasActiveTimers)
            }
        }
        .padding(.vertical, 2)
    }
    
    private var activeTimerCount: Int? {
        let count = refreshWorker.activeSearchTimers.values.filter {
            $0.dashboardId == dashboard.id
        }.count
        return count > 0 ? count : nil
    }
    
    private var hasActiveTimers: Bool {
        activeTimerCount ?? 0 > 0
    }
}

// MARK: - Dashboard Detail View

struct DashboardDetailView: View {
    let dashboard: DashboardEntity
    @StateObject private var refreshWorker = DashboardRefreshWorker.shared
    @State private var selectedSearchId: String?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(dashboard.title ?? dashboard.id)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    if let description = dashboard.dashboardDescription {
                        Text(description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let appName = dashboard.appName {
                        Label(appName, systemImage: "app")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                
                Divider()
                
                // Active timers for this dashboard
                activeTimersSection
                
                Divider()
                
                // Search results section
                searchResultsSection
                
                Spacer()
            }
        }
        #if os(macOS)
        .frame(minWidth: 400)
        #endif
    }
    
    private var activeTimersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dashboard Searches")
                .font(.headline)
            
            // Get all searches for this dashboard
            let allSearches = dashboard.allSearches
            
            if allSearches.isEmpty {
                Text("No searches found in this dashboard")
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(allSearches, id: \.id) { search in
                    // Look up timer info using the composite key format
                    let timerKey = "\(dashboard.id):\(search.id)"
                    let timerInfo = refreshWorker.activeSearchTimers[timerKey]
                    let hasBaseSearch = search.base != nil
                    
                    SearchRowView(
                        search: search,
                        timerInfo: timerInfo,
                        hasBaseSearch: hasBaseSearch,
                        isSelected: selectedSearchId == search.id,
                        onSelect: { selectedSearchId = search.id }
                    )
                }
            }
        }
        .padding()
    }
    
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Search Results")
                .font(.headline)
            
            if let searchId = selectedSearchId {
                SearchResultsTableView(
                    dashboardId: dashboard.id,
                    searchId: searchId
                )
                .id("\(dashboard.id)-\(searchId)") // Force recreation when dashboard or search changes
            } else {
                Text("Select a search timer above to view its results")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            }
        }
        .padding()
    }
}

// MARK: - Timer Info Row

struct TimerInfoRow: View {
    let timerInfo: SearchTimerInfo
    var isSelected: Bool = false
    var onSelect: (() -> Void)? = nil
    
    var body: some View {
        Button {
            onSelect?()
        } label: {
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(isSelected ? .blue : .secondary)
                        Text(timerInfo.searchId)
                            .font(.headline)
                            .foregroundStyle(isSelected ? .primary : .primary)
                        
                        if isSelected {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                    
                    HStack {
                        Label("Interval", systemImage: "clock")
                        Spacer()
                        Text(DashboardRefreshWorker.formatInterval(timerInfo.interval))
                            .fontWeight(.medium)
                    }
                    .font(.caption)
                    
                    if let lastRefresh = timerInfo.lastRefresh {
                        HStack {
                            Label("Last refresh", systemImage: "checkmark.circle")
                            Spacer()
                            Text(lastRefresh, formatter: timeFormatter)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Label("Next refresh", systemImage: "clock.arrow.circlepath")
                        Spacer()
                        Text(timerInfo.nextRefresh, formatter: timeFormatter)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }
}

// MARK: - Search Row View

struct SearchRowView: View {
    let search: SearchEntity
    let timerInfo: SearchTimerInfo?
    let hasBaseSearch: Bool
    var isSelected: Bool = false
    var onSelect: (() -> Void)? = nil
    
    var body: some View {
        Button {
            onSelect?()
        } label: {
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    // Header with search ID and status indicators
                    HStack {
                        Image(systemName: hasBaseSearch ? "link" : "magnifyingglass")
                            .foregroundStyle(isSelected ? .blue : .secondary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(search.id)
                                .font(.headline)
                                .foregroundStyle(isSelected ? .primary : .primary)
                            
                            if hasBaseSearch, let baseId = search.base {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.triangle.branch")
                                        .imageScale(.small)
                                    Text("Post-processes: \(baseId)")
                                        .font(.caption2)
                                }
                                .foregroundStyle(.orange)
                            }
                            
                            // Show refresh interval from search entity
                            if let refreshInterval = search.refresh, !refreshInterval.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.clockwise")
                                        .imageScale(.small)
                                    Text("Refresh: \(refreshInterval)")
                                        .font(.caption2)
                                }
                                .foregroundStyle(.purple)
                            }
                        }
                        
                        Spacer()
                        
                        // Status badges
                        HStack(spacing: 6) {
                            if timerInfo != nil {
                                Image(systemName: "timer")
                                    .foregroundStyle(.green)
                                    .help("Has active refresh timer")
                            } else if let refreshInterval = search.refresh, !refreshInterval.isEmpty {
                                Image(systemName: "timer.circle")
                                    .foregroundStyle(.orange)
                                    .help("Has refresh interval but timer not active")
                            }
                            
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    
                    // Timer info if available
                    if let timer = timerInfo {
                        Divider()
                        
                        HStack {
                            Label("Active Interval", systemImage: "clock")
                            Spacer()
                            Text(DashboardRefreshWorker.formatInterval(timer.interval))
                                .fontWeight(.medium)
                        }
                        .font(.caption)
                        
                        if let lastRefresh = timer.lastRefresh {
                            HStack {
                                Label("Last refresh", systemImage: "checkmark.circle")
                                Spacer()
                                Text(lastRefresh, formatter: timeFormatter)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        
                        HStack {
                            Label("Next refresh", systemImage: "clock.arrow.circlepath")
                            Spacer()
                            Text(timer.nextRefresh, formatter: timeFormatter)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    } else {
                        // Show search type info if no timer
                        HStack {
                            if hasBaseSearch {
                                Label("Post-processing search", systemImage: "wand.and.stars")
                            } else if let refreshInterval = search.refresh, !refreshInterval.isEmpty {
                                Label("Has refresh: \(refreshInterval) (timer not started)", systemImage: "timer.circle")
                                    .foregroundStyle(.orange)
                            } else {
                                Label("Static search", systemImage: "doc.text")
                            }
                            Spacer()
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    
                    // Show query preview if available
                    if let query = search.query, !query.isEmpty {
                        Divider()
                        
                        Text(query)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .help(query)
                    }
                }
                .padding(.vertical, 4)
            }
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }
}

// MARK: - Search Results Table View

struct SearchResultsTableView: View {
    let dashboardId: String
    let searchId: String
    
    @Environment(\.managedObjectContext) private var viewContext
    @State private var executions: [SearchExecutionEntity] = []
    @State private var selectedExecutionId: String?
    @State private var isPlaying = false
    @State private var playbackTimer: Timer?
    @State private var currentExecutionIndex: Int = 0
    @State private var notificationObserver: NSObjectProtocol?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Timeline controls
            timelineSection
            
            Divider()
            
            // Results table
            if let executionId = selectedExecutionId,
               let execution = executions.first(where: { $0.id == executionId }),
               let currentIndex = executions.firstIndex(where: { $0.id == executionId }) {
                // Check if there's a previous (older) execution to compare with
                // Since executions are sorted newest-first, the previous execution is at currentIndex + 1
                let hasPreviousExecution = currentIndex < executions.count - 1
                
                if hasPreviousExecution {
                    let previousExecution = executions[currentIndex + 1]
                    //print("📊 Showing execution at index \(currentIndex) with previous at index \(currentIndex + 1)")
                    ResultsTableContent(
                        execution: execution,
                        previousExecution: previousExecution,
                        showChanges: true
                    )
                    .id(executionId) // Force view recreation when execution changes
                } else {
                    //print("📊 Showing execution at index \(currentIndex) with no previous execution (oldest)")
                    ResultsTableContent(
                        execution: execution,
                        previousExecution: nil,
                        showChanges: false
                    )
                    .id(executionId)
                }
            } else {
                emptyResultsView
            }
        }
        .onAppear {
            loadExecutions()
            setupNotificationListener()
        }
        .onDisappear {
            stopPlayback()
            removeNotificationListener()
        }
    }
    
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Execution Timeline")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button {
                    loadExecutions()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
            }
            
            if executions.isEmpty {
                Text("No executions found for this search")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                // Playback controls
                HStack(spacing: 12) {
                    // Previous button
                    Button {
                        moveToPrevious()
                    } label: {
                        Image(systemName: "backward.fill")
                    }
                    .buttonStyle(.bordered)
                    .disabled(currentExecutionIndex >= executions.count - 1)
                    
                    // Play/Pause button
                    Button {
                        togglePlayback()
                    } label: {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    
                    // Next button
                    Button {
                        moveToNext()
                    } label: {
                        Image(systemName: "forward.fill")
                    }
                    .buttonStyle(.bordered)
                    .disabled(currentExecutionIndex <= 0)
                    
                    // Jump to latest
                    Button {
                        jumpToLatest()
                    } label: {
                        Label("Latest", systemImage: "arrow.right.to.line")
                    }
                    .buttonStyle(.bordered)
                    .disabled(currentExecutionIndex == 0)
                    
                    Spacer()
                    
                    // Current position indicator
                    Text("\(executions.count - currentExecutionIndex) of \(executions.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Timeline slider
                VStack(alignment: .leading, spacing: 4) {
                    Slider(
                        value: Binding(
                            get: { Double(executions.count - 1 - currentExecutionIndex) },
                            set: { newValue in
                                currentExecutionIndex = executions.count - 1 - Int(newValue)
                                updateSelectedExecution()
                            }
                        ),
                        in: 0...Double(max(1, executions.count - 1)),
                        step: executions.count > 1 ? 1 : 0.1  // Use 0.1 step when only 1 execution to avoid crash
                    )
                    .disabled(isPlaying || executions.count <= 1)
                    
                    // Timeline labels
                    if let currentExecution = executions[safe: currentExecutionIndex] {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(currentExecution.startTime, formatter: dateTimeFormatter)
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(executionStatusColor(currentExecution))
                                        .frame(width: 6, height: 6)
                                    Text(executionStatusText(currentExecution))
                                        .font(.caption2)
                                    if currentExecution.resultCount > 0 {
                                        Text("• \(currentExecution.resultCount) rows")
                                            .font(.caption2)
                                    }
                                }
                                .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            if currentExecutionIndex < executions.count - 1,
                               let previousExecution = executions[safe: currentExecutionIndex + 1] {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("vs Previous")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    
                                    let diff = currentExecution.resultCount - previousExecution.resultCount
                                    if diff != 0 {
                                        Text("\(diff > 0 ? "+" : "")\(diff) rows")
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                            .foregroundStyle(diff > 0 ? .green : .red)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var emptyResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tablecells")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No Results Available")
                .font(.headline)
            
            Text("Run a search or wait for automatic refresh")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Helper Methods
    
    private func loadExecutions() {
        let request: NSFetchRequest<SearchExecutionEntity> = SearchExecutionEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "searchId == %@ AND dashboardId == %@",
            searchId,
            dashboardId
        )
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]
        request.fetchLimit = 50 // Show last 50 executions for better timeline
        
        do {
            let previousCount = executions.count
            let wasAtLatest = currentExecutionIndex == 0 && selectedExecutionId != nil
            let oldExecutions = executions
            
            executions = try viewContext.fetch(request)
            
            print("🔄 loadExecutions: previousCount=\(previousCount), newCount=\(executions.count), wasAtLatest=\(wasAtLatest)")
            
            // Auto-jump to latest when new execution arrives AND user was already viewing latest
            if previousCount > 0 && executions.count > previousCount && wasAtLatest {
                print("  ↳ New execution detected, jumping to latest")
                jumpToLatest()
            } else if previousCount > 0 && executions.count > previousCount {
                // New executions arrived but user wasn't at latest - maintain their position
                // Try to find the currently selected execution in the new array
                if let selectedId = selectedExecutionId,
                   let newIndex = executions.firstIndex(where: { $0.id == selectedId }) {
                    currentExecutionIndex = newIndex
                    print("  ↳ New execution detected, maintaining position at index \(newIndex)")
                }
            }
            
            // Auto-select most recent completed execution on first load
            if selectedExecutionId == nil,
               let mostRecent = executions.first(where: {
                   $0.executionStatus == .completed && $0.resultCount > 0
               }) {
                selectedExecutionId = mostRecent.id
                currentExecutionIndex = 0
                print("  ↳ First load, selected most recent: \(mostRecent.id)")
            }
        } catch {
            print("❌ Error loading executions: \(error)")
            executions = []
        }
    }
    
    // MARK: - Playback Controls
    
    private func togglePlayback() {
        isPlaying.toggle()
        
        if isPlaying {
            startPlayback()
        } else {
            stopPlayback()
        }
    }
    
    private func startPlayback() {
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            if currentExecutionIndex > 0 {
                moveToNext()
            } else {
                stopPlayback()
                isPlaying = false
            }
        }
    }
    
    private func stopPlayback() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    private func moveToNext() {
        guard currentExecutionIndex > 0 else { return }
        currentExecutionIndex -= 1
        updateSelectedExecution()
    }
    
    private func moveToPrevious() {
        guard currentExecutionIndex < executions.count - 1 else { return }
        currentExecutionIndex += 1
        updateSelectedExecution()
    }
    
    private func jumpToLatest() {
        currentExecutionIndex = 0
        updateSelectedExecution()
    }
    
    private func updateSelectedExecution() {
        guard currentExecutionIndex < executions.count else { return }
        selectedExecutionId = executions[currentExecutionIndex].id
    }
    
    // MARK: - Notification Handling
    
    private func setupNotificationListener() {
        // Listen for search execution completion notifications
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .searchExecutionCompleted,
            object: nil,
            queue: .main
        ) { notification in
            // Check if this notification is for our search
            if let userInfo = notification.userInfo,
               let notificationSearchId = userInfo["searchId"] as? String,
               let notificationDashboardId = userInfo["dashboardId"] as? String,
               notificationSearchId == self.searchId,
               notificationDashboardId == self.dashboardId {
                print("🔔 SearchResultsTableView: Search completed for \(notificationSearchId), reloading")
                self.loadExecutions()
            }
        }
        
        print("🔔 SearchResultsTableView: Set up searchExecutionCompleted notification listener")
    }
    
    private func removeNotificationListener() {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
            notificationObserver = nil
            print("🔔 SearchResultsTableView: Removed notification listener")
        }
    }
    
    private func executionStatusText(_ execution: SearchExecutionEntity) -> String {
        switch execution.executionStatus {
        case .pending: return "Pending"
        case .running: return "Running"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }
    
    private func executionStatusColor(_ execution: SearchExecutionEntity) -> Color {
        switch execution.executionStatus {
        case .pending: return .orange
        case .running: return .blue
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .gray
        }
    }
    
    private var dateTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }
}

// MARK: - Results Table Content

struct ResultsTableContent: View {
    let execution: SearchExecutionEntity
    let previousExecution: SearchExecutionEntity?
    let showChanges: Bool
    
    @ObservedObject private var settings = DashboardMonitorSettings.shared
    @State private var results: [[String: Any]] = []
    @State private var previousResults: [[String: Any]] = []
    @State private var fields: [String] = []
    @State private var fieldMetadata: [String: [String: Any]] = [:] // Store field metadata including groupby_rank
    @State private var isLoading = true
    @State private var animatingCells: Set<String> = [] // Track which cells are animating
    @State private var newRowIndices: Set<Int> = [] // Track new rows for slide-in animation
    @State private var newRowsAnimating: Bool = false // Track if new row animations are active
    @State private var deletedRowSignatures: Set<String> = [] // Track deleted rows
    @State private var deletedRows: [[String: Any]] = [] // Store deleted rows temporarily for slide-out
    @State private var deletingRowIndices: Set<Int> = [] // Track which deleted rows are animating out
    @State private var sortField: String?
    @State private var sortAscending = true
    @State private var columnWidths: [String: CGFloat] = [:] // Track custom column widths
    @State private var preferencesLoaded = false // Track if we've loaded saved preferences
    
    // Splunk table options
    @State private var wrapResults: Bool = false // Whether to wrap text in cells (multi-line)
    @State private var showRowNumbers: Bool = false // Whether to show row number column
    @State private var vizFormatting: VisualizationFormatting? = nil // Splunk visualization formatting
    @State private var displayRowCount: Int = 10 // Number of rows to display from Splunk count option
    @State private var fieldsWithNumberFormat: Set<String> = [] // Cache of fields that have number formatting
    @State private var fieldsWithColorFormat: Set<String> = [] // Cache of fields that have color formatting
    
    // Column resizing
    @State private var resizingColumn: String? = nil // Track which column is being resized
    @State private var resizeStartX: CGFloat = 0 // Starting X position for resize
    @State private var resizeStartWidth: CGFloat = 0 // Starting width for resize
    
    @Environment(\.managedObjectContext) private var viewContext
    
    // MARK: - Computed Properties
    
    /// Results limited by Splunk's count option
    private var displayedResults: [[String: Any]] {
        guard displayRowCount > 0 else { return results }
        return Array(results.prefix(displayRowCount))
    }
    
    /// Total number of pages needed
    private var totalPages: Int {
        guard displayRowCount > 0 else { return 1 }
        return max(1, Int(ceil(Double(results.count) / Double(displayRowCount))))
    }
    
    var body: some View {
        #if DEBUG
        let _ = print("🎨 [BODY] ResultsTableContent.body evaluated - isLoading: \(isLoading), results.count: \(results.count), fields.count: \(fields.count)")
        #endif
        
        return VStack(alignment: .leading, spacing: 12) {
            // Header with metadata
            resultMetadataHeader
            
            Divider()
            
            // Table
            if isLoading {
                ProgressView("Loading results...")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else if results.isEmpty {
                Text("No data to display")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                ScrollView([.horizontal, .vertical]) {
                    resultTable
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                #if os(macOS)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
                #else
                .background(Color(uiColor: .secondarySystemBackground).opacity(0.5))
                #endif
                .cornerRadius(10)
            }
        }
        .onAppear {
            loadResults()
            loadTablePreferences()
        }
        .onChange(of: execution.id) { _, _ in
            // Reload results when execution changes
            print("🔄 ResultsTableContent: execution.id changed, reloading results")
            loadResults()
            loadTablePreferences() // Reload preferences for new execution
        }
        .onChange(of: execution.resultCount) { _, _ in
            // Reload results when result count changes (indicates new data)
            print("🔄 ResultsTableContent: resultCount changed to \(execution.resultCount), reloading results")
            loadResults()
        }
        .onChange(of: settings.cellChangeSettings) { oldValue, newValue in
            print("🔄 ResultsTableContent: cellChangeSettings changed")
            print("   Old style: \(oldValue.highlightStyle.rawValue)")
            print("   New style: \(newValue.highlightStyle.rawValue)")
            // Force view refresh by triggering cell animation check
            if settings.cellChangeSettings.animateChanges {
                triggerCellAnimations()
            }
        }
        .onChange(of: settings.tableAppearance) { oldValue, newValue in
            print("🔄 ResultsTableContent: tableAppearance changed")
            print("   Old font size: \(oldValue.fontSize)")
            print("   New font size: \(newValue.fontSize)")
            // No action needed - @ObservedObject will handle the refresh
        }
    }
    
    private var resultMetadataHeader: some View {
        HStack(spacing: 8) {
            Spacer()
            
            // Change indicator legend (compact icons only)
            if showChanges && settings.cellChangeSettings.highlightStyle != .splunkDefault {
                HStack(spacing: 6) {
                    if settings.cellChangeSettings.highlightStyle == .directional {
                        // Increase indicator
                        RoundedRectangle(cornerRadius: 2)
                            .fill(settings.cellChangeSettings.increaseColor.opacity(settings.cellChangeSettings.fillOpacity))
                            .frame(width: 12, height: 12)
                            .overlay(
                                settings.cellChangeSettings.showOverlay ?
                                    RoundedRectangle(cornerRadius: 2)
                                        .stroke(settings.cellChangeSettings.increaseColor, lineWidth: 1)
                                : nil
                            )
                            .help("Increased values")
                        
                        // Decrease indicator
                        RoundedRectangle(cornerRadius: 2)
                            .fill(settings.cellChangeSettings.decreaseColor.opacity(settings.cellChangeSettings.fillOpacity))
                            .frame(width: 12, height: 12)
                            .overlay(
                                settings.cellChangeSettings.showOverlay ?
                                    RoundedRectangle(cornerRadius: 2)
                                        .stroke(settings.cellChangeSettings.decreaseColor, lineWidth: 1)
                                : nil
                            )
                            .help("Decreased values")
                    } else {
                        let legendColor: Color = {
                            switch settings.cellChangeSettings.highlightStyle {
                            case .systemColors:
                                #if os(macOS)
                                return Color(nsColor: .controlAccentColor)
                                #else
                                return .accentColor
                                #endif
                            case .customColor:
                                return settings.cellChangeSettings.customColor
                            default:
                                return .orange
                            }
                        }()
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(legendColor.opacity(settings.cellChangeSettings.fillOpacity))
                            .frame(width: 12, height: 12)
                            .overlay(
                                settings.cellChangeSettings.showOverlay ?
                                    RoundedRectangle(cornerRadius: 2)
                                        .stroke(legendColor, lineWidth: 1)
                                : nil
                            )
                            .help("Changed values")
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
    
    private func resetTablePreferences() {
        sortField = nil
        sortAscending = true
        columnWidths.removeAll()
        settings.clearTablePreferences(
            dashboardId: execution.dashboardId,
            searchId: execution.searchId
        )
        // Reload results to clear sorting
        let tempResults = results
        results = tempResults
        print("🔄 Reset table preferences to defaults")
    }
    
    private var resultTable: some View {
        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
            Section {
                tableDataRows
            } header: {
                tableHeaderRow
                    .background(Color(nsColor: .controlBackgroundColor))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tableBackground)
        .overlay(tableBorder)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var tableHeaderRow: some View {
        HStack(spacing: 0) {
            if showRowNumbers {
                rowNumberHeaderCell
                Divider()
            }
            
            ForEach(fields, id: \.self) { field in
                columnHeaderCell(for: field)
                
                if field != fields.last {
                    Divider()
                }
            }
        }
    }
    
    private var rowNumberHeaderCell: some View {
        Text("#")
            .font(.system(
                size: settings.tableAppearance.fontSize,
                weight: .bold, // Always bold for headers
                design: settings.tableAppearance.fontDesign
            ))
            .frame(width: 60, alignment: .center)
            .padding(.vertical, 10)
            #if os(macOS)
            .background(Color(nsColor: .controlAccentColor).opacity(0.15))
            #else
            .background(Color.accentColor.opacity(0.15))
            #endif
    }
    
    private func columnHeaderCell(for field: String) -> some View {
        let columnWidth = columnWidths[field] ?? 150 // Fallback to 150 if not set
        
        return Button {
            sortByField(field)
        } label: {
            HStack(spacing: 6) {
                Text(field)
                    .font(.system(
                        size: settings.tableAppearance.fontSize,
                        weight: .bold, // Always bold for headers
                        design: settings.tableAppearance.fontDesign
                    ))
                    .lineLimit(1)
                
                Spacer(minLength: 4)
                
                sortIndicator(for: field)
            }
            .frame(width: columnWidth, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(headerBackgroundColor(for: field))
        #if os(macOS)
        .onTapGesture(count: 2) {
            autoSizeColumn(field)
        }
        .onHover { isHovered in
            if isHovered {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        #endif
        .help("\(field)\nClick to sort • Double-click to auto-size")
    }
    
    @ViewBuilder
    private func sortIndicator(for field: String) -> some View {
        if sortField == field {
            Image(systemName: sortAscending ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                .font(.caption)
                .foregroundStyle(.blue)
        } else {
            Image(systemName: "arrow.up.arrow.down.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .opacity(0.5)
        }
    }
    
    private func headerBackgroundColor(for field: String) -> Color {
        #if os(macOS)
        return Color(nsColor: .controlAccentColor).opacity(sortField == field ? 0.25 : 0.15)
        #else
        return Color.accentColor.opacity(sortField == field ? 0.25 : 0.15)
        #endif
    }
    
    private var tableDataRows: some View {
        #if DEBUG
        let _ = print("🎨 [TABLE ROWS] Building tableDataRows with \(displayedResults.count) results")
        #endif
        
        return ForEach(Array(displayedResults.enumerated()), id: \.offset) { index, row in
            tableDataRow(index: index, row: row)
            
            if index != results.count - 1 {
                Divider()
                    .opacity(0.3)
            }
        }
    }
    
    private func tableDataRow(index: Int, row: [String: Any]) -> some View {
        let isNewRow = newRowIndices.contains(index)
        let shouldOffset = isNewRow && !newRowsAnimating
        
        return HStack(alignment: .top, spacing: 0) {
            if showRowNumbers {
                rowNumberCell(index: index)
                Divider().opacity(0.5)
            }
            
            ForEach(fields, id: \.self) { field in
                dataCell(field: field, row: row, index: index)
                
                if field != fields.last {
                    Divider().opacity(0.5)
                }
            }
        }
        .offset(x: shouldOffset ? 150 : 0)
        .opacity(shouldOffset ? 0.0 : 1.0)
        .scaleEffect(shouldOffset ? 0.85 : 1.0, anchor: .leading)
        .overlay(newRowGlow(isNewRow: isNewRow))
    }
    
    private func rowNumberCell(index: Int) -> some View {
        let baseFont = Font.system(
            size: settings.tableAppearance.fontSize,
            weight: settings.tableAppearance.fontWeight,
            design: settings.tableAppearance.fontDesign
        )
        
        return Text("\(index + 1)")
            .font(settings.tableAppearance.isItalic ? baseFont.italic() : baseFont)
            .foregroundStyle(.secondary)
            .frame(minHeight: wrapResults ? 24 : nil, alignment: .center)
            .padding(.vertical, 8)
            .background(rowBackground(for: index))
    }

    private func dataCell(field: String, row: [String: Any], index: Int) -> some View {
        let cellValue = stringValue(for: field, in: row)
        let changeInfo = cellChangeInfo(field: field, rowIndex: index)
        let cellKey = "\(index)-\(field)"
        let isAnimating = animatingCells.contains(cellKey)
        
        // Get raw value for formatting
        let rawValue = row[field]
        
        #if DEBUG
        // Debug EVERY cell's color calculation, not just row 0
        if field == "count" || field == "error" || field == "info" || field == "source" {
            print("🎨 [CELL \(index)-\(field)] rawValue=\(String(describing: rawValue)), type=\(type(of: rawValue))")
        }
        #endif
        
        // Apply Splunk number formatting ONLY if this field has number formatting defined
        let displayValue: String
        if fieldsWithNumberFormat.contains(field),
           let formatting = vizFormatting,
           let formattedValue = formatting.applyNumberFormatting(field: field, value: rawValue ?? cellValue) {
            displayValue = formattedValue
        } else {
            displayValue = cellValue
        }
        
        // IMPORTANT: Calculate these OUTSIDE the closure so debug prints execute
        let shouldUseSplunkColors = settings.cellChangeSettings.highlightStyle == .splunkDefault
        let fieldHasColorFormat = fieldsWithColorFormat.contains(field)
        
        #if DEBUG
        if field == "count" || field == "error" || field == "info" || field == "source" {
            print("🎨 [CELL \(index)-\(field)] shouldUseSplunkColors=\(shouldUseSplunkColors), fieldHasColorFormat=\(fieldHasColorFormat)")
        }
        #endif
        
        // Calculate Splunk background color if applicable
        let splunkBackgroundColor: Color? = {
            guard shouldUseSplunkColors && fieldHasColorFormat else {
                #if DEBUG
                if field == "count" || field == "error" || field == "info" || field == "source" {
                    print("🎨 [CELL \(index)-\(field)] ❌ Skipping color calc: splunk=\(shouldUseSplunkColors), hasFormat=\(fieldHasColorFormat)")
                }
                #endif
                return nil
            }
            
            guard let formatting = vizFormatting else {
                #if DEBUG
                if field == "count" || field == "error" || field == "info" || field == "source" {
                    print("🎨 [CELL \(index)-\(field)] ❌ No vizFormatting")
                }
                #endif
                return nil
            }
            
            let allColumnValues = results.map { $0[field] }
            
            #if DEBUG
            if field == "count" || field == "error" || field == "info" || field == "source" {
                print("🎨 [CELL \(index)-\(field)] ✓ Calling applyColorFormatting with \(allColumnValues.count) values")
                print("🎨 [CELL \(index)-\(field)]   value to format: \(String(describing: rawValue ?? cellValue))")
            }
            #endif
            
            let color = formatting.applyColorFormatting(
                field: field,
                value: rawValue ?? cellValue,
                allValues: allColumnValues
            )
            
            #if DEBUG
            if field == "count" || field == "error" || field == "info" || field == "source" {
                if let actualColor = color {
                    print("🎨 [CELL \(index)-\(field)] ✅ Got color: \(actualColor)")
                } else {
                    print("🎨 [CELL \(index)-\(field)] ❌ applyColorFormatting returned nil")
                }
            }
            #endif
            
            return color
        }()
        
        // Calculate background color - CORRECTED PRIORITY ORDER
        let backgroundColor: Color = {
            // PRIORITY 1: In Splunk Default mode, Splunk colors take absolute priority
            if shouldUseSplunkColors, let splunkColor = splunkBackgroundColor {
                #if DEBUG
                if field == "count" || field == "error" || field == "info" || field == "source" {
                    print("🎨 [CELL \(index)-\(field)] ✅ Using Splunk color (priority over custom): \(splunkColor)")
                }
                #endif
                return splunkColor.opacity(0.7)
            }
            
            // PRIORITY 2: Custom cell background (if enabled)
            if settings.tableAppearance.useCustomCellBackground {
                #if DEBUG
                if field == "count" || field == "error" || field == "info" || field == "source" {
                    print("🎨 [CELL \(index)-\(field)] Using custom cell background")
                }
                #endif
                return settings.tableAppearance.customCellBackgroundColor
            }
            
            // PRIORITY 3: Apply change highlighting (if cell changed and NOT in Splunk Default)
            if changeInfo.hasChanged {
                #if DEBUG
                if field == "count" || field == "error" || field == "info" || field == "source" {
                    print("🎨 [CELL \(index)-\(field)] Cell changed, style=\(settings.cellChangeSettings.highlightStyle.rawValue)")
                }
                #endif
                
                switch settings.cellChangeSettings.highlightStyle {
                case .splunkDefault:
                    // Already handled above - shouldn't reach here
                    break
                case .systemColors, .customColor, .directional:
                    let baseColor = changeInfo.color
                    let opacity = isAnimating && settings.cellChangeSettings.animateChanges ? 0.8 : settings.cellChangeSettings.fillOpacity
                    return baseColor.opacity(opacity)
                }
            }
            
            // PRIORITY 4: Fallback to zebra striping
            #if DEBUG
            if field == "count" || field == "error" || field == "info" || field == "source" {
                print("🎨 [CELL \(index)-\(field)] Using zebra/clear background")
            }
            #endif
            return rowBackground(for: index)
        }()
        
        let textColor: Color = {
            if changeInfo.hasChanged && settings.tableAppearance.changedCellTextColor != nil {
                return settings.tableAppearance.changedCellTextColor!
            }
            if let customColor = settings.tableAppearance.customTextColor {
                return customColor
            }
            if cellValue.isEmpty {
                #if os(macOS)
                return Color(nsColor: .tertiaryLabelColor)
                #else
                return Color(uiColor: .tertiaryLabel)
                #endif
            } else {
                #if os(macOS)
                return Color(nsColor: .labelColor)
                #else
                return Color(uiColor: .label)
                #endif
            }
        }()
        
        let baseFont = Font.system(
            size: settings.tableAppearance.fontSize,
            weight: settings.tableAppearance.fontWeight,
            design: settings.tableAppearance.fontDesign
        )
        
        return Text(displayValue)
            .font(settings.tableAppearance.isItalic ? baseFont.italic() : baseFont)
            .foregroundStyle(textColor)
            .frame(minWidth: columnWidths[field] ?? 150, maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(backgroundColor)
            .lineLimit(wrapResults ? nil : 3)
            .truncationMode(.tail)
            .help(displayValue)
            .textSelection(.enabled)
            .overlay(
                changeInfo.hasChanged &&
                settings.cellChangeSettings.showOverlay &&
                settings.cellChangeSettings.highlightStyle != .splunkDefault ?
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(changeInfo.color, lineWidth: settings.cellChangeSettings.frameWidth)
                        .padding(2)
                        .opacity(isAnimating && settings.cellChangeSettings.animateChanges ? 1.0 : 0.7)
                : nil
            )
            .id("\(index)-\(field)-\(cellValue)-\(changeInfo.hasChanged)-\(settings.cellChangeSettings.highlightStyle.rawValue)-\(settings.tableAppearance.fontSize)-\(settings.tableAppearance.fontWeight)")
            .animation(.easeInOut(duration: settings.cellChangeSettings.animationDuration), value: isAnimating)
    }
    
    @ViewBuilder
    private func newRowGlow(isNewRow: Bool) -> some View {
        if isNewRow && newRowsAnimating {
            RoundedRectangle(cornerRadius: 6)
                .stroke(settings.cellChangeSettings.increaseColor, lineWidth: 2)
                .shadow(color: settings.cellChangeSettings.increaseColor.opacity(0.5), radius: 6, x: 0, y: 0)
                .shadow(color: settings.cellChangeSettings.increaseColor.opacity(0.25), radius: 10, x: 0, y: 0)
        }
    }
    
    private var tableBackground: some View {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }
    
    private var tableBorder: some View {
        #if os(macOS)
        RoundedRectangle(cornerRadius: 8)
            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        #else
        RoundedRectangle(cornerRadius: 8)
            .stroke(Color(uiColor: .separator), lineWidth: 1)
        #endif
    }
    
    private func rowBackground(for index: Int) -> Color {
        // If custom cell background is enabled, it takes full priority
        if settings.tableAppearance.useCustomCellBackground {
            return settings.tableAppearance.customCellBackgroundColor
        }
        
        // Zebra striping logic
        guard settings.tableAppearance.enableZebraStriping else {
            return .clear
        }
        
        // Only stripe odd rows (index 1, 3, 5, etc.)
        guard index % 2 != 0 else {
            return .clear
        }
        
        #if os(macOS)
        // Use a darker/lighter color depending on the appearance
        return Color(nsColor: .separatorColor).opacity(settings.tableAppearance.zebraStripeOpacity * 2)
        #else
        return Color(uiColor: .systemGray4).opacity(settings.tableAppearance.zebraStripeOpacity * 2)
        #endif
    }
    
    // MARK: - Helper Methods
    
    private func cellView(value: String, field: String, changeInfo: CellChangeInfo, isAnimating: Bool, rowIndex: Int) -> some View {
        // Try to get the actual value from the row for formatting
        let rowData = results[rowIndex]
        let rawValue = rowData[field]
        
        // Apply Splunk number formatting ONLY if this field has number formatting defined
        let displayValue: String
        if fieldsWithNumberFormat.contains(field),
           let formatting = vizFormatting,
           let formattedValue = formatting.applyNumberFormatting(field: field, value: rawValue ?? value) {
            displayValue = formattedValue
        } else {
            displayValue = value
        }
        
        let backgroundColor: Color = {
            // Custom cell background (if enabled) - takes highest priority
            if settings.tableAppearance.useCustomCellBackground {
                return settings.tableAppearance.customCellBackgroundColor
            }
            
            // Determine if we should use Splunk color formatting
            let shouldUseSplunkColors = settings.cellChangeSettings.highlightStyle == .splunkDefault
            
            // Only calculate Splunk colors if this field has color formatting AND we're in Splunk Default mode
            let splunkBackgroundColor: Color? = {
                #if DEBUG
                // Print for first row (index 0) of EACH field to debug all columns
                if rowIndex == 0 {
                    print("🎨 [COLOR CALC] field='\(field)', value='\(value)'")
                    print("🎨   shouldUseSplunkColors: \(shouldUseSplunkColors)")
                    print("🎨   fieldsWithColorFormat.contains('\(field)'): \(fieldsWithColorFormat.contains(field))")
                    print("🎨   fieldsWithColorFormat = \(fieldsWithColorFormat.sorted())")
                }
                #endif
                
                if shouldUseSplunkColors && fieldsWithColorFormat.contains(field) {
                    if let formatting = vizFormatting {
                        let allColumnValues = results.map { $0[field] }
                        
                        #if DEBUG
                        if rowIndex == 0 {
                            print("🎨   allColumnValues count: \(allColumnValues.count)")
                            print("🎨   rawValue type: \(type(of: rawValue ?? "nil"))")
                            print("🎨   rawValue: \(rawValue ?? "nil")")
                            print("🎨   Calling applyColorFormatting...")
                        }
                        #endif
                        
                        let color = formatting.applyColorFormatting(
                            field: field,
                            value: rawValue ?? value,
                            allValues: allColumnValues
                        )
                        
                        #if DEBUG
                        if rowIndex == 0 {
                            if let actualColor = color {
                                print("🎨   ➜ Result color: ✅ SUCCESS - got a color!")
                            } else {
                                print("🎨   ➜ Result color: ❌ NIL - applyColorFormatting returned nil")
                            }
                        }
                        #endif
                        
                        return color
                    } else {
                        #if DEBUG
                        if rowIndex == 0 {
                            print("🎨   ➜ ❌ No vizFormatting object")
                        }
                        #endif
                    }
                } else {
                    #if DEBUG
                    if rowIndex == 0 {
                        if !shouldUseSplunkColors {
                            print("🎨   ➜ ⚠️ Not in Splunk Default mode")
                        } else if !fieldsWithColorFormat.contains(field) {
                            print("🎨   ➜ ⚠️ Field '\(field)' not in fieldsWithColorFormat")
                            print("🎨   ➜    Available fields with colors: \(fieldsWithColorFormat.sorted())")
                        }
                    }
                    #endif
                }
                return nil
            }()
            
            // Apply highlighting based on style
            if changeInfo.hasChanged {
                switch settings.cellChangeSettings.highlightStyle {
                case .splunkDefault:
                    // Use Splunk formatting only, no change indicators
                    if let splunkColor = splunkBackgroundColor {
                        #if DEBUG
                        if rowIndex == 0 {
                            print("🎨 [CHANGED CELL - SPLUNK DEFAULT] Using Splunk color for '\(field)' ✅")
                        }
                        #endif
                        return splunkColor.opacity(0.7)
                    } else {
                        #if DEBUG
                        if rowIndex == 0 {
                            print("🎨 [CHANGED CELL - SPLUNK DEFAULT] ❌ No Splunk color available for '\(field)', falling through")
                        }
                        #endif
                    }
                    
                case .systemColors, .customColor, .directional:
                    // Show change highlight - NO Splunk color formatting in these modes
                    let baseColor = changeInfo.color
                    let opacity = isAnimating && settings.cellChangeSettings.animateChanges ? 0.8 : settings.cellChangeSettings.fillOpacity
                    return baseColor.opacity(opacity)
                }
            }
            
            // No changes detected
            if shouldUseSplunkColors {
                // In Splunk Default mode, use Splunk formatting for unchanged cells
                if let splunkColor = splunkBackgroundColor {
                    #if DEBUG
                    if rowIndex == 0 {
                        print("🎨 [UNCHANGED CELL - SPLUNK DEFAULT] Using Splunk color for '\(field)' ✅")
                    }
                    #endif
                    return splunkColor.opacity(0.7)
                } else {
                    #if DEBUG
                    if rowIndex == 0 {
                        print("🎨 [UNCHANGED CELL - SPLUNK DEFAULT] ❌ No Splunk color available for '\(field)', falling through to zebra")
                    }
                    #endif
                }
            }
            // In other modes, don't use Splunk colors at all - go straight to zebra striping
            
            // Zebra striping background (lowest priority)
            #if DEBUG
            if rowIndex == 0 {
                print("🎨 [FALLBACK] Using zebra/clear background for '\(field)'")
            }
            #endif
            return rowBackground(for: rowIndex)
        }()
        
        let textColor: Color = {
            // Changed cell text color override
            if changeInfo.hasChanged && settings.tableAppearance.changedCellTextColor != nil {
                return settings.tableAppearance.changedCellTextColor!
            }
            
            // Custom text color
            if let customColor = settings.tableAppearance.customTextColor {
                return customColor
            }
            
            // Default text color
            if value.isEmpty {
                #if os(macOS)
                return Color(nsColor: .tertiaryLabelColor)
                #else
                return Color(uiColor: .tertiaryLabel)
                #endif
            } else {
                #if os(macOS)
                return Color(nsColor: .labelColor)
                #else
                return Color(uiColor: .label)
                #endif
            }
        }()
        
        let baseFont = Font.system(
            size: settings.tableAppearance.fontSize,
            weight: settings.tableAppearance.fontWeight,
            design: settings.tableAppearance.fontDesign
        )
        
        return Text(displayValue)
            .font(settings.tableAppearance.isItalic ? baseFont.italic() : baseFont)
            .foregroundStyle(textColor)
            .frame(minWidth: columnWidths[field] ?? 150, maxWidth: .infinity, minHeight: wrapResults ? 24 : nil, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(backgroundColor)
            .lineLimit(wrapResults ? nil : 3) // Honor wrap setting
            .truncationMode(.tail)
            .help(displayValue)
            .textSelection(.enabled)
            .overlay(
                changeInfo.hasChanged && 
                settings.cellChangeSettings.showOverlay && 
                settings.cellChangeSettings.highlightStyle != .splunkDefault ?
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(changeInfo.color, lineWidth: settings.cellChangeSettings.frameWidth)
                        .padding(2)
                        .opacity(isAnimating && settings.cellChangeSettings.animateChanges ? 1.0 : 0.7)
                : nil
            )
            .id("\(rowIndex)-\(field)-\(value)-\(changeInfo.hasChanged)-\(changeInfo.isIncrease?.description ?? "none")") // Force view recreation when key properties change
            .animation(.easeInOut(duration: settings.cellChangeSettings.animationDuration), value: isAnimating)
    }
    
    // MARK: - Sorting & Column Width
    
    private func loadTablePreferences() {
        let prefs = settings.getTablePreferences(
            dashboardId: execution.dashboardId,
            searchId: execution.searchId
        )
        
        sortField = prefs.sortField
        sortAscending = prefs.sortAscending
        columnWidths = prefs.columnWidths.mapValues { CGFloat($0) }
        preferencesLoaded = true
        
        // Auto-size all columns on first load if no saved widths exist
        // Use dispatch to avoid blocking the main thread
        if columnWidths.isEmpty && !fields.isEmpty {
            print("📏 No saved column widths, auto-sizing all columns...")
            DispatchQueue.main.async {
                for field in self.fields {
                    self.autoSizeColumn(field, savePreference: false)
                }
                // Save the auto-sized widths
                self.saveTablePreferences()
            }
        }
        
        // Apply sorting if we have a sort field
        if sortField != nil {
            applySorting()
        }
        
        print("📊 Loaded table preferences: sort=\(sortField ?? "none"), ascending=\(sortAscending), \(columnWidths.count) column widths")
    }
    
    private func saveTablePreferences() {
        var prefs = TableViewPreferences()
        prefs.sortField = sortField
        prefs.sortAscending = sortAscending
        prefs.columnWidths = columnWidths.mapValues { Double($0) }
        
        settings.setTablePreferences(
            prefs,
            dashboardId: execution.dashboardId,
            searchId: execution.searchId
        )
        
        print("💾 Saved table preferences: sort=\(sortField ?? "none"), ascending=\(sortAscending), \(columnWidths.count) column widths")
    }
    
    private func sortByField(_ field: String) {
        if sortField == field {
            // Toggle sort direction
            sortAscending.toggle()
        } else {
            // New field, default to ascending
            sortField = field
            sortAscending = true
        }
        
        applySorting()
        saveTablePreferences() // Save preference
    }
    
    private func applySorting() {
        guard let field = sortField else { return }
        
        results.sort { row1, row2 in
            let value1 = stringValue(for: field, in: row1)
            let value2 = stringValue(for: field, in: row2)
            
            // Try numeric comparison first
            if let num1 = Double(value1), let num2 = Double(value2) {
                return sortAscending ? num1 < num2 : num1 > num2
            }
            
            // Fall back to string comparison
            return sortAscending ? value1 < value2 : value1 > value2
        }
    }
    
    private func autoSizeColumn(_ field: String, savePreference: Bool = true) {
        // Calculate the content-based width for this column
        var contentWidth: CGFloat = 60 // Lower minimum width for more flexibility
        
        // Measure header text
        let headerWidth = measureText(field, font: .caption, bold: true)
        contentWidth = max(contentWidth, headerWidth + 40) // Add padding for sort indicator
        
        // Measure all values in this column (sample first 50 rows for performance)
        let sampleSize = min(results.count, 50)
        for row in results.prefix(sampleSize) {
            let value = stringValue(for: field, in: row)
            let valueWidth = measureText(value, font: .caption, bold: false)
            contentWidth = max(contentWidth, valueWidth + 30) // Add padding
        }
        
        // Cap at reasonable maximum to prevent one column dominating
        contentWidth = min(contentWidth, 400)
        
        columnWidths[field] = contentWidth
        
        if savePreference {
            saveTablePreferences() // Save preference
            print("📏 Auto-sized column '\(field)' to \(Int(contentWidth))pt")
        }
    }
    
    /// Normalize column widths to fit within available space while respecting content
    private func normalizeColumnWidths(availableWidth: CGFloat) {
        guard !columnWidths.isEmpty, availableWidth > 0 else { return }
        
        // Calculate total natural width
        let totalNaturalWidth = columnWidths.values.reduce(0, +)
        let totalSpacing = CGFloat(max(0, columnWidths.count - 1)) * 16 // Account for spacing between columns
        let rowNumberWidth: CGFloat = showRowNumbers ? 64 : 0
        let effectiveAvailableWidth = availableWidth - totalSpacing - rowNumberWidth - 8 // Minimal padding
        
        guard effectiveAvailableWidth > 0 else { return }
        
        // If natural width fits, we're good
        if totalNaturalWidth <= effectiveAvailableWidth {
            // Distribute extra space proportionally if there's room
            let extraSpace = effectiveAvailableWidth - totalNaturalWidth
            if extraSpace > 50 { // Only distribute if there's significant extra space
                let scaleFactor = effectiveAvailableWidth / totalNaturalWidth
                for field in columnWidths.keys {
                    columnWidths[field] = columnWidths[field]! * scaleFactor
                }
            }
        } else {
            // Scale down proportionally to fit
            let scaleFactor = effectiveAvailableWidth / totalNaturalWidth
            for field in columnWidths.keys {
                let scaledWidth = columnWidths[field]! * scaleFactor
                // Maintain minimum readable width (lower threshold)
                columnWidths[field] = max(scaledWidth, 50)
            }
        }
    }
    
    private func measureText(_ text: String, font: Font, bold: Bool) -> CGFloat {
        #if os(macOS)
        let nsFont: NSFont
        switch font {
        case .caption:
            nsFont = bold ? NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .bold) : NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        default:
            nsFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        }
        
        let attributes: [NSAttributedString.Key: Any] = [.font: nsFont]
        let size = (text as NSString).size(withAttributes: attributes)
        return size.width
        #else
        // iOS fallback - use estimated width
        return CGFloat(text.count) * 8
        #endif
    }
    
    private struct CellChangeInfo {
        let hasChanged: Bool
        let color: Color
        let isIncrease: Bool?
    }
    
    private func cellChangeInfo(field: String, rowIndex: Int) -> CellChangeInfo {
        guard showChanges,
              rowIndex < results.count else {
            return CellChangeInfo(hasChanged: false, color: .clear, isIncrease: nil)
        }
        
        // IMPORTANT: Don't highlight changes in groupby fields (key fields)
        // If a groupby field changes, it's actually a different row, not a change to track
        let keyFields = getRowKeyFields(excludingField: "")
        if keyFields.contains(field) {
            // This is a groupby field - don't highlight as a change
            // New rows with different groupby values will be highlighted as new rows instead
            return CellChangeInfo(hasChanged: false, color: .clear, isIncrease: nil)
        }
        
        let currentRow = results[rowIndex]
        let currentValue = stringValue(for: field, in: currentRow)
        
        // Find matching row in previous results by comparing ALL fields EXCEPT the one we're checking
        let matchingPreviousRow = findMatchingRow(for: currentRow, excludingField: field, in: previousResults)
        
        guard let previousRow = matchingPreviousRow else {
            // No matching row found - this might be a new row
            return CellChangeInfo(hasChanged: false, color: .clear, isIncrease: nil)
        }
        
        let previousValue = stringValue(for: field, in: previousRow)
        let hasChanged = currentValue != previousValue
        
        if !hasChanged {
            return CellChangeInfo(hasChanged: false, color: .clear, isIncrease: nil)
        }
        
        // Determine color based on settings
        let color: Color
        var isIncrease: Bool? = nil
        
        switch settings.cellChangeSettings.highlightStyle {
        case .splunkDefault:
            // No visual change indicator in Splunk Default mode
            color = .clear
        case .systemColors:
            #if os(macOS)
            color = Color(nsColor: .controlAccentColor)
            #else
            color = .accentColor
            #endif
        case .customColor:
            color = settings.cellChangeSettings.customColor
        case .directional:
            // Try to determine if value increased or decreased
            isIncrease = determineDirection(current: currentValue, previous: previousValue)
            if let increase = isIncrease {
                color = increase ? settings.cellChangeSettings.increaseColor : settings.cellChangeSettings.decreaseColor
            } else {
                // Can't determine direction, use default
                color = settings.cellChangeSettings.customColor
            }
        }
        
        return CellChangeInfo(hasChanged: true, color: color, isIncrease: isIncrease)
    }
    
    /// Find a matching row in previous results by creating a stable row signature
    /// This allows us to track the same logical row even if the order changes or values change
    private func findMatchingRow(for currentRow: [String: Any], excludingField: String, in previousResults: [[String: Any]]) -> [String: Any]? {
        // Strategy: Use groupby_rank fields from Splunk metadata if available, otherwise fall back to heuristics
        let keyFields = getRowKeyFields(excludingField: excludingField)
        
        // If we found key fields, use them for matching
        if !keyFields.isEmpty {
            let match = previousResults.first { previousRow in
                keyFields.allSatisfy { field in
                    let currentValue = stringValue(for: field, in: currentRow)
                    let previousValue = stringValue(for: field, in: previousRow)
                    return currentValue == previousValue
                }
            }
            
            return match
        }
        
        // Fallback: If all fields are numeric (unusual but possible), use ALL fields except the one being checked
        let comparisonFields = fields.filter { $0 != excludingField }
        
        guard !comparisonFields.isEmpty else {
            // Single column table - can't match rows
            return nil
        }
        
        // Find a row where all comparison fields match
        return previousResults.first { previousRow in
            comparisonFields.allSatisfy { field in
                let currentValue = stringValue(for: field, in: currentRow)
                let previousValue = stringValue(for: field, in: previousRow)
                return currentValue == previousValue
            }
        }
    }
    
    private func determineDirection(current: String, previous: String) -> Bool? {
        // Try to parse as numbers
        let currentNumber = Double(current)
        let previousNumber = Double(previous)
        
        if let curr = currentNumber, let prev = previousNumber {
            return curr > prev
        }
        
        // Try string comparison for non-numeric values
        return nil
    }
    
    private func loadResults() {
        isLoading = true
        
        print("\n" + String(repeating: "=", count: 80))
        print("🔄 START: Loading results for execution: \(execution.id)")
        print("   Execution status: \(execution.executionStatus)")
        print("   Result count: \(execution.resultCount)")
        print(String(repeating: "-", count: 80))
        
        // Load table display options from CoreData visualization settings
        // Trace: Execution -> SearchEntity -> Panel -> Visualizations
        if let dashboard = CoreDataManager.shared.findDashboard(by: execution.dashboardId) {
            // Find the search entity
            let allSearches = dashboard.allSearches
            if let search = allSearches.first(where: { $0.id == execution.searchId }) {
                print("   🔍 Found search: \(search.id)")
                
                // Get the panel that contains this search
                if let panel = search.panel {
                    print("   🔍 Found panel: \(panel.id)")
                    
                    // Look for table visualization in this panel
                    if let viz = panel.visualizationsArray.first(where: { $0.type == "table" }) {
                        let formatting = VisualizationFormatting(visualization: viz)
                        vizFormatting = formatting
                        wrapResults = formatting.wrapText
                        showRowNumbers = formatting.showRowNumbers
                        displayRowCount = formatting.tableRowCount // Set display row limit
                        
                        // Cache which fields have formatting to optimize rendering
                        fieldsWithNumberFormat = Set(formatting.fieldsWithNumberFormatting)
                        fieldsWithColorFormat = Set(formatting.fieldsWithColorFormatting)
                        
                        print("   📊 Loaded table options: wrap=\(wrapResults), rowNumbers=\(showRowNumbers), displayCount=\(displayRowCount)")
                        print("   🎨 Highlight mode: \(settings.cellChangeSettings.highlightStyle.rawValue)")
                        print("   🎨 Fields with NUMBER formatting: \(fieldsWithNumberFormat.sorted())")
                        print("   🎨 Fields with COLOR formatting: \(fieldsWithColorFormat.sorted())")
                        
                        if settings.cellChangeSettings.highlightStyle == .splunkDefault {
                            print("   🎨 ✅ Splunk Default mode ACTIVE - will apply colors to: \(fieldsWithColorFormat.sorted().joined(separator: ", "))")
                        } else {
                            print("   🎨 ⚠️ NOT in Splunk Default mode - using '\(settings.cellChangeSettings.highlightStyle.rawValue)' instead")
                        }
                    } else {
                        print("   ⚠️ No table visualization found in panel")
                    }
                } else {
                    print("   ⚠️ Search has no panel association")
                }
            } else {
                print("   ⚠️ Could not find search '\(execution.searchId)' in dashboard")
            }
        } else {
            print("   ⚠️ Could not find dashboard '\(execution.dashboardId)'")
        }
        
        // Refresh the execution object from Core Data to ensure we have latest data
        execution.managedObjectContext?.refresh(execution, mergeChanges: true)
        
        // Load current results
        if let splunkResults = execution.results {
            self.fields = splunkResults.fields?.map { $0.name } ?? []
            
            // Extract field metadata including groupby_rank from Splunk
            // This metadata is used to identify key fields for row matching when comparing changes
            self.fieldMetadata = [:]
            if let fieldObjects = splunkResults.fields {
                for field in fieldObjects {
                    var metadata: [String: Any] = [:]
                    metadata["name"] = field.name
                    metadata["type"] = field.type
                    
                    // Extract groupby_rank directly from the FieldInfo struct
                    if let groupbyRank = field.groupbyRank {
                        metadata["groupby_rank"] = groupbyRank
                    }
                    
                    self.fieldMetadata[field.name] = metadata
                }
            }
            
            self.results = splunkResults.results.map { convertToStringDict($0) }
            print("   ✅ Loaded \(self.results.count) results from splunkResults")
            print("   📋 Fields: \(self.fields.joined(separator: ", "))")
        } else {
            // Fallback to individual result records
            let resultRecords = CoreDataManager.shared.getSearchResultRecords(
                executionId: execution.id,
                offset: 0,
                limit: 1000
            )
            
            if !resultRecords.isEmpty {
                if let firstResult = resultRecords.first {
                    self.fields = Array(firstResult.keys).sorted()
                }
                self.results = resultRecords
                print("   ✅ Loaded \(self.results.count) results from result records")
                print("   📋 Fields: \(self.fields.joined(separator: ", "))")
                
                // IMPORTANT: Also extract field metadata from the full results object
                // This ensures groupby_rank is available even when using the Core Data path
                if let fullResults = execution.results,
                   let fieldObjects = fullResults.fields {
                    print("   📊 Extracting metadata from \(fieldObjects.count) fields (Core Data path)...")
                    self.fieldMetadata = [:]
                    for field in fieldObjects {
                        var metadata: [String: Any] = [:]
                        metadata["name"] = field.name
                        metadata["type"] = field.type
                        
                        // Extract groupby_rank directly from the FieldInfo struct
                        if let groupbyRank = field.groupbyRank {
                            metadata["groupby_rank"] = groupbyRank
                            print("      Field '\(field.name)' → groupby_rank: \(groupbyRank) ✅")
                        } else {
                            print("      Field '\(field.name)' → No groupby_rank (type: \(field.type ?? "unknown"))")
                        }
                        
                        self.fieldMetadata[field.name] = metadata
                    }
                }
            } else {
                print("   ⚠️ No results found")
            }
        }
        
        // Load previous results if available
        if let prevExecution = previousExecution {
            prevExecution.managedObjectContext?.refresh(prevExecution, mergeChanges: true)
            
            if let splunkResults = prevExecution.results {
                self.previousResults = splunkResults.results.map { convertToStringDict($0) }
                print("   ✅ Loaded \(self.previousResults.count) previous results")
            } else {
                let resultRecords = CoreDataManager.shared.getSearchResultRecords(
                    executionId: prevExecution.id,
                    offset: 0,
                    limit: 1000
                )
                self.previousResults = resultRecords
                print("   ✅ Loaded \(self.previousResults.count) previous results")
            }
        } else {
            self.previousResults = []
            print("   ⚠️ No previous execution to compare with")
        }
        
        print(String(repeating: "-", count: 80))
        
        // Trigger animations for changed cells
        if settings.cellChangeSettings.animateChanges && showChanges {
            triggerCellAnimations()
        }
        
        print("✅ END: Finished loading results")
        print(String(repeating: "=", count: 80) + "\n")
        
        isLoading = false
    }
    
    private func triggerCellAnimations() {
        // Find all changed cells and new/deleted rows
        var changedCells: Set<String> = []
        var newRows: Set<Int> = []
        
        // Get key fields for row matching
        let keyFields = getRowKeyFields(excludingField: "")
        
        // Detect new rows and changed cells
        for (rowIndex, row) in results.enumerated() {
            // Check if this is a new row
            if !keyFields.isEmpty {
                let currentSignature = rowSignature(for: row, keyFields: keyFields)
                let existsInPrevious = previousResults.contains { previousRow in
                    let prevSignature = rowSignature(for: previousRow, keyFields: keyFields)
                    return currentSignature == prevSignature
                }
                
                if !existsInPrevious {
                    newRows.insert(rowIndex)
                    // For new rows, animate ALL cells
                    for field in fields {
                        let cellKey = "\(rowIndex)-\(field)"
                        changedCells.insert(cellKey)
                    }
                    continue // Skip individual cell checking for new rows
                }
            }
            
            // Check individual cells for changes (for existing rows)
            var rowHasChanges = false
            var rowKeyFieldsMatch = true
            
            for field in fields {
                let currentValue = stringValue(for: field, in: row)
                
                // Find matching previous row
                let matchingPreviousRow = findMatchingRow(for: row, excludingField: field, in: previousResults)
                
                if let previousRow = matchingPreviousRow {
                    let previousValue = stringValue(for: field, in: previousRow)
                    
                    if currentValue != previousValue {
                        let cellKey = "\(rowIndex)-\(field)"
                        changedCells.insert(cellKey)
                        rowHasChanges = true
                        
                        // Check if this is a key field that changed
                        if keyFields.contains(field) {
                            rowKeyFieldsMatch = false
                        }
                    }
                }
            }
            
            // If key fields don't match, it means row identity changed - animate entire row
            if rowHasChanges && !rowKeyFieldsMatch {
                // Add all cells in this row to animation
                for field in fields {
                    let cellKey = "\(rowIndex)-\(field)"
                    changedCells.insert(cellKey)
                }
            }
        }
        
        // Detect deleted rows (rows in previous that aren't in current)
        if !keyFields.isEmpty && !previousResults.isEmpty {
            var deletedSignatures: Set<String> = []
            var foundDeletedRows: [[String: Any]] = []
            
            for previousRow in previousResults {
                let prevSignature = rowSignature(for: previousRow, keyFields: keyFields)
                let existsInCurrent = results.contains { currentRow in
                    let currentSignature = rowSignature(for: currentRow, keyFields: keyFields)
                    return currentSignature == prevSignature
                }
                
                if !existsInCurrent {
                    deletedSignatures.insert(prevSignature)
                    foundDeletedRows.append(previousRow)
                }
            }
            
            if !deletedSignatures.isEmpty {
                self.deletedRowSignatures = deletedSignatures
                self.deletedRows = foundDeletedRows
            }
        }
        
        // Only trigger animation if there are actually changed cells or new rows
        guard !changedCells.isEmpty || !newRows.isEmpty else {
            return
        }
        
        // Important: Clear and set states synchronously
        animatingCells.removeAll()
        newRowIndices.removeAll()
        newRowsAnimating = false
        
        // Set new rows immediately - they will render in "hidden" state
        if !newRows.isEmpty {
            newRowIndices = newRows
            newRowsAnimating = false  // Explicit: start hidden
        }
        
        // Trigger slide-in animation after a delay to ensure initial state renders
        if !newRows.isEmpty || !changedCells.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                // Animate new rows with slide-in (slower, more dramatic)
                if !newRows.isEmpty {
                    withAnimation(.spring(response: 1.0, dampingFraction: 0.6)) {
                        self.newRowsAnimating = true
                    }
                }
                
                // Animate changed cells with glow
                if !changedCells.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut(duration: self.settings.cellChangeSettings.animationDuration * 0.3)) {
                            self.animatingCells = changedCells
                        }
                    }
                }
                
                // Remove animations after duration
                let totalDuration = max(1.5, self.settings.cellChangeSettings.animationDuration)
                DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.animatingCells.removeAll()
                        self.newRowIndices.removeAll()
                        self.newRowsAnimating = false
                    }
                }
            }
        }
    }
    
    private func cellValueChanged(field: String, rowIndex: Int) -> Bool {
        guard showChanges,
              rowIndex < results.count,
              rowIndex < previousResults.count else {
            return false
        }
        
        let currentValue = stringValue(for: field, in: results[rowIndex])
        let previousValue = stringValue(for: field, in: previousResults[rowIndex])
        
        return currentValue != previousValue
    }
    
    private func convertToStringDict(_ dict: [String: Any]) -> [String: Any] {
        // Unwrap AnyCodable values if present
        return dict.mapValues { value in
            // Check if the value has a "value" property (AnyCodable pattern)
            let mirror = Mirror(reflecting: value)
            if let valueProperty = mirror.children.first(where: { $0.label == "value" }) {
                return valueProperty.value
            }
            return value
        }
    }
    
    // MARK: - Field Metadata Helpers
    
    /// Get the key fields for row matching based on groupby_rank metadata
    /// Falls back to heuristic-based detection if metadata is not available
    private func getRowKeyFields(excludingField: String) -> [String] {
        // First, try to use groupby_rank from field metadata
        let rankedFields = fields.compactMap { field -> (field: String, rank: Int)? in
            guard field != excludingField else { return nil }
            guard let metadata = fieldMetadata[field] else { return nil }
            
            if let rankString = metadata["groupby_rank"] as? String,
               let rank = Int(rankString) {
                return (field: field, rank: rank)
            }
            return nil
        }
        
        // If we found ranked fields, use them sorted by rank
        if !rankedFields.isEmpty {
            let sortedFields = rankedFields.sorted { $0.rank < $1.rank }.map { $0.field }
            return sortedFields
        }
        
        // Fallback to heuristic: non-numeric fields are likely keys
        let heuristicKeys = fields.filter { field in
            guard field != excludingField else { return false }
            
            // Sample the first row to determine if numeric
            guard let firstRow = results.first else { return false }
            let value = stringValue(for: field, in: firstRow)
            
            // If it's numeric, it's probably a metric that changes
            return Double(value) == nil
        }
        
        return heuristicKeys
    }
    
    /// Create a signature for a row based on its key fields
    private func rowSignature(for row: [String: Any], keyFields: [String]) -> String {
        return keyFields.map { field in
            "\(field)=\(stringValue(for: field, in: row))"
        }.joined(separator: "|")
    }
    
    /// Detect if a row is new by checking if it exists in previous results
    private func isNewRow(at index: Int) -> Bool {
        guard index < results.count else { return false }
        let currentRow = results[index]
        
        let keyFields = getRowKeyFields(excludingField: "")
        guard !keyFields.isEmpty else { return false }
        
        // Check if this row's signature exists in previous results
        let signature = rowSignature(for: currentRow, keyFields: keyFields)
        let existsInPrevious = previousResults.contains { previousRow in
            let prevSignature = rowSignature(for: previousRow, keyFields: keyFields)
            return signature == prevSignature
        }
        
        return !existsInPrevious
    }
    
    private func stringValue(for field: String, in row: [String: Any]) -> String {
        guard let value = row[field] else {
            return ""
        }
        
        // Handle different value types
        if let stringValue = value as? String {
            return stringValue
        } else if let numberValue = value as? NSNumber {
            return numberValue.stringValue
        } else if let arrayValue = value as? [Any] {
            return "[\(arrayValue.count) items]"
        } else if let dictValue = value as? [String: Any] {
            return "{\(dictValue.count) fields}"
        } else {
            return String(describing: value)
        }
    }
}

// MARK: - Dashboard Settings View

struct DashboardSettingsView: View {
    @StateObject private var settings = DashboardMonitorSettings.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Configure how cell changes are highlighted in search results")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Label("Cell Change Display", systemImage: "paintbrush.fill")
                }
                
                Section {
                    Picker("Highlight Style", selection: $settings.cellChangeSettings.highlightStyle) {
                        ForEach(CellChangeSettings.HighlightStyle.allCases) { style in
                            VStack(alignment: .leading) {
                                Text(style.rawValue)
                                Text(style.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(style)
                        }
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text("Style")
                }
                
                if settings.cellChangeSettings.highlightStyle != .splunkDefault {
                    Section {
                        if settings.cellChangeSettings.highlightStyle == .customColor {
                            ColorPicker("Custom Color", selection: $settings.cellChangeSettings.customColor)
                        }
                        
                        if settings.cellChangeSettings.highlightStyle == .directional {
                            ColorPicker("Increase Color", selection: $settings.cellChangeSettings.increaseColor)
                            ColorPicker("Decrease Color", selection: $settings.cellChangeSettings.decreaseColor)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Fill Opacity")
                                Spacer()
                                Text("\(Int(settings.cellChangeSettings.fillOpacity * 100))%")
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $settings.cellChangeSettings.fillOpacity, in: 0.1...1.0, step: 0.05)
                        }
                        
                        Toggle("Show Frame Overlay", isOn: $settings.cellChangeSettings.showOverlay)
                        
                        if settings.cellChangeSettings.showOverlay {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Frame Width")
                                    Spacer()
                                    Text("\(Int(settings.cellChangeSettings.frameWidth))pt")
                                        .foregroundStyle(.secondary)
                                }
                                Slider(value: $settings.cellChangeSettings.frameWidth, in: 1...4, step: 0.5)
                            }
                        }
                    } header: {
                        Text("Appearance")
                    }
                    
                    Section {
                        Toggle("Glow and Fade Animation", isOn: $settings.cellChangeSettings.animateChanges)
                        
                        if settings.cellChangeSettings.animateChanges {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Animation Duration")
                                    Spacer()
                                    Text(String(format: "%.1fs", settings.cellChangeSettings.animationDuration))
                                        .foregroundStyle(.secondary)
                                }
                                Slider(value: $settings.cellChangeSettings.animationDuration, in: 0.5...3.0, step: 0.1)
                            }
                        }
                    } header: {
                        Text("Animation")
                    } footer: {
                        Text("Cells will glow when changes are detected, then fade to the configured opacity")
                            .font(.caption)
                    }
                    
                    Section {
                        previewSection
                    } header: {
                        Text("Preview")
                    }
                }
                
                // Table Appearance Section
                Section {
                    // Font Design Picker
                    Picker("Font", selection: $settings.tableAppearance.fontDesign) {
                        Text("Default").tag(Font.Design.default)
                        Text("Serif").tag(Font.Design.serif)
                        Text("Rounded").tag(Font.Design.rounded)
                        Text("Monospaced").tag(Font.Design.monospaced)
                    }
                    
                    // Font Size Slider
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Font Size")
                            Spacer()
                            Text("\(Int(settings.tableAppearance.fontSize))pt")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $settings.tableAppearance.fontSize, in: 9...24, step: 1)
                    }
                    
                    // Font Weight Picker
                    Picker("Weight", selection: $settings.tableAppearance.fontWeight) {
                        Text("Ultralight").tag(Font.Weight.ultraLight)
                        Text("Thin").tag(Font.Weight.thin)
                        Text("Light").tag(Font.Weight.light)
                        Text("Regular").tag(Font.Weight.regular)
                        Text("Medium").tag(Font.Weight.medium)
                        Text("Semibold").tag(Font.Weight.semibold)
                        Text("Bold").tag(Font.Weight.bold)
                        Text("Heavy").tag(Font.Weight.heavy)
                        Text("Black").tag(Font.Weight.black)
                    }
                    
                    // Italic Toggle
                    Toggle("Italic", isOn: $settings.tableAppearance.isItalic)
                    
                } header: {
                    Label("Table Appearance", systemImage: "tablecells")
                }
                
                // Text & Cell Options (grouped together)
                Section {
                    // Text color options
                    HStack {
                        Text("Text Color")
                        Spacer()
                        if settings.tableAppearance.customTextColor != nil {
                            Button("Reset") {
                                settings.tableAppearance.customTextColor = nil
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                        }
                    }
                    
                    if let textColor = Binding(
                        get: { settings.tableAppearance.customTextColor ?? .primary },
                        set: { settings.tableAppearance.customTextColor = $0 }
                    ) as Binding<Color>? {
                        ColorPicker("", selection: textColor, supportsOpacity: false)
                            .labelsHidden()
                            .disabled(settings.tableAppearance.customTextColor == nil)
                    }
                    
                    Toggle(settings.tableAppearance.customTextColor == nil ? "Use Custom Text Color" : "Using Custom Text Color",
                           isOn: Binding(
                        get: { settings.tableAppearance.customTextColor != nil },
                        set: { enabled in
                            if enabled {
                                settings.tableAppearance.customTextColor = .primary
                            } else {
                                settings.tableAppearance.customTextColor = nil
                            }
                        }
                    ))
                    
                    Divider()
                    
                    // Changed cell text color
                    HStack {
                        Text("Changed Cell Text Color")
                        Spacer()
                        if settings.tableAppearance.changedCellTextColor != nil {
                            Button("Reset") {
                                settings.tableAppearance.changedCellTextColor = nil
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                        }
                    }
                    
                    if let changedTextColor = Binding(
                        get: { settings.tableAppearance.changedCellTextColor ?? .orange },
                        set: { settings.tableAppearance.changedCellTextColor = $0 }
                    ) as Binding<Color>? {
                        ColorPicker("", selection: changedTextColor, supportsOpacity: false)
                            .labelsHidden()
                            .disabled(settings.tableAppearance.changedCellTextColor == nil)
                    }
                    
                    Toggle(settings.tableAppearance.changedCellTextColor == nil ? "Use Custom Changed Text Color" : "Using Custom Changed Text Color",
                           isOn: Binding(
                        get: { settings.tableAppearance.changedCellTextColor != nil },
                        set: { enabled in
                            if enabled {
                                settings.tableAppearance.changedCellTextColor = .orange
                            } else {
                                settings.tableAppearance.changedCellTextColor = nil
                            }
                        }
                    ))
                    
                    Divider()
                    
                    // Cell background
                    Toggle("Custom Cell Background", isOn: $settings.tableAppearance.useCustomCellBackground)
                    
                    if settings.tableAppearance.useCustomCellBackground {
                        ColorPicker("Background Color", selection: $settings.tableAppearance.customCellBackgroundColor, supportsOpacity: false)
                    }
                }
                
                // Zebra Striping (separate section as requested)
                Section {
                    Toggle("Zebra Striping", isOn: $settings.tableAppearance.enableZebraStriping)
                    
                    if settings.tableAppearance.enableZebraStriping {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Stripe Opacity")
                                Spacer()
                                Text("\(Int(settings.tableAppearance.zebraStripeOpacity * 100))%")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            Slider(value: $settings.tableAppearance.zebraStripeOpacity, in: 0.01...0.5, step: 0.01)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Dashboard Settings")
            #if os(macOS)
            .frame(minWidth: 500, minHeight: 600)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        settings.loadSettings()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        settings.saveSettings()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var previewSection: some View {
        VStack(spacing: 12) {
            Text("Preview of highlighted cells:")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 20) {
                previewCell(label: "Changed", isIncrease: nil)
                
                if settings.cellChangeSettings.highlightStyle == .directional {
                    previewCell(label: "Increased", isIncrease: true)
                    previewCell(label: "Decreased", isIncrease: false)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func previewCell(label: String, isIncrease: Bool?) -> some View {
        let color = cellColor(isIncrease: isIncrease)
        
        return Text(label)
            .font(.caption)
            .padding(8)
            .frame(minWidth: 100)
            .background(color.opacity(settings.cellChangeSettings.fillOpacity))
            .overlay(
                settings.cellChangeSettings.showOverlay ?
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(color, lineWidth: settings.cellChangeSettings.frameWidth)
                        .padding(2)
                : nil
            )
            .cornerRadius(4)
    }
    
    private func cellColor(isIncrease: Bool?) -> Color {
        switch settings.cellChangeSettings.highlightStyle {
        case .splunkDefault:
            return .clear
        case .systemColors:
            #if os(macOS)
            return Color(nsColor: .controlAccentColor)
            #else
            return .accentColor
            #endif
        case .customColor:
            return settings.cellChangeSettings.customColor
        case .directional:
            if let isIncrease = isIncrease {
                return isIncrease ? settings.cellChangeSettings.increaseColor : settings.cellChangeSettings.decreaseColor
            }
            return settings.cellChangeSettings.customColor
        }
    }
}

// MARK: - Preview

#if DEBUG
struct DashboardMonitorView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardMonitorView()
            .environment(\.managedObjectContext, CoreDataManager.shared.context)
    }
}
#endif

// MARK: - Array Extension for Safe Access

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

#endif

