import SwiftUI
import CoreData
import DashboardKit

/// Displays search execution results with timeline playback
struct SearchResultsTableView: View {
    let dashboardId: String
    let searchId: String

    @Environment(\.managedObjectContext) private var viewContext
    @State private var executions: [SearchExecutionEntity] = []
    @State private var currentExecutionIndex: Int = 0
    @State private var isPlaying = false
    @State private var playbackTimer: Timer?
    @State private var notificationObserver: NSObjectProtocol?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ExecutionTimelineView(
                executions: executions,
                currentIndex: $currentExecutionIndex,
                isPlaying: $isPlaying,
                onRefresh: loadExecutions
            )

            Divider()

            resultsContentView
        }
        .onAppear {
            loadExecutions()
            setupNotificationListener()
            startPlaybackIfNeeded()
        }
        .onDisappear {
            stopPlayback()
            removeNotificationListener()
        }
        .onChange(of: isPlaying) { _, playing in
            if playing {
                startPlayback()
            } else {
                stopPlayback()
            }
        }
    }

    // MARK: - Results Content

    @ViewBuilder
    private var resultsContentView: some View {
        if let currentExecution = executions[safe: currentExecutionIndex] {
            let hasPrevious = currentExecutionIndex < executions.count - 1
            let previousExecution = hasPrevious ? executions[currentExecutionIndex + 1] : nil

            ResultsTableContent(
                execution: currentExecution,
                previousExecution: previousExecution,
                showChanges: hasPrevious
            )
            .id(currentExecution.id)
        } else {
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

    // MARK: - Data Loading

    private func loadExecutions() {
        let request: NSFetchRequest<SearchExecutionEntity> = SearchExecutionEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "dashboardId == %@ AND searchId == %@",
            dashboardId, searchId
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SearchExecutionEntity.startTime, ascending: false)]

        do {
            executions = try viewContext.fetch(request)
            print("📊 Loaded \(executions.count) execution(s) for search '\(searchId)'")

            if !executions.isEmpty && currentExecutionIndex >= executions.count {
                currentExecutionIndex = 0
            }
        } catch {
            print("❌ Failed to load executions: \(error)")
            executions = []
        }
    }

    // MARK: - Playback Control

    private func startPlaybackIfNeeded() {
        // Auto-start playback if we have multiple executions
        if executions.count > 1 {
            isPlaying = true
        }
    }

    private func startPlayback() {
        stopPlayback()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            moveToNext()
            if currentExecutionIndex == 0 {
                stopPlayback()
            }
        }
    }

    private func stopPlayback() {
        playbackTimer?.invalidate()
        playbackTimer = nil
        isPlaying = false
    }

    private func moveToNext() {
        guard currentExecutionIndex > 0 else {
            stopPlayback()
            return
        }
        currentExecutionIndex -= 1
    }

    // MARK: - Notification Handling

    private func setupNotificationListener() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .searchExecutionCompleted,
            object: nil,
            queue: .main
        ) { notification in
            guard let userInfo = notification.userInfo,
                  let notificationDashboardId = userInfo["dashboardId"] as? String,
                  let notificationSearchId = userInfo["searchId"] as? String,
                  notificationDashboardId == dashboardId,
                  notificationSearchId == searchId else {
                return
            }

            print("🔔 Search execution completed, reloading results")
            loadExecutions()

            if executions.count > 0 {
                currentExecutionIndex = 0
            }
        }
    }

    private func removeNotificationListener() {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
            notificationObserver = nil
        }
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let searchExecutionCompleted = Notification.Name("searchExecutionCompleted")
}
