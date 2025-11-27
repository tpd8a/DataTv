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
    @State private var selectedDashboard: Dashboard?
    @State private var showingSettings = false

    // MARK: - Token Manager
    @StateObject private var tokenManager = DashboardTokenManager.shared

    // MARK: - Fetch Requests
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Dashboard.title, ascending: true)],
        animation: .default)
    private var dashboards: FetchedResults<Dashboard>

    // MARK: - Body
    var body: some View {
        NavigationSplitView {
            sidebarContent
        } detail: {
            mainContent
        }
        .onAppear {
            autoSelectFirstDashboard()
            SearchExecutionMonitor.shared.startMonitoring()
        }
        .onChange(of: selectedDashboard) { _, newDashboard in
            if let dashboard = newDashboard, selectedMode == .render {
                tokenManager.loadTokens(for: dashboard)

                // Evaluate autostart after tokens are loaded
                Task {
                    await DashboardAutoStartManager.shared.evaluateAutoStart(for: dashboard)
                }
            }
        }
        .onChange(of: selectedMode) { _, newMode in
            if newMode == .render, let dashboard = selectedDashboard {
                tokenManager.loadTokens(for: dashboard)

                // Evaluate autostart after tokens are loaded
                Task {
                    await DashboardAutoStartManager.shared.evaluateAutoStart(for: dashboard)
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            DashboardSettingsView()
        }
    }

    // MARK: - Sidebar

    private var sidebarContent: some View {
        List {
            viewModeSection
            dashboardListSection

            if selectedMode == .render, let dashboard = selectedDashboard {
                dashboardInputsSection(for: dashboard)
                tokenDebugSection
            }
        }
        #if os(macOS)
        .listStyle(.sidebar)
        .frame(minWidth: 280)
        #endif
        .navigationTitle("Dashboards")
    }

    // MARK: - View Mode Section

    private var viewModeSection: some View {
        Section("View Mode") {
            Picker("Mode", selection: $selectedMode) {
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    Label(mode.rawValue, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Dashboard List Section

    private var dashboardListSection: some View {
        Section("Dashboards") {
            if dashboards.isEmpty {
                Text("No dashboards found")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                ForEach(dashboards) { dashboard in
                    DashboardRowView(
                        dashboard: dashboard,
                        isSelected: selectedDashboard?.id == dashboard.id,
                        showInputCount: selectedMode == .render
                    ) {
                        selectedDashboard = dashboard
                    }
                }
            }
        }
    }

    // MARK: - Dashboard Inputs Section

    @ViewBuilder
    private func dashboardInputsSection(for dashboard: Dashboard) -> some View {
        if let inputs = dashboard.inputs as? Set<DashboardInput>, !inputs.isEmpty {
            Section {
                ForEach(Array(inputs).sorted(by: { ($0.inputId ?? "") < ($1.inputId ?? "") })) { input in
                    TokenInputView(adapter: TokenAdapter(input: input))
                }
            } header: {
                Label("Dashboard Inputs", systemImage: "slider.horizontal.3")
            }
        }
    }

    // MARK: - Token Debug Section

    private var tokenDebugSection: some View {
        Section {
            TokenDebugView()
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        if let dashboard = selectedDashboard {
            switch selectedMode {
            case .monitor:
                DashboardDetailView(dashboard: dashboard)
                    .id(dashboard.id)
                    .toolbar {
                        ToolbarItemGroup(placement: .automatic) {
                            monitorToolbarButtons
                        }
                    }

            case .render:
                DashboardStudioRenderView(dashboard: dashboard)
                    .id(dashboard.id)
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
            showingSettings = true
        } label: {
            Label("Settings", systemImage: "gear")
        }
        .help("Table and cell display settings")
    }

    @ViewBuilder
    private var renderToolbarButtons: some View {
        Button {
            print("🔄 Refresh all visualizations for dashboard")
        } label: {
            Label("Refresh All", systemImage: "arrow.clockwise")
        }
        .help("Refresh all visualizations")

        Button {
            showingSettings = true
        } label: {
            Label("Settings", systemImage: "gear")
        }
        .help("Dashboard settings")
    }

    // MARK: - Empty State

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

    // MARK: - Helper Methods

    private func autoSelectFirstDashboard() {
        if selectedDashboard == nil, let first = dashboards.first {
            selectedDashboard = first
            if selectedMode == .render {
                tokenManager.loadTokens(for: first)
            }
        }
    }
}

// MARK: - Dashboard Row View

struct DashboardRowView: View {
    let dashboard: Dashboard
    let isSelected: Bool
    let showInputCount: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dashboard.title ?? dashboard.id?.uuidString ?? "Untitled")
                        .font(.headline)

                    HStack(spacing: 8) {
                        if showInputCount {
                            inputCountBadge
                        }
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var inputCountBadge: some View {
        if let inputs = dashboard.inputs as? Set<DashboardInput>, !inputs.isEmpty {
            HStack(spacing: 2) {
                Image(systemName: "slider.horizontal.3")
                    .font(.caption2)
                Text("\(inputs.count)")
                    .font(.caption2)
            }
            .foregroundStyle(.purple)
        }
    }
}

// MARK: - Preview

// MARK: - Dashboard Settings View (Stub)

/// Placeholder settings view - TODO: Implement full settings UI
struct DashboardSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settings = DashboardMonitorSettings.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("Cell Change Highlighting") {
                    Text("Settings UI coming soon")
                        .foregroundStyle(.secondary)
                }

                Section("Table Appearance") {
                    Text("Font, colors, and spacing controls")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Dashboard Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        settings.saveSettings()
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}

#if DEBUG
@available(macOS 26, tvOS 26, *)
struct DashboardMainView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardMainView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
#endif

#endif
