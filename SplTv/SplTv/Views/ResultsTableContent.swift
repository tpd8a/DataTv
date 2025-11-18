import SwiftUI
import CoreData
import DashboardKit

/// Main coordinator for displaying search results in a table format
/// Handles loading, change detection, sorting, and rendering
struct ResultsTableContent: View {
    let execution: SearchExecution
    let previousExecution: SearchExecution?
    let showChanges: Bool

    @ObservedObject private var settings = DashboardMonitorSettings.shared
    @Environment(\.managedObjectContext) private var viewContext

    // MARK: - State

    @State private var results: [[String: Any]] = []
    @State private var previousResults: [[String: Any]] = []
    @State private var fields: [String] = []
    @State private var isLoading = true

    // Table display options
    @State private var sortField: String?
    @State private var sortAscending = true
    @State private var columnWidths: [String: CGFloat] = [:]
    @State private var wrapResults: Bool = false
    @State private var showRowNumbers: Bool = false
    @State private var displayRowCount: Int = 10

    // Formatting
    @State private var vizFormatting: VisualizationFormatting? = nil
    @State private var fieldsWithNumberFormat: Set<String> = []
    @State private var fieldsWithColorFormat: Set<String> = []

    // Animation state
    @State private var animatingCells: Set<String> = []
    @State private var newRowIndices: Set<Int> = []

    // MARK: - Computed Properties

    private var displayedResults: [[String: Any]] {
        guard displayRowCount > 0 else { return results }
        return Array(results.prefix(displayRowCount))
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            resultMetadataHeader

            Divider()

            if isLoading {
                ProgressView("Loading results...")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else if results.isEmpty {
                emptyResultsView
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
            loadResults()
            loadTablePreferences()
        }
    }

    // MARK: - Metadata Header

    private var resultMetadataHeader: some View {
        HStack(spacing: 8) {
            Text("\(results.count) results")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if showChanges && settings.cellChangeSettings.highlightStyle != .splunkDefault {
                changeLegend
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var changeLegend: some View {
        HStack(spacing: 6) {
            if settings.cellChangeSettings.highlightStyle == .directional {
                legendBox(color: settings.cellChangeSettings.increaseColor, label: "Increased")
                legendBox(color: settings.cellChangeSettings.decreaseColor, label: "Decreased")
            } else {
                let color: Color = settings.cellChangeSettings.highlightStyle == .systemColors ?
                    .accentColor : settings.cellChangeSettings.customColor
                legendBox(color: color, label: "Changed")
            }
        }
    }

    private func legendBox(color: Color, label: String) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color.opacity(settings.cellChangeSettings.fillOpacity))
            .frame(width: 12, height: 12)
            .overlay(
                settings.cellChangeSettings.showOverlay ?
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(color, lineWidth: 1) : nil
            )
            .help(label)
    }

    // MARK: - Empty State

    private var emptyResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No data to display")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 40)
    }

    // MARK: - Results Table

    private var resultTable: some View {
        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
            Section {
                tableDataRows
            } header: {
                ResultsTableHeader(
                    fields: fields,
                    showRowNumbers: showRowNumbers,
                    sortField: sortField,
                    sortAscending: sortAscending,
                    columnWidths: columnWidths.mapValues { Double($0) },
                    settings: settings,
                    onSort: sortByField,
                    onAutoSize: autoSizeColumn
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tableBackground)
        .overlay(tableBorder)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    // MARK: - Table Rows

    private var tableDataRows: some View {
        ForEach(Array(displayedResults.enumerated()), id: \.offset) { index, row in
            tableDataRow(index: index, row: row)

            if index != displayedResults.count - 1 {
                Divider().opacity(0.3)
            }
        }
    }

    private func tableDataRow(index: Int, row: [String: Any]) -> some View {
        HStack(alignment: .top, spacing: 0) {
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
        .background(rowBackground(for: index))
    }

    // MARK: - Cells

    private func rowNumberCell(index: Int) -> some View {
        Text("\(index + 1)")
            .font(.system(
                size: settings.tableAppearance.fontSize,
                weight: settings.tableAppearance.fontWeight,
                design: settings.tableAppearance.fontDesign
            ))
            .foregroundStyle(.secondary)
            .frame(width: 60, alignment: .center)
            .padding(.vertical, 8)
    }

    private func dataCell(field: String, row: [String: Any], index: Int) -> some View {
        let cellValue = stringValue(for: field, in: row)
        let rawValue = row[field]
        let changeInfo = cellChangeInfo(field: field, rowIndex: index)
        let allColumnValues = results.map { $0[field] }

        // Calculate formatting with CORRECT PRIORITY ORDER
        let formatting = CellFormatting(
            field: field,
            value: cellValue,
            rawValue: rawValue,
            changeInfo: changeInfo,
            rowIndex: index,
            allColumnValues: allColumnValues,
            settings: settings,
            vizFormatting: vizFormatting,
            fieldsWithNumberFormat: fieldsWithNumberFormat,
            fieldsWithColorFormat: fieldsWithColorFormat
        )

        let cellKey = "\(index)-\(field)"
        let isAnimating = Binding(
            get: { animatingCells.contains(cellKey) },
            set: { if $0 { animatingCells.insert(cellKey) } else { animatingCells.remove(cellKey) } }
        )

        return ResultsTableCell(
            formatting: formatting,
            field: field,
            index: index,
            settings: settings,
            isAnimating: isAnimating
        )
        .frame(minWidth: columnWidths[field] ?? 150)
    }

    // MARK: - Table Styling

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
        if settings.tableAppearance.useCustomCellBackground {
            return settings.tableAppearance.customCellBackgroundColor
        }

        guard settings.tableAppearance.enableZebraStriping else {
            return .clear
        }

        guard index % 2 != 0 else {
            return .clear
        }

        #if os(macOS)
        return Color(nsColor: .separatorColor).opacity(settings.tableAppearance.zebraStripeOpacity * 2)
        #else
        return Color(uiColor: .systemGray4).opacity(settings.tableAppearance.zebraStripeOpacity * 2)
        #endif
    }

    // MARK: - Data Loading

    private func loadResults() {
        isLoading = true

        print("🔄 Loading results for execution: \(execution.id?.uuidString ?? "unknown")")

        // Load visualization options from dashboard
        loadVisualizationOptions()

        // Parse results from SearchResult entities
        if let resultsSet = execution.results as? Set<SearchResult> {
            let sortedResults = resultsSet.sorted { $0.rowIndex < $1.rowIndex }
            var parsedRows: [[String: Any]] = []

            for result in sortedResults {
                if let jsonString = result.resultJSON,
                   let jsonData = jsonString.data(using: .utf8) {
                    do {
                        if let row = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                            parsedRows.append(row)
                        }
                    } catch {
                        print("❌ Failed to parse result row \(result.rowIndex): \(error)")
                    }
                }
            }

            results = parsedRows
            fields = extractFields(from: parsedRows)
            print("✅ Loaded \(parsedRows.count) results with \(fields.count) fields")
        } else {
            results = []
            fields = []
        }

        // Load previous results for change detection
        if showChanges, let prevExecution = previousExecution,
           let prevResultsSet = prevExecution.results as? Set<SearchResult> {
            let sortedPrevResults = prevResultsSet.sorted { $0.rowIndex < $1.rowIndex }
            var parsedPrevRows: [[String: Any]] = []

            for result in sortedPrevResults {
                if let jsonString = result.resultJSON,
                   let jsonData = jsonString.data(using: .utf8) {
                    do {
                        if let row = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                            parsedPrevRows.append(row)
                        }
                    } catch {
                        print("❌ Failed to parse previous result row \(result.rowIndex): \(error)")
                    }
                }
            }

            previousResults = parsedPrevRows
            print("✅ Loaded \(parsedPrevRows.count) previous results for comparison")
        } else {
            previousResults = []
        }

        isLoading = false
    }

    private func loadVisualizationOptions() {
        // Load from DataSource → Visualization relationship
        guard let dataSource = execution.dataSource else {
            print("⚠️ No dataSource relationship found for execution")
            setDefaultVisualizationOptions()
            return
        }

        // Find table visualization for this dataSource
        if let tableViz = Visualization.tableVisualization(forDataSource: dataSource, in: viewContext) {
            print("✅ Found table visualization: \(tableViz.vizId ?? "unknown")")

            // Create formatting helper
            let formatting = VisualizationFormatting(visualization: tableViz)
            vizFormatting = formatting

            // Apply table display options
            wrapResults = formatting.wrapText
            showRowNumbers = formatting.showRowNumbers
            displayRowCount = formatting.tableRowCount

            // Cache fields with formatting
            fieldsWithNumberFormat = Set(formatting.formats(ofType: "number").compactMap { $0["field"] as? String })
            fieldsWithColorFormat = Set(formatting.formats(ofType: "color").compactMap { $0["field"] as? String })

            print("📊 Table options loaded: wrap=\(wrapResults), rowNumbers=\(showRowNumbers), count=\(displayRowCount)")
            print("📊 Fields with number format: \(fieldsWithNumberFormat)")
            print("📊 Fields with color format: \(fieldsWithColorFormat)")
        } else {
            print("⚠️ No table visualization found for dataSource, using defaults")
            setDefaultVisualizationOptions()
        }
    }

    private func setDefaultVisualizationOptions() {
        wrapResults = false
        showRowNumbers = true
        displayRowCount = 100
        fieldsWithNumberFormat = []
        fieldsWithColorFormat = []
    }

    private func extractFields(from rows: [[String: Any]]) -> [String] {
        guard let firstRow = rows.first else { return [] }
        return Array(firstRow.keys).sorted()
    }

    // MARK: - Change Detection

    private func cellChangeInfo(field: String, rowIndex: Int) -> CellFormatting.ChangeInfo {
        guard showChanges, rowIndex < results.count, !previousResults.isEmpty else {
            return CellFormatting.ChangeInfo(hasChanged: false, changeType: .none, color: .clear)
        }

        let currentRow = results[rowIndex]
        let currentValue = stringValue(for: field, in: currentRow)

        // Find matching previous row (simple matching for now)
        guard let previousRow = previousResults.first(where: { prev in
            // Match by key fields (this is simplified - real implementation should use groupby_rank)
            return true
        }) else {
            return CellFormatting.ChangeInfo(hasChanged: false, changeType: .none, color: .clear)
        }

        let previousValue = stringValue(for: field, in: previousRow)

        guard currentValue != previousValue else {
            return CellFormatting.ChangeInfo(hasChanged: false, changeType: .none, color: .clear)
        }

        // Detect change type
        let changeType: CellFormatting.ChangeInfo.ChangeType
        let color: Color

        if let currentNum = Double(currentValue), let previousNum = Double(previousValue) {
            if currentNum > previousNum {
                changeType = .increased
                color = settings.cellChangeSettings.increaseColor
            } else {
                changeType = .decreased
                color = settings.cellChangeSettings.decreaseColor
            }
        } else {
            changeType = .modified
            color = settings.cellChangeSettings.highlightStyle == .customColor ?
                settings.cellChangeSettings.customColor : .accentColor
        }

        return CellFormatting.ChangeInfo(hasChanged: true, changeType: changeType, color: color)
    }

    // MARK: - Sorting

    private func sortByField(_ field: String) {
        if sortField == field {
            sortAscending.toggle()
        } else {
            sortField = field
            sortAscending = true
        }

        applySorting()
        saveTablePreferences()
    }

    private func applySorting() {
        guard let field = sortField else { return }

        results.sort { row1, row2 in
            let value1 = stringValue(for: field, in: row1)
            let value2 = stringValue(for: field, in: row2)

            if let num1 = Double(value1), let num2 = Double(value2) {
                return sortAscending ? num1 < num2 : num1 > num2
            }

            return sortAscending ? value1 < value2 : value1 > value2
        }
    }

    private func autoSizeColumn(_ field: String) {
        var contentWidth: CGFloat = 60

        // Measure header
        let headerWidth = CGFloat(field.count) * 8 + 40
        contentWidth = max(contentWidth, headerWidth)

        // Sample first 50 rows
        for row in results.prefix(50) {
            let value = stringValue(for: field, in: row)
            let valueWidth = CGFloat(value.count) * 7 + 30
            contentWidth = max(contentWidth, valueWidth)
        }

        contentWidth = min(contentWidth, 400)
        columnWidths[field] = contentWidth
        saveTablePreferences()
    }

    // MARK: - Preferences

    private func loadTablePreferences() {
        guard let dashboardId = execution.dashboardId,
              let searchId = execution.searchId else { return }

        let prefs = settings.getTablePreferences(dashboardId: dashboardId, searchId: searchId)
        sortField = prefs.sortField
        sortAscending = prefs.sortAscending
        columnWidths = prefs.columnWidths.mapValues { CGFloat($0) }

        if sortField != nil {
            applySorting()
        }
    }

    private func saveTablePreferences() {
        guard let dashboardId = execution.dashboardId,
              let searchId = execution.searchId else { return }

        var prefs = TableViewPreferences()
        prefs.sortField = sortField
        prefs.sortAscending = sortAscending
        prefs.columnWidths = columnWidths.mapValues { Double($0) }

        settings.setTablePreferences(prefs, dashboardId: dashboardId, searchId: searchId)
    }

    // MARK: - Helpers

    private func stringValue(for field: String, in row: [String: Any]) -> String {
        guard let value = row[field] else { return "" }

        if let string = value as? String {
            return string
        } else if let number = value as? NSNumber {
            return number.stringValue
        } else {
            return "\(value)"
        }
    }
}
