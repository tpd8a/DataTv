import SwiftUI
import DashboardKit

/// Displays a single search/data source row with timer and status information
struct SearchRowView: View {
    let adapter: DataSourceAdapter
    // Note: DashboardRefreshWorker not yet migrated - timer info disabled
    // let timerInfo: SearchTimerInfo?
    var isSelected: Bool = false
    var onSelect: (() -> Void)? = nil

    var body: some View {
        Button {
            onSelect?()
        } label: {
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    headerSection

                    // Timer info disabled until DashboardRefreshWorker migrated
                    // if let timer = timerInfo {
                    //     Divider()
                    //     timerInfoSection(timer)
                    // } else {
                    noTimerSection
                    // }

                    if let query = adapter.query, !query.isEmpty {
                        Divider()
                        queryPreviewSection(query)
                    }
                }
                .padding(.vertical, 4)
            }
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            Image(systemName: adapter.iconName)
                .foregroundStyle(isSelected ? .blue : Color(adapter.iconColor))

            VStack(alignment: .leading, spacing: 2) {
                Text(adapter.displayName)
                    .font(.headline)

                if adapter.isChained, let baseId = adapter.extendsId {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.branch")
                            .imageScale(.small)
                        Text("Post-processes: \(baseId)")
                            .font(.caption2)
                    }
                    .foregroundStyle(.orange)
                }

                if let refresh = adapter.refresh, !refresh.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .imageScale(.small)
                        Text("Refresh: \(refresh)")
                            .font(.caption2)
                    }
                    .foregroundStyle(.purple)
                }
            }

            Spacer()

            statusBadges
        }
    }

    // MARK: - Status Badges

    private var statusBadges: some View {
        HStack(spacing: 6) {
            // Timer info disabled until DashboardRefreshWorker migrated
            // if timerInfo != nil {
            //     Image(systemName: "timer")
            //         .foregroundStyle(.green)
            //         .help("Has active refresh timer")
            // } else
            if let refresh = adapter.refresh, !refresh.isEmpty {
                Image(systemName: "timer.circle")
                    .foregroundStyle(.orange)
                    .help("Has refresh interval but timer not active")
            }

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
            }
        }
    }

    // MARK: - Timer Info Section
    // Disabled until DashboardRefreshWorker migrated - SearchTimerInfo type removed
    /*
    private func timerInfoSection(_ timer: SearchTimerInfo) -> some View {
        VStack(spacing: 4) {
            HStack {
                Label("Active Interval", systemImage: "clock")
                Spacer()
                Text(DashboardRefreshWorker.formatInterval(timer.interval))
                    .fontWeight(.medium)
            }
            .font(.caption)

            if let lastRefresh = timer.lastRefresh {
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
                Text(timer.nextRefresh, formatter: timeFormatter)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
    */

    // MARK: - No Timer Section

    private var noTimerSection: some View {
        HStack {
            if adapter.isChained {
                Label("Post-processing search", systemImage: "wand.and.stars")
            } else if adapter.isSavedSearch {
                Label("Saved search reference", systemImage: "bookmark")
            } else if let refresh = adapter.refresh, !refresh.isEmpty {
                Label("Has refresh: \(refresh) (timer not started)", systemImage: "timer.circle")
                    .foregroundStyle(.orange)
            } else {
                Label("Static search", systemImage: "doc.text")
            }
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - Query Preview Section

    private func queryPreviewSection(_ query: String) -> some View {
        Text(query)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .help(query)
    }

    // MARK: - Formatters

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }
}
