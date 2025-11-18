import SwiftUI
import CoreData
import DashboardKit

#if os(macOS) || os(tvOS)

/// Renders Dashboard Studio dashboards using DashboardKit entities
/// Displays layout, visualizations, and data sources in their configured positions
public struct DashboardStudioRenderView: View {

    // MARK: - Environment
    @Environment(\.managedObjectContext) private var viewContext

    // MARK: - Properties
    let dashboard: Dashboard

    // MARK: - State
    @State private var selectedItemId: UUID?
    @State private var showGlobalTimeline: Bool = false

    // MARK: - Initialization
    public init(dashboard: Dashboard) {
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

                // Dashboard Layout Content
                if let layout = dashboard.layout {
                    layoutContent(layout)
                } else {
                    noLayoutView
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
                    Text(dashboard.title ?? "Untitled Dashboard")
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
                .help("Toggle global execution timeline for all data sources")
            }

            // Metadata
            HStack(spacing: 16) {
                // Format type
                if let formatType = dashboard.formatType {
                    Label(formatType, systemImage: "doc.text")
                        .font(.caption)
                }

                // Data sources count
                let dataSourceCount = dashboard.dataSources?.count ?? 0
                if dataSourceCount > 0 {
                    Label("\(dataSourceCount) data sources", systemImage: "cylinder")
                        .font(.caption)
                }

                // Visualizations count
                let vizCount = dashboard.visualizations?.count ?? 0
                if vizCount > 0 {
                    Label("\(vizCount) visualizations", systemImage: "chart.bar")
                        .font(.caption)
                }

                // Inputs count
                let inputCount = dashboard.inputs?.count ?? 0
                if inputCount > 0 {
                    Label("\(inputCount) inputs", systemImage: "slider.horizontal.3")
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

            Text("Timeline controls for all data sources will appear here")
                .font(.caption)
                .foregroundStyle(.secondary)

            // TODO: Implement global timeline view that shows all executions
            // This would need to aggregate executions from all data sources
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Layout Content

    @ViewBuilder
    private func layoutContent(_ layout: DashboardLayout) -> some View {
        let items = (layout.layoutItems?.allObjects as? [LayoutItem]) ?? []
        let sortedItems = items.sorted { ($0.position, $0.y, $0.x) < ($1.position, $1.y, $1.x) }

        let layoutType = layout.type ?? "bootstrap"

        switch layoutType {
        case "bootstrap":
            bootstrapLayout(items: sortedItems)
        case "absolute":
            absoluteLayout(items: sortedItems)
        case "grid":
            gridLayout(items: sortedItems)
        default:
            // Default to bootstrap if unknown type
            bootstrapLayout(items: sortedItems)
        }
    }

    // MARK: - Bootstrap Layout (12-column grid)

    @ViewBuilder
    private func bootstrapLayout(items: [LayoutItem]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Group items by row (using y-coordinate or sequential position)
            let rows = groupItemsIntoRows(items)

            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                VStack(alignment: .leading, spacing: 8) {
                    // Row header
                    Text("Row \(index + 1)")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    // Row content using Bootstrap-style grid
                    #if os(macOS)
                    BootstrapGridLayout(spacing: 16) {
                        ForEach(row, id: \.id) { item in
                            layoutItemView(item)
                                .gridColumnWidth(parseBootstrapWidth(item.bootstrapWidth))
                        }
                    }
                    #else
                    // tvOS uses vertical stack for better focus management
                    VStack(spacing: 16) {
                        ForEach(row, id: \.id) { item in
                            layoutItemView(item)
                        }
                    }
                    #endif
                }
                .padding()
                .background(rowBackground)
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Absolute Layout (pixel positioning)

    @ViewBuilder
    private func absoluteLayout(items: [LayoutItem]) -> some View {
        // Use ZStack for absolute positioning
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                ForEach(items, id: \.id) { item in
                    layoutItemView(item)
                        .frame(
                            width: CGFloat(item.width),
                            height: CGFloat(item.height)
                        )
                        .position(
                            x: CGFloat(item.x) + CGFloat(item.width) / 2,
                            y: CGFloat(item.y) + CGFloat(item.height) / 2
                        )
                }
            }
        }
        .frame(minHeight: 800) // Provide minimum height for positioning
    }

    // MARK: - Grid Layout (auto-layout)

    @ViewBuilder
    private func gridLayout(items: [LayoutItem]) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 300, maximum: 600), spacing: 16)
            ],
            spacing: 16
        ) {
            ForEach(items, id: \.id) { item in
                layoutItemView(item)
            }
        }
    }

    // MARK: - Layout Item View

    @ViewBuilder
    private func layoutItemView(_ item: LayoutItem) -> some View {
        let isSelected = selectedItemId == item.id

        switch item.type {
        case "block":
            // Visualization block
            if let visualization = item.visualization {
                VisualizationItemView(
                    visualization: visualization,
                    dashboardId: dashboard.id,
                    isSelected: isSelected,
                    showTimeline: showGlobalTimeline
                )
                .onTapGesture {
                    selectedItemId = item.id
                }
            } else {
                placeholderView(type: "Visualization")
            }

        case "input":
            // Input control
            if let input = item.input {
                InputItemView(input: input)
            } else {
                placeholderView(type: "Input")
            }

        default:
            placeholderView(type: "Unknown (\(item.type ?? "nil"))")
        }
    }

    // MARK: - Placeholder View

    private func placeholderView(type: String) -> some View {
        VStack {
            Image(systemName: "questionmark.square.dashed")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("\(type) Not Found")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - No Layout View

    private var noLayoutView: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.3.group")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Layout Configured")
                .font(.headline)

            Text("This dashboard doesn't have a layout defined yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    // MARK: - Helper Functions

    /// Group layout items into rows based on y-coordinate or sequential position
    private func groupItemsIntoRows(_ items: [LayoutItem]) -> [[LayoutItem]] {
        var rows: [[LayoutItem]] = []
        var currentRow: [LayoutItem] = []
        var currentY: Int32 = -1

        for item in items {
            // If y-coordinate changes significantly (or first item), start new row
            if currentY == -1 || abs(item.y - currentY) > 10 {
                if !currentRow.isEmpty {
                    rows.append(currentRow)
                    currentRow = []
                }
                currentY = item.y
            }
            currentRow.append(item)
        }

        // Add last row
        if !currentRow.isEmpty {
            rows.append(currentRow)
        }

        // If no rows created (all items at y=0), group by bootstrap width to fill 12 columns
        if rows.isEmpty && !items.isEmpty {
            currentRow = []
            var currentColumnWidth: CGFloat = 0

            for item in items {
                let width = parseBootstrapWidth(item.bootstrapWidth)

                // If adding this item would exceed 12 columns, start new row
                if currentColumnWidth + width > 12 && !currentRow.isEmpty {
                    rows.append(currentRow)
                    currentRow = []
                    currentColumnWidth = 0
                }

                currentRow.append(item)
                currentColumnWidth += width
            }

            if !currentRow.isEmpty {
                rows.append(currentRow)
            }
        }

        return rows
    }

    /// Parse Bootstrap width string to CGFloat (default 12 if not specified)
    private func parseBootstrapWidth(_ width: String?) -> CGFloat {
        guard let width = width, !width.isEmpty else { return 12 }

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

        return 12 // Full width by default
    }

    private var rowBackground: some View {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemBackground)
        #endif
    }
}

// MARK: - Visualization Item View

struct VisualizationItemView: View {
    let visualization: Visualization
    let dashboardId: UUID?
    let isSelected: Bool
    let showTimeline: Bool

    @State private var showResults: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Visualization Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let title = visualization.title, !title.isEmpty {
                        Text(title)
                            .font(.headline)
                    } else {
                        Text("Visualization")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }

                    if let type = visualization.type {
                        Text(type)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Toggle results button
                Button {
                    showResults.toggle()
                } label: {
                    Image(systemName: showResults ? "eye.slash" : "eye")
                }
                .buttonStyle(.bordered)
                .help(showResults ? "Hide results" : "Show results")
            }

            // Results section
            if showResults {
                Divider()
                visualizationResults
            }
        }
        .padding()
        .background(itemBackground)
        .overlay(itemBorder)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    private var visualizationResults: some View {
        if let dataSource = visualization.dataSource,
           let dsId = dataSource.id,
           let dashId = dashboardId {
            // Show search results using existing SearchResultsTableView
            SearchResultsTableView(
                dashboardId: dashId,
                dataSourceId: dsId
            )
            .frame(minHeight: 300, maxHeight: 600)
        } else {
            // No data source linked
            VStack(spacing: 8) {
                Image(systemName: "cylinder.slash")
                    .font(.title)
                    .foregroundStyle(.secondary)
                Text("No data source configured")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(6)
        }
    }

    private var itemBackground: some View {
        #if os(macOS)
        Color(nsColor: .textBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }

    private var itemBorder: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
    }
}

// MARK: - Input Item View

struct InputItemView: View {
    let input: DashboardInput

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Input label
            if let title = input.title, !title.isEmpty {
                Text(title)
                    .font(.headline)
            } else if let token = input.token {
                Text("$\(token)$")
                    .font(.headline)
                    .monospaced()
            }

            // Input type and token info
            HStack {
                if let type = input.type {
                    Text(type)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }

                if let token = input.token {
                    Text("Token: $\(token)$")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospaced()
                }
            }

            // Default value (if any)
            if let defaultValue = input.defaultValue, !defaultValue.isEmpty {
                Text("Default: \(defaultValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // TODO: Render actual input control based on type
            Text("Input control rendering not yet implemented")
                .font(.caption)
                .italic()
                .foregroundStyle(.orange)
        }
        .padding()
        .background(inputBackground)
        .cornerRadius(8)
    }

    private var inputBackground: some View {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor).opacity(0.5)
        #else
        Color(uiColor: .secondarySystemBackground).opacity(0.5)
        #endif
    }
}

// MARK: - Bootstrap Grid Layout

/// A custom layout that mimics Bootstrap's 12-column grid system
/// Layout items specify their width as a percentage or column count
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

    /// Compute rows based on Bootstrap column widths (12-column grid)
    private func computeRows(subviews: Subviews, availableWidth: CGFloat) -> [[RowItem]] {
        var rows: [[RowItem]] = []
        var currentRow: [RowItem] = []
        var currentRowColumns: CGFloat = 0

        for subview in subviews {
            let columnWidth = subview[GridColumnWidthKey.self]

            // If adding this item would exceed 12 columns, start a new row
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

// MARK: - Preview

#if DEBUG
struct DashboardStudioRenderView_Previews: PreviewProvider {
    static var previews: some View {
        if let dashboard = try? PersistenceController.shared.context.fetch(Dashboard.fetchRequest()).first {
            NavigationStack {
                DashboardStudioRenderView(dashboard: dashboard)
            }
            .environment(\.managedObjectContext, PersistenceController.shared.context)
        } else {
            Text("No dashboards available")
        }
    }
}
#endif

#endif
