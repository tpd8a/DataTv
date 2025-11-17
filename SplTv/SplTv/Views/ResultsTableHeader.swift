import SwiftUI

/// Table header row with sortable columns
struct ResultsTableHeader: View {
    let fields: [String]
    let showRowNumbers: Bool
    let sortField: String?
    let sortAscending: Bool
    let columnWidths: [String: Double]
    let settings: DashboardMonitorSettings
    let onSort: (String) -> Void
    let onAutoSize: (String) -> Void

    var body: some View {
        HStack(spacing: 0) {
            if showRowNumbers {
                rowNumberHeaderCell
                Divider()
            }

            ForEach(fields, id: \.self) { field in
                columnHeaderCell(for: field)

                if field != fields.last {
                    Divider()
                }
            }
        }
        #if os(macOS)
        .background(Color(nsColor: .controlBackgroundColor))
        #else
        .background(Color(uiColor: .systemBackground))
        #endif
    }

    // MARK: - Row Number Header

    private var rowNumberHeaderCell: some View {
        Text("#")
            .font(.system(
                size: settings.tableAppearance.fontSize,
                weight: .bold,
                design: settings.tableAppearance.fontDesign
            ))
            .frame(width: 60, alignment: .center)
            .padding(.vertical, 10)
            #if os(macOS)
            .background(Color(nsColor: .controlAccentColor).opacity(0.15))
            #else
            .background(Color.accentColor.opacity(0.15))
            #endif
    }

    // MARK: - Column Header Cell

    private func columnHeaderCell(for field: String) -> some View {
        let columnWidth = columnWidths[field] ?? 150

        return Button {
            onSort(field)
        } label: {
            HStack(spacing: 6) {
                Text(field)
                    .font(.system(
                        size: settings.tableAppearance.fontSize,
                        weight: .bold,
                        design: settings.tableAppearance.fontDesign
                    ))
                    .lineLimit(1)

                Spacer(minLength: 4)

                sortIndicator(for: field)
            }
            .frame(width: columnWidth, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(headerBackgroundColor(for: field))
        #if os(macOS)
        .onTapGesture(count: 2) {
            onAutoSize(field)
        }
        .onHover { isHovered in
            if isHovered {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        #endif
    }

    // MARK: - Sort Indicator

    @ViewBuilder
    private func sortIndicator(for field: String) -> some View {
        if sortField == field {
            Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.blue)
        } else {
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .opacity(0.3)
        }
    }

    // MARK: - Header Background Color

    private func headerBackgroundColor(for field: String) -> Color {
        if sortField == field {
            #if os(macOS)
            return Color(nsColor: .controlAccentColor).opacity(0.15)
            #else
            return Color.accentColor.opacity(0.15)
            #endif
        } else {
            return .clear
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ResultsTableHeader_Previews: PreviewProvider {
    static var previews: some View {
        ResultsTableHeader(
            fields: ["timestamp", "source", "count", "error"],
            showRowNumbers: true,
            sortField: "count",
            sortAscending: false,
            columnWidths: ["timestamp": 200, "source": 150, "count": 100, "error": 100],
            settings: DashboardMonitorSettings.shared,
            onSort: { field in print("Sort by \(field)") },
            onAutoSize: { field in print("Auto-size \(field)") }
        )
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
#endif
