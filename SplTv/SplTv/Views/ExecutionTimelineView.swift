import SwiftUI
import CoreData
import DashboardKit

/// Manages playback and navigation through search execution timeline
struct ExecutionTimelineView: View {
    let executions: [SearchExecution]
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
        .padding(16)
        .background {
            // Subtle gradient to provide depth for glass effect
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.05), Color.white.opacity(0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
        HStack(spacing: 16) {
            Spacer()

            // Previous button
            Button {
                moveToPrevious()
            } label: {
                Image(systemName: "backward.end.fill")
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .disabled(currentIndex >= executions.count - 1)

            // Play/Pause button with prominence
            Button {
                isPlaying.toggle()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.circle)
            .tint(.blue)

            // Next button
            Button {
                moveToNext()
            } label: {
                Image(systemName: "forward.end.fill")
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .disabled(currentIndex <= 0)

            Spacer()
        }
        .overlay(alignment: .trailing) {
            // Counter badge on the right
            Text("\(executions.count - currentIndex) of \(executions.count)")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .glassEffect(.clear, in: Capsule())
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
                        if let startTime = currentExecution.startTime {
                            // Date and time display
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.caption2)
                                    .foregroundStyle(.blue)

                                Text(startTime, formatter: timeOnlyFormatter)
                                    .font(.caption.bold())

                                Text(startTime, formatter: dateOnlyFormatter)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        executionStatusBadge(currentExecution)
                    }

                    Spacer()

                    let resultCount = currentExecution.resultCount
                    if resultCount > 0 {
                        Text("\(resultCount) result(s)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Status Badge

    private func executionStatusBadge(_ execution: SearchExecution) -> some View {
        Text(executionStatusText(execution))
            .font(.caption2.weight(.medium))
            .foregroundStyle(executionStatusColor(execution))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .glassEffect(.clear.tint(executionStatusColor(execution).opacity(0.2)), in: Capsule())
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

    private func executionStatusText(_ execution: SearchExecution) -> String {
        switch execution.status {
        case "completed": return "Completed"
        case "running": return "Running"
        case "failed": return "Failed"
        default: return execution.status ?? "Unknown"
        }
    }

    private func executionStatusColor(_ execution: SearchExecution) -> Color {
        switch execution.status {
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

    private var timeOnlyFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }

    private var dateOnlyFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }
}

// MARK: - Safe Array Extension

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
