import SwiftUI

/// Individual table cell with proper formatting order
/// CRITICAL: Text values are set LAST after all formatting is calculated
struct ResultsTableCell: View {
    let formatting: CellFormatting
    let field: String
    let index: Int
    let settings: DashboardMonitorSettings
    @Binding var isAnimating: Bool

    var body: some View {
        // STEP 5: Apply all pre-calculated formatting to Text view
        // This ensures Splunk formatting and user settings are applied BEFORE text is set
        Text(formatting.displayValue)
            .foregroundColor(formatting.textColor) // Apply calculated text color
            .font(fontWithSettings) // Apply user font settings
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(formatting.backgroundColor) // Apply calculated background color
            .help(formatting.displayValue)
            .textSelection(.enabled)
            .overlay(
                // Change indicator overlay (NOT shown in Splunk Default mode)
                changeIndicatorOverlay
            )
            .id(cellIdentifier) // Ensure proper updates
            .animation(
                settings.cellChangeSettings.animateChanges ?
                    .easeInOut(duration: settings.cellChangeSettings.animationDuration) : nil,
                value: isAnimating
            )
    }

    // MARK: - Font with Settings

    private var fontWithSettings: Font {
        let baseFont = Font.system(
            size: settings.tableAppearance.fontSize,
            weight: settings.tableAppearance.fontWeight,
            design: settings.tableAppearance.fontDesign
        )

        return settings.tableAppearance.isItalic ? baseFont.italic() : baseFont
    }

    // MARK: - Change Indicator Overlay

    @ViewBuilder
    private var changeIndicatorOverlay: some View {
        if formatting.changeInfo.hasChanged &&
           settings.cellChangeSettings.showOverlay &&
           settings.cellChangeSettings.highlightStyle != .splunkDefault {
            RoundedRectangle(cornerRadius: 4)
                .stroke(
                    formatting.changeInfo.color,
                    lineWidth: settings.cellChangeSettings.frameWidth
                )
                .padding(2)
                .opacity(
                    isAnimating && settings.cellChangeSettings.animateChanges ? 1.0 : 0.7
                )
        }
    }

    // MARK: - Cell Identifier

    /// Unique identifier for this cell to ensure proper SwiftUI updates
    private var cellIdentifier: String {
        // Include all factors that should trigger a cell recreation
        "\(index)-\(field)-\(formatting.displayValue)-\(formatting.changeInfo.hasChanged)-\(settings.cellChangeSettings.highlightStyle.rawValue)-\(settings.tableAppearance.fontSize)-\(settings.tableAppearance.fontWeight)"
    }
}

// MARK: - Preview

#if DEBUG
struct ResultsTableCell_Previews: PreviewProvider {
    static var previews: some View {
        let formatting = CellFormatting(
            field: "count",
            value: "123",
            rawValue: 123,
            changeInfo: CellFormatting.ChangeInfo(
                hasChanged: true,
                changeType: .increased,
                color: .green
            ),
            rowIndex: 0,
            allColumnValues: [100, 123, 145],
            settings: DashboardMonitorSettings.shared,
            vizFormatting: nil,
            fieldsWithNumberFormat: ["count"],
            fieldsWithColorFormat: ["count"]
        )

        ResultsTableCell(
            formatting: formatting,
            field: "count",
            index: 0,
            settings: DashboardMonitorSettings.shared,
            isAnimating: .constant(true)
        )
        .padding()
    }
}
#endif
