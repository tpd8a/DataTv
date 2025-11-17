import Foundation
import SwiftUI
import DashboardKit
import d8aTvCore

// MARK: - Visualization Formatting System

/// Applies Splunk visualization formatting from stored options
/// 
/// Supports per-field formatting rules including:
/// - **Color formatting** (background colors):
///   - `list` palette: Threshold-based colors (e.g., green/yellow/red for values 0-30-70-100)
///   - `minMidMax` palette: Gradient colors based on min/max range
///   - `sharedList`/`sharedCategory` palette: Categorical colors (same values get same color)
///   - `map` palette: Explicit value-to-color mapping (specific values get specific colors)
/// - **Number formatting** (text display):
///   - Units with position (e.g., "£ 100" with unit="£", unitPosition="before")
///   - Precision control (decimal places)
///
/// Example format configuration:
/// ```json
/// {
///   "field": "error",
///   "type": "color",
///   "palette": { "type": "list", "colors": ["#118832", "#D41F1F"] },
///   "scale": { "type": "threshold", "values": [0, 50] }
/// }
/// ```
///
/// Example map palette configuration:
/// ```json
/// {
///   "field": "source",
///   "type": "color",
///   "palette": {
///     "type": "map",
///     "colors": [
///       "{\"\/opt\/splunk\/var\/log\/splunk\/splunkd.log\":#D94E17",
///       "\"\/opt\/splunk\/var\/log\/splunk\/search_messages.log\":#602CA1}"
///     ]
///   }
/// }
/// ```
public struct VisualizationFormatting {

    // Support both old and new visualization types during migration
    private enum VisualizationType {
        case legacy(VisualizationEntity)
        case dashboardKit(Visualization)
    }

    private let vizType: VisualizationType

    // Legacy initializer for VisualizationEntity (d8aTvCore)
    public init(visualization: VisualizationEntity) {
        self.vizType = .legacy(visualization)

        #if DEBUG
        print("🔧 VisualizationFormatting init (legacy) - allOptions keys: \(visualization.allOptions.keys.sorted())")
        if let options = visualization.allOptions["options"] as? [String: String] {
            print("🔧 Options dict has \(options.count) entries")
            if let splunkDefault = options["SplunkDefault"] {
                print("🔧 ✅ SplunkDefault = '\(splunkDefault)'")
            } else {
                print("🔧 ❌ No SplunkDefault key in options")
            }
        } else {
            print("🔧 ❌ No 'options' dict in allOptions")
        }
        if let formats = visualization.allOptions["formats"] as? [[String: Any]] {
            print("🔧 Formats array has \(formats.count) entries")
        } else {
            print("🔧 ❌ No 'formats' array in allOptions")
        }
        #endif
    }

    // New initializer for Visualization (DashboardKit)
    public init(dashboardKitVisualization: Visualization) {
        self.vizType = .dashboardKit(dashboardKitVisualization)

        #if DEBUG
        print("🔧 VisualizationFormatting init (DashboardKit) - allOptions keys: \(dashboardKitVisualization.allOptions.keys.sorted())")
        if let options = dashboardKitVisualization.allOptions["options"] as? [String: String] {
            print("🔧 Options dict has \(options.count) entries")
            if let splunkDefault = options["SplunkDefault"] {
                print("🔧 ✅ SplunkDefault = '\(splunkDefault)'")
            } else {
                print("🔧 ❌ No SplunkDefault key in options")
            }
        } else {
            print("🔧 ❌ No 'options' dict in allOptions")
        }
        if let formats = dashboardKitVisualization.allOptions["formats"] as? [[String: Any]] {
            print("🔧 Formats array has \(formats.count) entries")
        } else {
            print("🔧 ❌ No 'formats' array in allOptions")
        }
        #endif
    }

    // Get allOptions regardless of entity type
    private var allOptionsDict: [String: Any] {
        switch vizType {
        case .legacy(let viz):
            return viz.allOptions
        case .dashboardKit(let viz):
            return viz.allOptions
        }
    }
    
    // MARK: - Options Access

    /// Get all options
    public var options: [String: String] {
        guard let allOptions = allOptionsDict["options"] as? [String: String] else {
            return [:]
        }
        return allOptions
    }

    /// Get all format configurations
    public var formats: [[String: Any]] {
        guard let formatsArray = allOptionsDict["formats"] as? [[String: Any]] else {
            return []
        }
        return formatsArray
    }
    
    /// Get a specific option value
    public func option(_ name: String) -> String? {
        return options[name]
    }
    
    /// Get format configuration for a specific field
    public func format(forField field: String) -> [String: Any]? {
        return formats.first { format in
            guard let formatField = format["field"] as? String else { return false }
            return formatField == field
        }
    }
    
    /// Get format configuration for a specific field and type
    /// Use this when a field might have multiple formats (e.g., both color and number)
    public func format(forField field: String, type: String) -> [String: Any]? {
        return formats.first { format in
            guard let formatField = format["field"] as? String,
                  let formatType = format["type"] as? String else {
                return false
            }
            return formatField == field && formatType == type
        }
    }
    
    /// Get all formats for a specific field
    /// Returns all format configurations that apply to this field
    public func formats(forField field: String) -> [[String: Any]] {
        return formats.filter { format in
            guard let formatField = format["field"] as? String else { return false }
            return formatField == field
        }
    }
    
    /// Get all formats of a specific type
    public func formats(ofType type: String) -> [[String: Any]] {
        return formats.filter { format in
            guard let formatType = format["type"] as? String else { return false }
            return formatType == type
        }
    }
    
    // MARK: - Table Display Options
    
    /// Number of rows to display in table
    public var tableRowCount: Int {
        guard let countStr = option("count"), let count = Int(countStr) else {
            return 10 // Default
        }
        return count
    }
    
    /// Whether to show row numbers column
    public var showRowNumbers: Bool {
        return option("rowNumbers") == "true"
    }
    
    /// Whether to wrap text in cells
    public var wrapText: Bool {
        // Check for "true" explicitly since Splunk uses string "true"/"false"
        return option("wrap") == "true"
    }
    
    /// Whether to show totals row
    public var showTotalsRow: Bool {
        return option("totalsRow") == "true"
    }
    
    /// Whether to show percentages row
    public var showPercentagesRow: Bool {
        return option("percentagesRow") == "true"
    }
    
    /// Drilldown behavior
    public enum DrilldownMode {
        case none
        case row
        case cell
        
        init(from string: String?) {
            switch string?.lowercased() {
            case "row": self = .row
            case "cell": self = .cell
            default: self = .none
            }
        }
    }
    
    public var drilldownMode: DrilldownMode {
        return DrilldownMode(from: option("drilldown"))
    }
    
    // MARK: - Field Formatting
    
    /// Check if a field has any formatting defined
    public func hasFormatting(forField field: String) -> Bool {
        return formats.contains { format in
            guard let formatField = format["field"] as? String else { return false }
            return formatField == field
        }
    }
    
    /// Check if a field has number formatting defined
    public func hasNumberFormatting(forField field: String) -> Bool {
        return format(forField: field, type: "number") != nil
    }
    
    /// Check if a field has color formatting defined
    public func hasColorFormatting(forField field: String) -> Bool {
        return format(forField: field, type: "color") != nil
    }
    
    /// Get all fields that have number formatting
    public var fieldsWithNumberFormatting: [String] {
        return formats(ofType: "number").compactMap { $0["field"] as? String }
    }
    
    /// Get all fields that have color formatting
    public var fieldsWithColorFormatting: [String] {
        return formats(ofType: "color").compactMap { $0["field"] as? String }
    }
    
    /// Apply color formatting to a field value
    /// Returns a color that should be applied to the cell background, not text
    /// - Parameters:
    ///   - field: The field name
    ///   - value: The cell value
    ///   - allValues: Optional array of all values in this column (needed for minMidMax gradients)
    public func applyColorFormatting(field: String, value: Any, allValues: [Any]? = nil) -> Color? {
        // Use type-specific lookup to avoid conflict with number formats on the same field
        guard let colorFormat = format(forField: field, type: "color") else {
            #if DEBUG
            print("    🔧 applyColorFormatting: No color format found for field '\(field)'")
            #endif
            return nil
        }
        
        #if DEBUG
        print("    🔧 applyColorFormatting: Found color format for field '\(field)'")
        print("    🔧   colorFormat keys: \(colorFormat.keys.sorted())")
        #endif
        
        guard let palette = colorFormat["palette"] as? [String: Any],
              let paletteType = palette["type"] as? String else {
            #if DEBUG
            print("    🔧 applyColorFormatting: No palette or paletteType found")
            if let palette = colorFormat["palette"] {
                print("    🔧   palette type: \(type(of: palette))")
            } else {
                print("    🔧   palette is nil")
            }
            #endif
            return nil
        }
        
        #if DEBUG
        print("    🔧   palette type: '\(paletteType)'")
        print("    🔧   palette keys: \(palette.keys.sorted())")
        #endif
        
        let resultColor: Color?
        
        switch paletteType {
        case "list":
            #if DEBUG
            print("    🔧   → Using 'list' palette (threshold-based)")
            #endif
            // Threshold-based numeric coloring
            guard let numericValue = extractNumericValue(from: value) else {
                #if DEBUG
                print("    🔧   → ❌ Could not extract numeric value from: \(value)")
                #endif
                return nil
            }
            resultColor = applyListColorFormat(numericValue: numericValue, palette: palette, format: colorFormat)
            
        case "minMidMax":
            #if DEBUG
            print("    🔧   → Using 'minMidMax' palette (gradient)")
            #endif
            // Gradient-based numeric coloring - needs min/max from actual data
            guard let numericValue = extractNumericValue(from: value) else {
                #if DEBUG
                print("    🔧   → ❌ Could not extract numeric value from: \(value)")
                #endif
                return nil
            }
            // Calculate min/max from all values if provided
            var minValue: Double = 0
            var maxValue: Double = 100
            
            if let values = allValues, !values.isEmpty {
                let numericValues = values.compactMap { extractNumericValue(from: $0) }
                if !numericValues.isEmpty {
                    minValue = numericValues.min() ?? 0
                    maxValue = numericValues.max() ?? 100
                }
            }
            
            resultColor = applyMinMidMaxColorFormat(
                numericValue: numericValue,
                palette: palette,
                minValue: minValue,
                maxValue: maxValue
            )
            
        case "sharedList", "sharedCategory":
            #if DEBUG
            print("    🔧   → Using 'sharedList/sharedCategory' palette (categorical)")
            print("    🔧   → value: '\(value)'")
            #endif
            // Categorical coloring - each unique value gets a consistent color
            resultColor = applySharedCategoryColorFormat(value: value, palette: palette)
            
        case "map":
            #if DEBUG
            print("    🔧   → Using 'map' palette (explicit mapping)")
            print("    🔧   → value: '\(value)'")
            #endif
            // Explicit value-to-color mapping
            resultColor = applyMapColorFormat(value: value, palette: palette)
            
        default:
            #if DEBUG
            print("    🔧   → ⚠️ Unknown palette type: '\(paletteType)'")
            #endif
            resultColor = nil
        }
        
        #if DEBUG
        print("    🔧   → Final result color: \(resultColor != nil ? "✅ Color" : "❌ nil")")
        #endif
        
        return resultColor
    }
    
    /// Extract numeric value from Any type
    private func extractNumericValue(from value: Any) -> Double? {
        if let doubleValue = value as? Double {
            return doubleValue
        } else if let intValue = value as? Int {
            return Double(intValue)
        } else if let stringValue = value as? String, let parsedValue = Double(stringValue) {
            return parsedValue
        }
        return nil
    }
    
    /// Apply list-based color formatting (threshold-based)
    private func applyListColorFormat(numericValue: Double, palette: [String: Any], format: [String: Any]) -> Color? {
        guard let colors = palette["colors"] as? [String] else { return nil }
        guard let scale = format["scale"] as? [String: Any],
              let thresholds = scale["values"] as? [Double] else {
            // No scale, return first color
            return parseColor(colors.first)
        }
        
        // Find which threshold bucket the value falls into
        var colorIndex = 0
        for threshold in thresholds {
            if numericValue >= threshold {
                colorIndex += 1
            } else {
                break
            }
        }
        
        // Clamp to valid color index
        colorIndex = min(colorIndex, colors.count - 1)
        
        return parseColor(colors[colorIndex])
    }
    
    /// Apply min/mid/max gradient color formatting
    private func applyMinMidMaxColorFormat(
        numericValue: Double,
        palette: [String: Any],
        minValue: Double,
        maxValue: Double
    ) -> Color? {
        guard let minColorStr = palette["minColor"] as? String,
              let maxColorStr = palette["maxColor"] as? String else {
            return nil
        }
        
        guard let minColor = parseColor(minColorStr),
              let maxColor = parseColor(maxColorStr) else {
            return nil
        }
        
        // Normalize value between 0 and 1 based on actual data range
        let range = maxValue - minValue
        let normalizedValue: Double
        
        if range > 0 {
            normalizedValue = min(max((numericValue - minValue) / range, 0.0), 1.0)
        } else {
            // All values are the same
            normalizedValue = 0.5
        }
        
        return interpolateColor(from: minColor, to: maxColor, fraction: normalizedValue)
    }
    
    /// Apply shared category/list color formatting (categorical coloring)
    /// Each unique value gets a consistent color from a predefined palette
    private func applySharedCategoryColorFormat(value: Any, palette: [String: Any]) -> Color? {
        // Convert value to string for consistent hashing
        let stringValue: String
        if let str = value as? String {
            stringValue = str
        } else {
            stringValue = String(describing: value)
        }
        
        // Use a predefined color palette (Splunk's default categorical colors)
        let defaultCategoricalColors = [
            "#7B56DB", // Purple
            "#FF6B6B", // Red
            "#4ECDC4", // Cyan
            "#FFE66D", // Yellow
            "#95E1D3", // Mint
            "#F38181", // Pink
            "#AA96DA", // Lavender
            "#FCBAD3", // Light Pink
            "#A8D8EA", // Light Blue
            "#FFAAA5", // Peach
            "#3D84A8", // Dark Blue
            "#46CDCF", // Turquoise
            "#ABEDD8", // Light Green
            "#48466D", // Dark Purple
            "#F7DB6A", // Gold
        ]
        
        // Check if custom colors are provided in the palette
        let colors: [String]
        if let customColors = palette["colors"] as? [String], !customColors.isEmpty {
            colors = customColors
        } else {
            colors = defaultCategoricalColors
        }
        
        // Generate a stable index based on the string value
        let hash = abs(stringValue.hashValue)
        let colorIndex = hash % colors.count
        
        return parseColor(colors[colorIndex])
    }
    
    /// Apply map-based color formatting (explicit value-to-color mapping)
    /// Maps specific cell values to specific colors using key:value pairs
    private func applyMapColorFormat(value: Any, palette: [String: Any]) -> Color? {
        // Convert value to string for matching
        let stringValue: String
        if let str = value as? String {
            stringValue = str
        } else {
            stringValue = String(describing: value)
        }
        
        #if DEBUG
        print("      🔧 applyMapColorFormat: stringValue = '\(stringValue)'")
        #endif
        
        // Get the color mappings
        guard let colors = palette["colors"] as? [String] else {
            #if DEBUG
            print("      🔧 applyMapColorFormat: ❌ No colors array in palette")
            if let colorsValue = palette["colors"] {
                print("      🔧   colors type: \(type(of: colorsValue))")
            }
            #endif
            return nil
        }
        
        #if DEBUG
        print("      🔧 applyMapColorFormat: colors array has \(colors.count) entries")
        for (idx, color) in colors.enumerated() {
            print("      🔧   colors[\(idx)]: '\(color)'")
        }
        #endif
        
        // Parse the color mappings
        // Format can be either:
        // 1. JSON-like string: "{\"value1\":#COLOR1,\"value2\":#COLOR2}"
        // 2. Array of separate mappings: ["{\"value1\":#COLOR1", "\"value2\":#COLOR2}"]
        
        var colorMap: [String: String] = [:]
        
        for colorEntry in colors {
            // Parse each entry
            // Handle both complete JSON objects and fragments
            var entry = colorEntry.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Remove leading/trailing braces if present
            if entry.hasPrefix("{") {
                entry = String(entry.dropFirst())
            }
            if entry.hasSuffix("}") {
                entry = String(entry.dropLast())
            }
            
            // Split by comma to handle multiple mappings in one string
            let mappings = entry.components(separatedBy: ",")
            
            for mapping in mappings {
                // Each mapping should be in format: "key":value or \"key\":value
                let parts = mapping.components(separatedBy: ":")
                guard parts.count == 2 else {
                    #if DEBUG
                    print("      🔧   ⚠️ Skipping malformed mapping: '\(mapping)'")
                    #endif
                    continue
                }
                
                let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"\\"))
                let color = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                
                colorMap[key] = color
                
                #if DEBUG
                print("      🔧   Parsed mapping: '\(key)' → '\(color)'")
                #endif
            }
        }
        
        #if DEBUG
        print("      🔧 applyMapColorFormat: Final colorMap has \(colorMap.count) entries")
        #endif
        
        // Look up the value in the map
        if let colorHex = colorMap[stringValue] {
            #if DEBUG
            print("      🔧 applyMapColorFormat: ✅ Found mapping for '\(stringValue)' → '\(colorHex)'")
            #endif
            let parsedColor = parseColor(colorHex)
            #if DEBUG
            print("      🔧 applyMapColorFormat: Parsed color: \(parsedColor != nil ? "✅" : "❌")")
            #endif
            return parsedColor
        }
        
        #if DEBUG
        print("      🔧 applyMapColorFormat: ❌ No mapping found for '\(stringValue)'")
        print("      🔧   Available keys: \(colorMap.keys.sorted())")
        #endif
        
        return nil
    }
    
    /// Apply number formatting to a field value
    /// Returns nil if no format is defined for this field (which is normal and expected)
    public func applyNumberFormatting(field: String, value: Any) -> String? {
        // Use type-specific lookup to avoid conflict with color formats on the same field
        guard let numberFormat = format(forField: field, type: "number") else {
            // No number format defined for this field - this is normal and expected
            return nil
        }
        
        // Get numeric value
        let numericValue: Double
        if let doubleValue = value as? Double {
            numericValue = doubleValue
        } else if let intValue = value as? Int {
            numericValue = Double(intValue)
        } else if let stringValue = value as? String, let parsedValue = Double(stringValue) {
            numericValue = parsedValue
        } else {
            return nil
        }
        
        // Get formatting options
        let unit = numberFormat["unit"] as? String ?? ""
        let unitPosition = numberFormat["unitPosition"] as? String ?? "after"
        let precisionStr = numberFormat["precision"] as? String
        let precision = precisionStr.flatMap { Int($0) } ?? 0
        
        // Format the number
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = precision
        formatter.maximumFractionDigits = precision
        
        guard let formattedNumber = formatter.string(from: NSNumber(value: numericValue)) else {
            return nil
        }
        
        // Apply unit with proper spacing
        let formattedValue: String
        if !unit.isEmpty {
            if unitPosition == "before" {
                // Add space after unit for readability (e.g., "£ 100" instead of "£100")
                formattedValue = "\(unit) \(formattedNumber)"
            } else {
                // Add space before unit for readability (e.g., "100 USD" instead of "100USD")
                formattedValue = "\(formattedNumber) \(unit)"
            }
        } else {
            formattedValue = formattedNumber
        }
        
        return formattedValue
    }
    
    // MARK: - Helper Methods
    
    /// Parse color from hex string
    private func parseColor(_ hexString: String?) -> Color? {
        guard let hex = hexString?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return nil
        }
        
        var cleanHex = hex
        if cleanHex.hasPrefix("#") {
            cleanHex = String(cleanHex.dropFirst())
        }
        
        guard cleanHex.count == 6 else { return nil }
        
        var rgb: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&rgb)
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        return Color(red: r, green: g, blue: b)
    }
    
    /// Interpolate between two colors using RGB linear interpolation
    private func interpolateColor(from fromColor: Color, to toColor: Color, fraction: Double) -> Color {
        // Extract RGB components from hex colors
        // We need to work with the resolved colors
        
        #if os(macOS)
        let fromNSColor = NSColor(fromColor)
        let toNSColor = NSColor(toColor)
        
        // Convert to RGB color space
        guard let fromRGB = fromNSColor.usingColorSpace(.deviceRGB),
              let toRGB = toNSColor.usingColorSpace(.deviceRGB) else {
            // Fallback to threshold-based selection
            return fraction < 0.5 ? fromColor : toColor
        }
        
        // Interpolate each component
        let r = fromRGB.redComponent + (toRGB.redComponent - fromRGB.redComponent) * fraction
        let g = fromRGB.greenComponent + (toRGB.greenComponent - fromRGB.greenComponent) * fraction
        let b = fromRGB.blueComponent + (toRGB.blueComponent - fromRGB.blueComponent) * fraction
        
        return Color(red: r, green: g, blue: b)
        #else
        let fromUIColor = UIColor(fromColor)
        let toUIColor = UIColor(toColor)
        
        var fromR: CGFloat = 0, fromG: CGFloat = 0, fromB: CGFloat = 0, fromA: CGFloat = 0
        var toR: CGFloat = 0, toG: CGFloat = 0, toB: CGFloat = 0, toA: CGFloat = 0
        
        fromUIColor.getRed(&fromR, green: &fromG, blue: &fromB, alpha: &fromA)
        toUIColor.getRed(&toR, green: &toG, blue: &toB, alpha: &toA)
        
        // Interpolate each component
        let r = fromR + (toR - fromR) * fraction
        let g = fromG + (toG - fromG) * fraction
        let b = fromB + (toB - fromB) * fraction
        
        return Color(red: Double(r), green: Double(g), blue: Double(b))
        #endif
    }
}

// MARK: - SwiftUI View Extensions

extension View {
    /// Apply visualization formatting to a table cell
    public func applyVisualizationFormatting(
        formatting: VisualizationFormatting,
        field: String,
        value: Any
    ) -> some View {
        self.modifier(VisualizationFormattingModifier(
            formatting: formatting,
            field: field,
            value: value
        ))
    }
}

struct VisualizationFormattingModifier: ViewModifier {
    let formatting: VisualizationFormatting
    let field: String
    let value: Any
    
    func body(content: Content) -> some View {
        content
            .foregroundColor(formatting.applyColorFormatting(field: field, value: value))
    }
}
