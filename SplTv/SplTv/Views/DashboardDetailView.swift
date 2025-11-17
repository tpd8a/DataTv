import SwiftUI
import DashboardKit

/// Main detail view for displaying dashboard information and search results
struct DashboardDetailView: View {
    let dashboard: Dashboard
    // Note: DashboardRefreshWorker not yet migrated - auto-refresh disabled for now
    // @StateObject private var refreshWorker = DashboardRefreshWorker.shared
    @State private var selectedDataSourceId: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                Divider()
                dataSourcesSection
                Divider()
                searchResultsSection
                Spacer()
            }
        }
        #if os(macOS)
        .frame(minWidth: 400)
        #endif
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(dashboard.title ?? dashboard.id?.uuidString ?? "Untitled")
                .font(.largeTitle)
                .fontWeight(.bold)

            if let description = dashboard.dashboardDescription {
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            // Show format type badge
            if let formatType = dashboard.formatType {
                HStack(spacing: 4) {
                    Image(systemName: formatType == "dashboardStudio" ? "rectangle.3.group" : "doc.text")
                        .imageScale(.small)
                    Text(formatType == "dashboardStudio" ? "Dashboard Studio" : "Simple XML")
                        .font(.caption)
                }
                .foregroundStyle(.blue)
            }
        }
        .padding()
    }

    // MARK: - Data Sources Section

    private var dataSourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data Sources")
                .font(.headline)

            let dataSources = getDataSources()

            if dataSources.isEmpty {
                Text("No data sources found in this dashboard")
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(dataSources.asAdapters) { adapter in
                    // Timer info disabled until DashboardRefreshWorker migrated
                    // let timerKey = "\(dashboard.id?.uuidString ?? ""):\(adapter.sourceId)"
                    // let timerInfo = refreshWorker.activeSearchTimers[timerKey]

                    SearchRowView(
                        adapter: adapter,
                        // timerInfo: timerInfo,  // Disabled - DashboardRefreshWorker not migrated
                        isSelected: selectedDataSourceId == adapter.sourceId,
                        onSelect: { selectedDataSourceId = adapter.sourceId }
                    )
                }
            }
        }
        .padding()
    }

    // MARK: - Search Results Section

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Search Results")
                .font(.headline)

            if let dataSourceId = selectedDataSourceId,
               let dashboardId = dashboard.id?.uuidString {
                SearchResultsTableView(
                    dashboardId: dashboardId,
                    searchId: dataSourceId
                )
                .id("\(dashboardId)-\(dataSourceId)")
            } else {
                Text("Select a data source above to view its results")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            }
        }
        .padding()
    }

    // MARK: - Helper Methods

    private func getDataSources() -> [DataSource] {
        guard let dataSources = dashboard.dataSources as? Set<DataSource> else {
            return []
        }
        // Sort by sourceId for consistent ordering
        return dataSources.sorted { ($0.sourceId ?? "") < ($1.sourceId ?? "") }
    }
}
