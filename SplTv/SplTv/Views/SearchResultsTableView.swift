import SwiftUI
import CoreData
import DashboardKit

/// Displays search execution results with timeline playback
struct SearchResultsTableView: View {
    let dashboardId: UUID
    let dataSourceId: UUID

    @Environment(\.managedObjectContext) private var viewContext

    // Use @FetchRequest for automatic CoreData observation
    @FetchRequest private var executions: FetchedResults<SearchExecution>

    @State private var currentExecutionIndex: Int = 0
    @State private var isPlaying = false
    @State private var playbackTimer: Timer?

    // Global timeline synchronization
    @ObservedObject private var globalTimeline = GlobalTimelineController.shared

    // Custom init to set up @FetchRequest with dynamic predicate
    init(dashboardId: UUID, dataSourceId: UUID) {
        self.dashboardId = dashboardId
        self.dataSourceId = dataSourceId

        // Initialize @FetchRequest with predicate for this specific dataSource
        // IMPORTANT: Prefetch 'results' relationship to avoid faulting issues
        let fetchRequest = NSFetchRequest<SearchExecution>(entityName: "SearchExecution")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \SearchExecution.startTime, ascending: false)]
        fetchRequest.predicate = NSPredicate(format: "dataSource.id == %@", dataSourceId as CVarArg)
        fetchRequest.relationshipKeyPathsForPrefetching = ["results", "dataSource"]

        _executions = FetchRequest<SearchExecution>(fetchRequest: fetchRequest, animation: .default)
    }

    // MARK: - Computed Properties

    /// Find execution closest to global timeline's current timestamp
    private var syncedExecution: SearchExecution? {
        guard let targetTime = globalTimeline.currentTimestamp else {
            // No global timeline set - use local index
            return executions[safe: currentExecutionIndex]
        }

        // Find execution with startTime closest to targetTime
        let closest = executions.min(by: { exec1, exec2 in
            let diff1 = abs(exec1.startTime?.timeIntervalSince(targetTime) ?? .infinity)
            let diff2 = abs(exec2.startTime?.timeIntervalSince(targetTime) ?? .infinity)
            return diff1 < diff2
        })

        if let found = closest, let foundTime = found.startTime {
            let timeDiff = abs(foundTime.timeIntervalSince(targetTime))
            print("📊 Synced to execution at \(foundTime) (diff: \(timeDiff)s)")
        }

        return closest
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ExecutionTimelineView(
                executions: Array(executions),  // Convert FetchedResults to Array
                currentIndex: $currentExecutionIndex,
                isPlaying: $isPlaying,
                onRefresh: {} // No manual refresh needed - @FetchRequest handles it
            )

            Divider()

            resultsContentView
        }
        .onAppear {
            print("📊 SearchResultsTableView: onAppear - \(executions.count) execution(s) for dataSource '\(dataSourceId)'")
            print("📊 SearchResultsTableView: Predicate = dataSource.id == \(dataSourceId)")

            // Debug: Print execution details
            for (index, exec) in executions.enumerated() {
                print("   [\(index)] ID: \(exec.id?.uuidString ?? "nil"), Status: \(exec.status ?? "nil"), DataSource: \(exec.dataSource?.id?.uuidString ?? "nil")")
            }

            startPlaybackIfNeeded()
        }
        .onDisappear {
            stopPlayback()
        }
        .onChange(of: isPlaying) { oldValue, newValue in
            print("📊 isPlaying changed: \(oldValue) -> \(newValue)")
            if newValue {
                print("📊 Starting playback...")
                startPlayback()
            } else {
                print("📊 Stopping playback...")
                stopPlayback()
            }
        }
        .onChange(of: executions.count) { _, newCount in
            // @FetchRequest automatically updates when CoreData changes
            print("📊 SearchResultsTableView: Execution count changed to \(newCount)")

            // Reset index if it's out of bounds
            if !executions.isEmpty && currentExecutionIndex >= executions.count {
                currentExecutionIndex = 0
            }
        }
    }

    // MARK: - Results Content

    @ViewBuilder
    private var resultsContentView: some View {
        let _ = print("📊 resultsContentView: executions.count=\(executions.count), globalTimestamp=\(globalTimeline.currentTimestamp?.description ?? "nil")")

        // Use synced execution from global timeline, or fallback to local index
        if let currentExecution = syncedExecution, currentExecution.resultCount > 0 {
            // Find previous execution for change detection
            if let currentIndex = executions.firstIndex(where: { $0.id == currentExecution.id }) {
                let hasPrevious = currentIndex < executions.count - 1
                let previousExecution = hasPrevious ? executions[currentIndex + 1] : nil

                let _ = print("📊 resultsContentView: Showing synced execution with \(currentExecution.resultCount) results")

                ResultsTableContent(
                    execution: currentExecution,
                    previousExecution: previousExecution,
                    showChanges: hasPrevious
                )
                .id(currentExecution.id)
            } else {
                let _ = print("📊 resultsContentView: Could not find execution index")
                emptyResultsView
            }
        } else {
            let _ = print("📊 resultsContentView: No synced execution with results - showing empty view")
            emptyResultsView
        }
    }

    private var emptyResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No results yet")
                .font(.headline)

            Text("Execute the search to see results here")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Playback Control

    private func startPlaybackIfNeeded() {
        // Auto-playback disabled - user can manually start with play button
        let executionsWithResults = executions.filter { $0.resultCount > 0 }
        print("📊 startPlaybackIfNeeded: \(executions.count) executions, \(executionsWithResults.count) with results - auto-playback disabled")
    }

    private func startPlayback() {
        print("📊 startPlayback called")
        stopPlayback()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            print("📊 Playback timer fired - moving to next")
            moveToNext()
            if currentExecutionIndex == 0 {
                print("📊 Reached latest execution - stopping playback")
                stopPlayback()
            }
        }
        print("📊 Playback timer started")
    }

    private func stopPlayback() {
        print("📊 stopPlayback called, timer exists: \(playbackTimer != nil)")
        if playbackTimer != nil {
            playbackTimer?.invalidate()
            playbackTimer = nil
            isPlaying = false
        }
    }

    private func moveToNext() {
        print("📊 moveToNext: currentIndex=\(currentExecutionIndex), executions.count=\(executions.count)")
        guard currentExecutionIndex > 0 else {
            print("📊 moveToNext: Already at latest (index 0) - stopping playback")
            stopPlayback()
            return
        }
        currentExecutionIndex -= 1
        print("📊 moveToNext: Moved to index \(currentExecutionIndex)")
    }
}
