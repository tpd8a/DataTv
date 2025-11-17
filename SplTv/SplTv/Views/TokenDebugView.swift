import SwiftUI
import DashboardKit

/// Debug view showing all tokens and their current state
struct TokenDebugView: View {
    @ObservedObject private var tokenManager = DashboardTokenManager.shared
    @State private var isExpanded = false

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                // Header with expand/collapse
                Button {
                    withAnimation {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Image(systemName: "list.bullet.rectangle")
                            .foregroundStyle(.purple)

                        Text("Token Registry")
                            .font(.headline)

                        Spacer()

                        let stats = tokenManager.getStatistics()
                        Text("\(stats.totalTokens) tokens")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                if isExpanded {
                    Divider()

                    // Statistics
                    statisticsSection

                    Divider()

                    // Token list
                    if tokenManager.tokenValues.isEmpty {
                        Text("No tokens loaded")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    } else {
                        tokenListSection
                    }
                }
            }
        }
    }

    private var statisticsSection: some View {
        let stats = tokenManager.getStatistics()

        return VStack(spacing: 6) {
            HStack(spacing: 16) {
                statBadge(label: "Total", value: "\(stats.totalTokens)", color: .blue)
                statBadge(label: "User", value: "\(stats.userModified)", color: .green)
                statBadge(label: "Default", value: "\(stats.defaults)", color: .gray)
            }

            if let lastUpdate = stats.lastUpdate {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text("Last update: \(lastUpdate, formatter: timeFormatter)")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
        }
    }

    private func statBadge(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var tokenListSection: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(Array(tokenManager.tokenValues.values).sorted(by: { $0.name < $1.name })) { tokenValue in
                    TokenDebugRow(tokenValue: tokenValue)
                }
            }
        }
        .frame(maxHeight: 300)
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }
}

// MARK: - Token Debug Row

struct TokenDebugRow: View {
    let tokenValue: TokenValue
    @ObservedObject private var tokenManager = DashboardTokenManager.shared

    var body: some View {
        HStack(spacing: 8) {
            // Source indicator
            sourceIcon
                .frame(width: 20)

            // Token name
            VStack(alignment: .leading, spacing: 2) {
                Text(tokenValue.name)
                    .font(.caption)
                    .fontWeight(.medium)

                if let adapter = tokenManager.tokenAdapters[tokenValue.name] {
                    Text(adapter.label ?? adapter.type)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Current value
            VStack(alignment: .trailing, spacing: 2) {
                Text(tokenValue.value.isEmpty ? "(empty)" : tokenValue.value)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(tokenValue.value.isEmpty ? .secondary : .primary)

                Text(tokenValue.lastUpdated, formatter: timeFormatter)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(rowBackground)
        .cornerRadius(6)
    }

    private var sourceIcon: some View {
        let (icon, color) = sourceIndicator
        return Image(systemName: icon)
            .font(.caption)
            .foregroundStyle(color)
    }

    private var sourceIndicator: (icon: String, color: Color) {
        switch tokenValue.source {
        case .user:
            return ("person.fill", .green)
        case .default:
            return ("gear", .gray)
        case .calculated:
            return ("function", .blue)
        case .search:
            return ("magnifyingglass", .orange)
        }
    }

    private var rowBackground: Color {
        switch tokenValue.source {
        case .user:
            return Color.green.opacity(0.1)
        case .default:
            return Color.gray.opacity(0.05)
        case .calculated:
            return Color.blue.opacity(0.1)
        case .search:
            return Color.orange.opacity(0.1)
        }
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }
}

// MARK: - Preview

#if DEBUG
struct TokenDebugView_Previews: PreviewProvider {
    static var previews: some View {
        TokenDebugView()
            .padding()
    }
}
#endif
