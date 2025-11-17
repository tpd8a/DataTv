import SwiftUI
import Foundation

/// Holds all formatting calculations for a table cell
/// CRITICAL: This struct calculates formatting in the EXACT order required to honor Splunk defaults
struct CellFormatting {
    let displayValue: String
    let backgroundColor: Color
    let textColor: Color
    let splunkBackgroundColor: Color?

    /// Change information for this cell
    struct ChangeInfo {
        let hasChanged: Bool
        let changeType: ChangeType
        let color: Color

        enum ChangeType {
            case none
            case increased
            case decreased
            case modified
        }
    }

    let changeInfo: ChangeInfo

    // MARK: - Initialization with CORRECT PRIORITY ORDER

    /// Initialize cell formatting with proper priority order
    /// ORDER: Splunk number format → Splunk colors → User settings → Change indicators
    init(
        field: String,
        value: String,
        rawValue: Any?,
        changeInfo: ChangeInfo,
        rowIndex: Int,
        allColumnValues: [Any?],
        settings: DashboardMonitorSettings,
        vizFormatting: VisualizationFormatting?,
        fieldsWithNumberFormat: Set<String>,
        fieldsWithColorFormat: Set<String>
    ) {
        self.changeInfo = changeInfo

        // STEP 1: Apply Splunk number formatting FIRST (if field has number formatting)
        if fieldsWithNumberFormat.contains(field),
           let formatting = vizFormatting,
           let formattedValue = formatting.applyNumberFormatting(field: field, value: rawValue ?? value) {
            self.displayValue = formattedValue
        } else {
            self.displayValue = value
        }

        // STEP 2: Calculate Splunk background color (if in Splunk Default mode AND field has color format)
        let shouldUseSplunkColors = settings.cellChangeSettings.highlightStyle == .splunkDefault

        self.splunkBackgroundColor = {
            guard shouldUseSplunkColors && fieldsWithColorFormat.contains(field),
                  let formatting = vizFormatting else {
                return nil
            }

            return formatting.applyColorFormatting(
                field: field,
                value: rawValue ?? value,
                allValues: allColumnValues
            )
        }()

        // STEP 3: Calculate final background color with CORRECT PRIORITY ORDER
        self.backgroundColor = Self.calculateBackgroundColor(
            shouldUseSplunkColors: shouldUseSplunkColors,
            splunkColor: splunkBackgroundColor,
            changeInfo: changeInfo,
            settings: settings
        )

        // STEP 4: Calculate text color
        self.textColor = Self.calculateTextColor(
            shouldUseSplunkColors: shouldUseSplunkColors,
            splunkBackgroundColor: splunkBackgroundColor,
            changeInfo: changeInfo,
            settings: settings,
            vizFormatting: vizFormatting,
            field: field,
            value: rawValue ?? value
        )
    }

    // MARK: - Background Color Calculation (CORRECTED PRIORITY ORDER)

    private static func calculateBackgroundColor(
        shouldUseSplunkColors: Bool,
        splunkColor: Color?,
        changeInfo: ChangeInfo,
        settings: DashboardMonitorSettings
    ) -> Color {
        // PRIORITY 1: In Splunk Default mode, Splunk colors take ABSOLUTE priority
        if shouldUseSplunkColors, let splunkColor = splunkColor {
            return splunkColor.opacity(0.7)
        }

        // PRIORITY 2: Custom cell background (if enabled globally)
        if settings.tableAppearance.useCustomCellBackground {
            return settings.tableAppearance.customCellBackgroundColor
        }

        // PRIORITY 3: Apply change highlighting (if cell changed and NOT in Splunk Default mode)
        if changeInfo.hasChanged && !shouldUseSplunkColors {
            switch settings.cellChangeSettings.highlightStyle {
            case .splunkDefault:
                // Should not reach here
                break

            case .systemColors:
                return Color.accentColor.opacity(settings.cellChangeSettings.fillOpacity)

            case .customColor:
                return settings.cellChangeSettings.customColor.opacity(settings.cellChangeSettings.fillOpacity)

            case .directional:
                return changeInfo.color.opacity(settings.cellChangeSettings.fillOpacity)
            }
        }

        // PRIORITY 4: No special formatting
        return .clear
    }

    // MARK: - Text Color Calculation

    private static func calculateTextColor(
        shouldUseSplunkColors: Bool,
        splunkBackgroundColor: Color?,
        changeInfo: ChangeInfo,
        settings: DashboardMonitorSettings,
        vizFormatting: VisualizationFormatting?,
        field: String,
        value: Any
    ) -> Color {
        // PRIORITY 1: Splunk text color (if in Splunk Default mode and has background color)
        if shouldUseSplunkColors,
           let _ = splunkBackgroundColor,
           let formatting = vizFormatting,
           let textColor = formatting.getTextColor(field: field, value: value) {
            return textColor
        }

        // PRIORITY 2: User custom color for changed cells
        if changeInfo.hasChanged,
           let changedTextColor = settings.tableAppearance.changedCellTextColor {
            return changedTextColor
        }

        // PRIORITY 3: User custom color for normal cells
        if let customTextColor = settings.tableAppearance.customTextColor {
            return customTextColor
        }

        // PRIORITY 4: System default
        return .primary
    }
}

// MARK: - Helper Extensions

extension VisualizationFormatting {
    /// Get text color for a field/value combination
    /// This should be implemented based on your VisualizationFormatting logic
    func getTextColor(field: String, value: Any) -> Color? {
        // TODO: Implement based on your Splunk text color formatting rules
        // This is called AFTER background color is determined
        return nil
    }
}
