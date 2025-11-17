import SwiftUI
import CoreData
import DashboardKit

/// Manages playback and navigation through search execution timeline
struct ExecutionTimelineView: View {
    let executions: [SearchExecutionEntity]
    @Binding var currentIndex: Int
    @Binding var isPlaying: Bool
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection

            if executions.isEmpty {
                emptyStateView
            } else {
                playbackControlsSection
                timelineSliderSection
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Text("Execution Timeline")
                .font(.subheadline)
                .fontWeight(.semibold)

            Spacer()

            Button {
                onRefresh()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        Text("No executions found for this search")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    // MARK: - Playback Controls

    private var playbackControlsSection: some View {
        HStack(spacing: 12) {
            Button {
                moveToPrevious()
            } label: {
                Image(systemName: "backward.fill")
            }
            .buttonStyle(.bordered)
            .disabled(currentIndex >= executions.count - 1)

            Button {
                isPlaying.toggle()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
            }
            .buttonStyle(.borderedProminent)

            Button {
                moveToNext()
            } label: {
                Image(systemName: "forward.fill")
            }
            .buttonStyle(.bordered)
            .disabled(currentIndex <= 0)

            Button {
                jumpToLatest()
            } label: {
                Label("Latest", systemImage: "arrow.right.to.line")
            }
            .buttonStyle(.bordered)
            .disabled(currentIndex == 0)

            Spacer()

            Text("\(executions.count - currentIndex) of \(executions.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Timeline Slider

    private var timelineSliderSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Slider(
                value: Binding(
                    get: { Double(executions.count - 1 - currentIndex) },
                    set: { newValue in
                        currentIndex = executions.count - 1 - Int(newValue)
                    }
                ),
                in: 0...Double(max(1, executions.count - 1)),
                step: executions.count > 1 ? 1 : 0.1
            )
            .disabled(isPlaying || executions.count <= 1)

            if let currentExecution = executions[safe: currentIndex] {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(currentExecution.startTime, formatter: dateTimeFormatter)
                            .font(.caption2)
                            .fontWeight(.semibold)

                        executionStatusBadge(currentExecution)
                    }

                    Spacer()

                    if let resultCount = currentExecution.resultCount {
                        Text("\(resultCount) result(s)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Status Badge

    private func executionStatusBadge(_ execution: SearchExecutionEntity) -> some View {
        Text(executionStatusText(execution))
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(executionStatusColor(execution).opacity(0.2))
            .foregroundStyle(executionStatusColor(execution))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Navigation Methods

    private func moveToNext() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
    }

    private func moveToPrevious() {
        guard currentIndex < executions.count - 1 else { return }
        currentIndex += 1
    }

    private func jumpToLatest() {
        currentIndex = 0
    }

    // MARK: - Helper Methods

    private func executionStatusText(_ execution: SearchExecutionEntity) -> String {
        switch execution.executionStatus {
        case "completed": return "Completed"
        case "running": return "Running"
        case "failed": return "Failed"
        default: return execution.executionStatus ?? "Unknown"
        }
    }

    private func executionStatusColor(_ execution: SearchExecutionEntity) -> Color {
        switch execution.executionStatus {
        case "completed": return .green
        case "running": return .blue
        case "failed": return .red
        default: return .gray
        }
    }

    private var dateTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }
}

// MARK: - Safe Array Extension

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
