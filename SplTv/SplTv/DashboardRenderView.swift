import SwiftUI
import CoreData
import DashboardKit

#if os(macOS) || os(tvOS)

/// Renders the actual dashboard layout from CoreData configuration
/// Shows rows, panels, and visualizations in their configured layout
public struct DashboardRenderView: View {
    
    // MARK: - Environment
    @Environment(\.managedObjectContext) private var viewContext
    
    // MARK: - Properties
    let dashboard: DashboardEntity
    
    // MARK: - State
    @State private var selectedPanelId: String?
    @State private var showGlobalTimeline: Bool = false
    
    // MARK: - Initialization
    public init(dashboard: DashboardEntity) {
        self.dashboard = dashboard
    }
    
    // MARK: - Body
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Dashboard Header
                dashboardHeader
                
                Divider()
                
                // Global Timeline Control (optional)
                if showGlobalTimeline {
                    globalTimelineControl
                    Divider()
                }
                
                // Dashboard Rows
                ForEach(dashboard.rowsArray, id: \.id) { row in
                    DashboardMainRowView(row: row, selectedPanelId: $selectedPanelId, showTimeline: $showGlobalTimeline)
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle(dashboard.title ?? "Dashboard")
    }
    
    // MARK: - Dashboard Header
    
    private var dashboardHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title and Timeline Toggle
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dashboard.title ?? dashboard.id)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    // Description
                    if let description = dashboard.dashboardDescription, !description.isEmpty {
                        Text(description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Global Timeline Toggle
                Button {
                    showGlobalTimeline.toggle()
                } label: {
                    Label(showGlobalTimeline ? "Hide Timeline" : "Show Timeline",
                          systemImage: showGlobalTimeline ? "clock.fill" : "clock")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .help("Toggle global execution timeline for all searches")
            }
            
            // Metadata
            HStack(spacing: 16) {
                if let appName = dashboard.appName {
                    Label(appName, systemImage: "app")
                        .font(.caption)
                }
                
                Label("\(dashboard.rowsArray.count) rows", systemImage: "rectangle.split.3x1")
                    .font(.caption)
                
                let totalPanels = dashboard.rowsArray.reduce(0) { $0 + $1.panelsArray.count }
                Label("\(totalPanels) panels", systemImage: "square.grid.2x2")
                    .font(.caption)
                
                let totalSearches = dashboard.rowsArray.flatMap { $0.panelsArray }.flatMap { $0.searchesArray }.count
                if totalSearches > 0 {
                    Label("\(totalSearches) searches", systemImage: "magnifyingglass")
                        .font(.caption)
                }
            }
            .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Global Timeline Control
    
    private var globalTimelineControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Global Execution Timeline")
                .font(.headline)
            
            Text("Timeline controls for all searches will appear here")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            // TODO: Implement global timeline view that shows all executions
            // This would need to aggregate executions from all searches
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Dashboard Row View

struct DashboardMainRowView: View {
    let row: RowEntity
    @Binding var selectedPanelId: String?
    @Binding var showTimeline: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Row Header
            HStack {
                Label("Row \(row.orderIndex + 1)", systemImage: "rectangle.split.3x1")
                    .font(.headline)
                
                if let xmlId = row.xmlId {
                    Text("ID: \(xmlId)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text("\(row.panelsArray.count) panels")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Row dependencies/constraints
            if let depends = row.depends, !depends.isEmpty {
                Label("Depends on: \(depends)", systemImage: "link")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            
            // Panels in this row - Bootstrap-like grid layout
            #if os(macOS)
            BootstrapGridLayout(spacing: 16) {
                ForEach(Array(row.panelsArray.enumerated()), id: \.element.id) { index, panel in
                    DashboardPanelView(panel: panel, isSelected: selectedPanelId == panel.id, hideTimeline: !showTimeline)
                        .frame(maxWidth: .infinity)
                        .gridColumnWidth(panel.bootstrapColumnWidth(totalPanelsInRow: row.panelsArray.count))
                        .onTapGesture {
                            selectedPanelId = panel.id
                        }
                }
            }
            #else
            // tvOS uses vertical stack for better focus management
            VStack(spacing: 16) {
                ForEach(row.panelsArray, id: \.id) { panel in
                    DashboardPanelView(panel: panel, isSelected: selectedPanelId == panel.id, hideTimeline: !showTimeline)
                        .onTapGesture {
                            selectedPanelId = panel.id
                        }
                }
            }
            #endif
        }
        .padding()
        .background(rowBackground)
        .cornerRadius(12)
    }
    
    private var rowBackground: some View {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemBackground)
        #endif
    }
}

// MARK: - Bootstrap Grid Layout

/// A custom layout that mimics Bootstrap's 12-column grid system
/// Panels specify their width as a percentage or column count
struct BootstrapGridLayout: Layout {
    var spacing: CGFloat = 16
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 1000
        let rows = computeRows(subviews: subviews, availableWidth: width)
        
        var totalHeight: CGFloat = 0
        for (rowIndex, row) in rows.enumerated() {
            let maxHeight = row.map { $0.view.sizeThatFits(.unspecified).height }.max() ?? 0
            totalHeight += maxHeight
            if rowIndex < rows.count - 1 {
                totalHeight += spacing
            }
        }
        
        return CGSize(width: width, height: totalHeight)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(subviews: subviews, availableWidth: bounds.width)
        
        var yOffset = bounds.minY
        
        for row in rows {
            // Calculate total column span for this row
            let totalColumns = row.reduce(0.0) { $0 + $1.columns }
            
            // Calculate actual widths based on available space
            let availableWidth = bounds.width - (spacing * CGFloat(row.count - 1))
            
            var xOffset = bounds.minX
            var maxHeight: CGFloat = 0
            
            for item in row {
                // Calculate proportional width
                let itemWidth = (availableWidth * item.columns / totalColumns)
                
                let proposal = ProposedViewSize(width: itemWidth, height: nil)
                let size = item.view.sizeThatFits(proposal)
                
                item.view.place(
                    at: CGPoint(x: xOffset, y: yOffset),
                    proposal: proposal
                )
                
                xOffset += itemWidth + spacing
                maxHeight = max(maxHeight, size.height)
            }
            
            yOffset += maxHeight + spacing
        }
    }
    
    /// Compute rows of panels based on Bootstrap column widths (12-column grid)
    private func computeRows(subviews: Subviews, availableWidth: CGFloat) -> [[RowItem]] {
        var rows: [[RowItem]] = []
        var currentRow: [RowItem] = []
        var currentRowColumns: CGFloat = 0
        
        for subview in subviews {
            let columnWidth = subview[GridColumnWidthKey.self]
            
            // If adding this panel would exceed 12 columns, start a new row
            if !currentRow.isEmpty && currentRowColumns + columnWidth > 12 {
                rows.append(currentRow)
                currentRow = []
                currentRowColumns = 0
            }
            
            currentRow.append(RowItem(view: subview, columns: columnWidth))
            currentRowColumns += columnWidth
        }
        
        if !currentRow.isEmpty {
            rows.append(currentRow)
        }
        
        return rows
    }
    
    struct RowItem {
        let view: LayoutSubview
        let columns: CGFloat
    }
}

// MARK: - Bootstrap Grid Column Width Key

private struct GridColumnWidthKey: LayoutValueKey {
    static let defaultValue: CGFloat = 12 // Full width by default
}

extension View {
    /// Specify the Bootstrap-style column width (out of 12 columns)
    func gridColumnWidth(_ width: CGFloat) -> some View {
        layoutValue(key: GridColumnWidthKey.self, value: width)
    }
}

// MARK: - PanelEntity Extension for Bootstrap Width

extension PanelEntity {
    /// Parse the panel's width property and convert to Bootstrap columns (0-12)
    /// If width is not set, intelligently defaults based on number of panels in the row
    func bootstrapColumnWidth(totalPanelsInRow: Int) -> CGFloat {
        // First, try to parse explicit width if it exists
        if let width = self.width, !width.isEmpty {
            // Handle percentage widths (e.g., "50%")
            if width.hasSuffix("%") {
                let percentString = width.dropLast()
                if let percent = Double(percentString) {
                    return CGFloat(percent / 100.0 * 12.0)
                }
            }
            
            // Handle explicit column counts (e.g., "6")
            if let columns = Double(width) {
                return min(CGFloat(columns), 12)
            }
        }
        
        // No width specified - use Bootstrap-like intelligent defaults
        // based on number of panels in the row
        switch totalPanelsInRow {
        case 1:
            // Single panel = full width (col-12)
            return 12
        case 2:
            // Two panels = half width each (col-6)
            return 6
        case 3:
            // Three panels = third width each (col-4)
            return 4
        case 4:
            // Four panels = quarter width each (col-3)
            return 3
        case 6:
            // Six panels = sixth width each (col-2)
            return 2
        default:
            // For other counts (5, 7-12), distribute evenly
            // Round to nearest Bootstrap column size
            let evenWidth = 12.0 / CGFloat(totalPanelsInRow)
            
            // Round to nearest valid Bootstrap column (1, 2, 3, 4, 6, or 12)
            let validColumns: [CGFloat] = [1, 2, 3, 4, 6, 12]
            let nearest = validColumns.min(by: { abs($0 - evenWidth) < abs($1 - evenWidth) }) ?? 12
            return nearest
        }
    }
}

// MARK: - Dashboard Panel View

struct DashboardPanelView: View {
    let panel: PanelEntity
    let isSelected: Bool
    let hideTimeline: Bool
    
    @State private var showResults: Bool = true // Show results by default
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Panel Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let title = panel.title {
                        Text(title)
                            .font(.headline)
                    } else {
                        Text("Panel \(panel.orderIndex + 1)")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let xmlId = panel.xmlId {
                        Text(xmlId)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Action buttons (icon-only with tooltips)
                HStack(spacing: 6) {
                    // Toggle to show/hide results table
                    if !panel.searchesArray.isEmpty {
                        Button {
                            showResults.toggle()
                        } label: {
                            Image(systemName: showResults ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.bordered)
                        .help(showResults ? "Hide results table" : "Show results table")
                    }
                    
                    // Panel dimensions if specified
                    if let width = panel.width, !width.isEmpty {
                        Text("W: \(width)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Panel Content (inputs only, if any)
            if !panel.inputsArray.isEmpty {
                Divider()
                panelContent
            }
            
            // Search Results Table (collapsible) - replaces search badges
            if showResults && !panel.searchesArray.isEmpty {
                Divider()
                searchResultsSection
            }
        }
        .padding()
        .background(panelBackground)
        .overlay(panelBorder)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var panelContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Panel-level inputs (if any) - shown contextually
            if !panel.inputsArray.isEmpty {
                panelInputsSection
            }
            
            // Visualizations section removed - we'll show results directly
        }
    }
    
    // MARK: - Panel Inputs Section
    
    private var panelInputsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(.purple)
                    .imageScale(.small)
                
                Text("Panel Inputs")
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(panel.inputsArray.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.15))
                    .cornerRadius(4)
            }
            
            // Show compact list of panel inputs
            ForEach(panel.inputsArray.prefix(3), id: \.name) { token in
                HStack(spacing: 4) {
                    Image(systemName: tokenIcon(for: token.tokenType))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                    
                    Text(token.label ?? token.name)
                        .font(.caption)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(token.tokenType.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Show "and X more" if there are more inputs
            if panel.inputsArray.count > 3 {
                Text("and \(panel.inputsArray.count - 3) more...")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
        .padding(8)
        .background(Color.purple.opacity(0.05))
        .cornerRadius(6)
    }
    
    // MARK: - Token Icon Helper
    
    private func tokenIcon(for type: CoreDataTokenType) -> String {
        switch type {
        case .text:
            return "textformat"
        case .dropdown, .link:
            return "list.bullet"
        case .time:
            return "clock"
        case .radio:
            return "circle"
        case .checkbox:
            return "checkmark.square"
        case .multiselect:
            return "list.bullet.rectangle"
        case .calculated:
            return "function"
        case .timeComponent:
            return "clock.badge.questionmark"
        case .undefined:
            return "questionmark.circle"
        }
    }
    
    // MARK: - Search Results Section
    
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Compact results table (timeline hidden unless global toggle is on)
            if let firstSearch = panel.searchesArray.first,
               let dashboardId = panel.row?.dashboard?.id {
                CompactSearchResultsView(
                    dashboardId: dashboardId,
                    searchId: firstSearch.id,
                    showTimeline: !hideTimeline
                )
                .frame(minHeight: 300, maxHeight: 600)
                .frame(maxWidth: .infinity) // Fill panel width
                .id("\(dashboardId)-\(firstSearch.id)")
            } else {
                Text("No search results available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            }
        }
        .frame(maxWidth: .infinity) // Ensure section fills width
        .padding(12)
        .background(Color.blue.opacity(0.03))
        .cornerRadius(8)
    }
    
    private var panelBackground: some View {
        #if os(macOS)
        Color(nsColor: .textBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }
    
    private var panelBorder: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
    }
}

// MARK: - Compact Search Results View

/// Wrapper around SearchResultsTableView that optionally hides the timeline
struct CompactSearchResultsView: View {
    let dashboardId: String
    let searchId: String
    let showTimeline: Bool

    @Environment(\.managedObjectContext) private var viewContext
    @State private var executions: [SearchExecution] = []
    @State private var dataSourceUUID: UUID?
    @State private var hasTablePreferences: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Minimal execution info header (if timeline hidden)
            if !showTimeline {
                HStack(spacing: 8) {
                    if let latest = executions.first {
                        // Status indicator
                        Circle()
                            .fill(statusColor(latest))
                            .frame(width: 6, height: 6)

                        // Row count
                        Text("\(latest.resultCount) rows")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        // Timestamp
                        if let startTime = latest.startTime {
                            Text(startTime, formatter: timeFormatter)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        // Execution duration (if available)
                        if let endTime = latest.endTime, let startTime = latest.startTime {
                            let duration = endTime.timeIntervalSince(startTime)
                            Text("•")
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            Text(String(format: "%.2fs", duration))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("No executions")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    // Reset table preferences button (icon-only)
                    if hasTablePreferences {
                        Button {
                            resetTablePreferences()
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                        }
                        .buttonStyle(.borderless)
                        .help("Reset table sorting and column widths")
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
            }
            
            // Full SearchResultsTableView (will show/hide its timeline based on parent state)
            if showTimeline, let dsUUID = dataSourceUUID, let dbUUID = UUID(uuidString: dashboardId) {
                SearchResultsTableView(
                    dashboardId: dbUUID,
                    dataSourceId: dsUUID
                )
                .frame(maxWidth: .infinity) // Fill available width
            } else {
                // Just show the results table directly
                if let execution = executions.first {
                    let currentIndex = 0
                    let hasPrevious = executions.count > 1

                    if hasPrevious {
                        let previousExecution = executions[1]
                        ResultsTableContent(
                            execution: execution,
                            previousExecution: previousExecution,
                            showChanges: true
                        )
                        .frame(maxWidth: .infinity) // Fill available width
                    } else {
                        ResultsTableContent(
                            execution: execution,
                            previousExecution: nil,
                            showChanges: false
                        )
                        .frame(maxWidth: .infinity) // Fill available width
                    }
                } else if let latest = executions.first {
                    // Auto-select latest
                    ResultsTableContent(
                        execution: latest,
                        previousExecution: executions.count > 1 ? executions[1] : nil,
                        showChanges: executions.count > 1
                    )
                    .frame(maxWidth: .infinity) // Fill available width
                }
            }
        }
        .frame(maxWidth: .infinity) // Ensure container fills width
        .onAppear {
            loadExecutions()
        }
    }
    
    private func loadExecutions() {
        // First, find the DataSource UUID from sourceId
        let dsRequest: NSFetchRequest<DataSource> = DataSource.fetchRequest()
        dsRequest.predicate = NSPredicate(
            format: "sourceId == %@ AND dashboard.id == %@",
            searchId,
            UUID(uuidString: dashboardId) as CVarArg? ?? UUID() as CVarArg
        )
        dsRequest.fetchLimit = 1

        do {
            if let dataSource = try viewContext.fetch(dsRequest).first,
               let dsUUID = dataSource.id {
                dataSourceUUID = dsUUID

                // Now fetch executions for this dataSource
                let request: NSFetchRequest<SearchExecution> = SearchExecution.fetchRequest()
                request.predicate = NSPredicate(
                    format: "dataSource.id == %@",
                    dsUUID as CVarArg
                )
                request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]
                request.fetchLimit = 10

                executions = try viewContext.fetch(request)

                // Check if table preferences exist
                checkTablePreferences()
            } else {
                print("⚠️ DataSource not found for searchId: \(searchId)")
                executions = []
            }
        } catch {
            print("❌ Error loading executions: \(error)")
            executions = []
        }
    }
    
    private func checkTablePreferences() {
        let prefs = DashboardMonitorSettings.shared.getTablePreferences(
            dashboardId: dashboardId,
            searchId: searchId
        )
        hasTablePreferences = prefs.sortField != nil || !prefs.columnWidths.isEmpty
    }
    
    private func resetTablePreferences() {
        DashboardMonitorSettings.shared.clearTablePreferences(
            dashboardId: dashboardId,
            searchId: searchId
        )
        hasTablePreferences = false
        // Force reload of executions to trigger table refresh
        loadExecutions()
    }
    
    private func statusColor(_ execution: SearchExecution) -> Color {
        switch execution.status {
        case "completed": return .green
        case "running": return .blue
        case "failed": return .red
        case "pending": return .orange
        case "cancelled": return .gray
        default: return .gray
        }
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }
}

// MARK: - Preview

#if DEBUG
struct DashboardRenderView_Previews: PreviewProvider {
    static var previews: some View {
        if let dashboard = CoreDataManager.shared.fetchAllDashboards().first {
            NavigationStack {
                DashboardRenderView(dashboard: dashboard)
            }
            .environment(\.managedObjectContext, CoreDataManager.shared.context)
        } else {
            Text("No dashboards available")
        }
    }
}
#endif

#endif
