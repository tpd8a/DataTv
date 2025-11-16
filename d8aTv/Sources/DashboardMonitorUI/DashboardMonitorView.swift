import SwiftUI
import CoreData
import d8aTvCore


#if os(macOS) || os(tvOS)

/// Main dashboard monitoring view
/// Displays dashboards with active refresh timers and allows control
public struct DashboardMonitorView: View {
    
    // MARK: - Environment
    @Environment(\.managedObjectContext) private var viewContext
    
    // MARK: - State
    @StateObject private var refreshWorker = DashboardRefreshWorker.shared
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
        .padding(.vertical, 2)
    }
    
    private var activeTimerCount: Int? {
        let count = refreshWorker.activeSearchTimers.values.filter {
            $0.dashboardId == dashboard.id
        }.count
        return count > 0 ? count : nil
    }
}

// MARK: - Dashboard Detail View

struct DashboardDetailView: View {
    let dashboard: DashboardEntity
    @StateObject private var refreshWorker = DashboardRefreshWorker.shared
    
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
                
                // Controls
                controlsSection
                
                Spacer()
            }
        }
        #if os(macOS)
        .frame(minWidth: 400)
        #endif
    }
    
    private var activeTimersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Refresh Timers")
                .font(.headline)
            
            let dashboardTimers = refreshWorker.activeSearchTimers.values.filter {
                $0.dashboardId == dashboard.id
            }
            
            if dashboardTimers.isEmpty {
                Text("No active refresh timers")
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(dashboardTimers), id: \.id) { timerInfo in
                    TimerInfoRow(timerInfo: timerInfo)
                }
            }
        }
        .padding()
    }
    
    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Controls")
                .font(.headline)
            
            HStack(spacing: 12) {
                Button {
                    refreshWorker.startRefreshTimers(for: dashboard.id)
                } label: {
                    Label("Start Timers", systemImage: "play.circle")
                }
                .buttonStyle(.bordered)
                
                Button {
                    refreshWorker.stopRefreshTimers(for: dashboard.id)
                } label: {
                    Label("Stop Timers", systemImage: "stop.circle")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
}

// MARK: - Timer Info Row

struct TimerInfoRow: View {
    let timerInfo: SearchTimerInfo
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.blue)
                    Text(timerInfo.searchId)
                        .font(.headline)
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
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
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

#endif
