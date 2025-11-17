import SwiftUI
import Foundation
import Combine

// MARK: - Cell Change Settings

/// Settings for how cell changes are displayed in the results table
struct CellChangeSettings: Equatable {
    enum HighlightStyle: String, CaseIterable, Identifiable {
        case splunkDefault = "Splunk Default"
        case systemColors = "System Colors"
        case customColor = "Custom Color"
        case directional = "Directional (↑Green/↓Red)"

        var id: String { rawValue }

        var description: String {
            switch self {
            case .splunkDefault: return "Use Splunk's color formatting (no change indicators)"
            case .systemColors: return "Use system accent color for changes"
            case .customColor: return "Choose custom color for changes"
            case .directional: return "Green for increases, red for decreases"
            }
        }
    }

    var highlightStyle: HighlightStyle = .customColor
    var customColor: Color = .orange
    var fillOpacity: Double = 0.3
    var frameWidth: Double = 2.0
    var showOverlay: Bool = true
    var animateChanges: Bool = true
    var animationDuration: Double = 1.5

    var increaseColor: Color = Color(red: 0.2, green: 0.7, blue: 0.3)
    var decreaseColor: Color = Color(red: 0.9, green: 0.3, blue: 0.3)

    static func == (lhs: CellChangeSettings, rhs: CellChangeSettings) -> Bool {
        return lhs.highlightStyle == rhs.highlightStyle &&
               lhs.customColor == rhs.customColor &&
               lhs.fillOpacity == rhs.fillOpacity &&
               lhs.frameWidth == rhs.frameWidth &&
               lhs.showOverlay == rhs.showOverlay &&
               lhs.animateChanges == rhs.animateChanges &&
               lhs.animationDuration == rhs.animationDuration &&
               lhs.increaseColor == rhs.increaseColor &&
               lhs.decreaseColor == rhs.decreaseColor
    }
}

// MARK: - Table Appearance Settings

/// Settings for table visual appearance
struct TableAppearanceSettings: Equatable {
    var customTextColor: Color? = nil
    var changedCellTextColor: Color? = nil

    var fontDesign: Font.Design = .default
    var fontSize: Double = 13
    var fontWeight: Font.Weight = .regular
    var isItalic: Bool = false

    var useCustomCellBackground: Bool = false
    var customCellBackgroundColor: Color = Color.clear

    var enableZebraStriping: Bool = true
    var zebraStripeOpacity: Double = 0.15

    static func == (lhs: TableAppearanceSettings, rhs: TableAppearanceSettings) -> Bool {
        return lhs.customTextColor == rhs.customTextColor &&
               lhs.changedCellTextColor == rhs.changedCellTextColor &&
               lhs.fontDesign == rhs.fontDesign &&
               lhs.fontSize == rhs.fontSize &&
               lhs.fontWeight == rhs.fontWeight &&
               lhs.isItalic == rhs.isItalic &&
               lhs.useCustomCellBackground == rhs.useCustomCellBackground &&
               lhs.customCellBackgroundColor == rhs.customCellBackgroundColor &&
               lhs.enableZebraStriping == rhs.enableZebraStriping &&
               lhs.zebraStripeOpacity == rhs.zebraStripeOpacity
    }
}

// MARK: - Table View Preferences

/// Stores table view preferences for a specific dashboard/search combination
struct TableViewPreferences: Codable {
    var sortField: String?
    var sortAscending: Bool = true
    var columnWidths: [String: Double] = [:]

    var key: String {
        return "\(sortField ?? "none")_\(sortAscending)_\(columnWidths.count)"
    }
}

// MARK: - Settings Manager

class DashboardMonitorSettings: ObservableObject {
    static let shared = DashboardMonitorSettings()

    @Published var cellChangeSettings = CellChangeSettings()
    @Published var tableAppearance = TableAppearanceSettings()
    private var tablePreferences: [String: TableViewPreferences] = [:]

    private init() {
        loadSettings()
        loadTablePreferences()
    }

    // MARK: - Settings Persistence

    func loadSettings() {
        loadCellChangeSettings()
        loadTableAppearanceSettings()
    }

    private func loadCellChangeSettings() {
        if let styleRaw = UserDefaults.standard.string(forKey: "cellHighlightStyle"),
           let style = CellChangeSettings.HighlightStyle(rawValue: styleRaw) {
            cellChangeSettings.highlightStyle = style
        }

        #if os(macOS)
        if let colorData = UserDefaults.standard.data(forKey: "cellCustomColor"),
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) {
            cellChangeSettings.customColor = Color(color)
        }
        #endif

        let fillOpacity = UserDefaults.standard.double(forKey: "cellFillOpacity")
        cellChangeSettings.fillOpacity = fillOpacity > 0 ? fillOpacity : 0.3

        let frameWidth = UserDefaults.standard.double(forKey: "cellFrameWidth")
        cellChangeSettings.frameWidth = frameWidth > 0 ? frameWidth : 2.0

        if UserDefaults.standard.object(forKey: "cellShowOverlay") != nil {
            cellChangeSettings.showOverlay = UserDefaults.standard.bool(forKey: "cellShowOverlay")
        }

        if UserDefaults.standard.object(forKey: "cellAnimateChanges") != nil {
            cellChangeSettings.animateChanges = UserDefaults.standard.bool(forKey: "cellAnimateChanges")
        }

        let animationDuration = UserDefaults.standard.double(forKey: "cellAnimationDuration")
        cellChangeSettings.animationDuration = animationDuration > 0 ? animationDuration : 1.5
    }

    private func loadTableAppearanceSettings() {
        #if os(macOS)
        if let textColorData = UserDefaults.standard.data(forKey: "tableCustomTextColor"),
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: textColorData) {
            tableAppearance.customTextColor = Color(color)
        }

        if let changedTextColorData = UserDefaults.standard.data(forKey: "tableChangedCellTextColor"),
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: changedTextColorData) {
            tableAppearance.changedCellTextColor = Color(color)
        }

        if let bgColorData = UserDefaults.standard.data(forKey: "tableCellBackgroundColor"),
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: bgColorData) {
            tableAppearance.customCellBackgroundColor = Color(color)
        }
        #endif

        if UserDefaults.standard.object(forKey: "tableUseCustomCellBackground") != nil {
            tableAppearance.useCustomCellBackground = UserDefaults.standard.bool(forKey: "tableUseCustomCellBackground")
        }

        if UserDefaults.standard.object(forKey: "tableEnableZebraStriping") != nil {
            tableAppearance.enableZebraStriping = UserDefaults.standard.bool(forKey: "tableEnableZebraStriping")
        }

        let zebraOpacity = UserDefaults.standard.double(forKey: "tableZebraStripeOpacity")
        tableAppearance.zebraStripeOpacity = zebraOpacity > 0 ? zebraOpacity : 0.15

        loadFontSettings()
    }

    private func loadFontSettings() {
        if let fontDesignRaw = UserDefaults.standard.string(forKey: "tableFontDesign") {
            switch fontDesignRaw {
            case "serif": tableAppearance.fontDesign = .serif
            case "rounded": tableAppearance.fontDesign = .rounded
            case "monospaced": tableAppearance.fontDesign = .monospaced
            default: tableAppearance.fontDesign = .default
            }
        }

        let fontSize = UserDefaults.standard.double(forKey: "tableFontSize")
        tableAppearance.fontSize = fontSize > 0 ? fontSize : 13

        if let fontWeightRaw = UserDefaults.standard.string(forKey: "tableFontWeight") {
            tableAppearance.fontWeight = fontWeightFromString(fontWeightRaw)
        }

        if UserDefaults.standard.object(forKey: "tableFontIsItalic") != nil {
            tableAppearance.isItalic = UserDefaults.standard.bool(forKey: "tableFontIsItalic")
        }
    }

    func saveSettings() {
        saveCellChangeSettings()
        saveTableAppearanceSettings()

        let updatedCellSettings = cellChangeSettings
        let updatedTableAppearance = tableAppearance

        cellChangeSettings = updatedCellSettings
        tableAppearance = updatedTableAppearance

        print("✅ Settings saved and UI update triggered")
    }

    private func saveCellChangeSettings() {
        UserDefaults.standard.set(cellChangeSettings.highlightStyle.rawValue, forKey: "cellHighlightStyle")

        #if os(macOS)
        if let colorData = try? NSKeyedArchiver.archivedData(withRootObject: NSColor(cellChangeSettings.customColor), requiringSecureCoding: false) {
            UserDefaults.standard.set(colorData, forKey: "cellCustomColor")
        }
        #endif

        UserDefaults.standard.set(cellChangeSettings.fillOpacity, forKey: "cellFillOpacity")
        UserDefaults.standard.set(cellChangeSettings.frameWidth, forKey: "cellFrameWidth")
        UserDefaults.standard.set(cellChangeSettings.showOverlay, forKey: "cellShowOverlay")
        UserDefaults.standard.set(cellChangeSettings.animateChanges, forKey: "cellAnimateChanges")
        UserDefaults.standard.set(cellChangeSettings.animationDuration, forKey: "cellAnimationDuration")
    }

    private func saveTableAppearanceSettings() {
        #if os(macOS)
        if let textColor = tableAppearance.customTextColor {
            if let colorData = try? NSKeyedArchiver.archivedData(withRootObject: NSColor(textColor), requiringSecureCoding: false) {
                UserDefaults.standard.set(colorData, forKey: "tableCustomTextColor")
            }
        } else {
            UserDefaults.standard.removeObject(forKey: "tableCustomTextColor")
        }

        if let changedTextColor = tableAppearance.changedCellTextColor {
            if let colorData = try? NSKeyedArchiver.archivedData(withRootObject: NSColor(changedTextColor), requiringSecureCoding: false) {
                UserDefaults.standard.set(colorData, forKey: "tableChangedCellTextColor")
            }
        } else {
            UserDefaults.standard.removeObject(forKey: "tableChangedCellTextColor")
        }

        if let bgColor = tableAppearance.customCellBackgroundColor as Color? {
            if let colorData = try? NSKeyedArchiver.archivedData(withRootObject: NSColor(bgColor), requiringSecureCoding: false) {
                UserDefaults.standard.set(colorData, forKey: "tableCellBackgroundColor")
            }
        }
        #endif

        UserDefaults.standard.set(tableAppearance.useCustomCellBackground, forKey: "tableUseCustomCellBackground")
        UserDefaults.standard.set(tableAppearance.enableZebraStriping, forKey: "tableEnableZebraStriping")
        UserDefaults.standard.set(tableAppearance.zebraStripeOpacity, forKey: "tableZebraStripeOpacity")

        UserDefaults.standard.set(fontDesignToString(tableAppearance.fontDesign), forKey: "tableFontDesign")
        UserDefaults.standard.set(tableAppearance.fontSize, forKey: "tableFontSize")
        UserDefaults.standard.set(fontWeightToString(tableAppearance.fontWeight), forKey: "tableFontWeight")
        UserDefaults.standard.set(tableAppearance.isItalic, forKey: "tableFontIsItalic")
    }

    // MARK: - Table Preferences

    private func loadTablePreferences() {
        guard let data = UserDefaults.standard.data(forKey: "tableViewPreferences"),
              let decoded = try? JSONDecoder().decode([String: TableViewPreferences].self, from: data) else {
            return
        }
        tablePreferences = decoded
    }

    private func saveTablePreferences() {
        guard let encoded = try? JSONEncoder().encode(tablePreferences) else {
            return
        }
        UserDefaults.standard.set(encoded, forKey: "tableViewPreferences")
    }

    func getTablePreferences(dashboardId: String, searchId: String) -> TableViewPreferences {
        let key = "\(dashboardId):\(searchId)"
        return tablePreferences[key] ?? TableViewPreferences()
    }

    func setTablePreferences(_ preferences: TableViewPreferences, dashboardId: String, searchId: String) {
        let key = "\(dashboardId):\(searchId)"
        tablePreferences[key] = preferences
        saveTablePreferences()
    }

    func clearTablePreferences(dashboardId: String, searchId: String) {
        let key = "\(dashboardId):\(searchId)"
        tablePreferences.removeValue(forKey: key)
        saveTablePreferences()
    }

    // MARK: - Helper Methods

    private func fontDesignToString(_ design: Font.Design) -> String {
        switch design {
        case .default: return "default"
        case .serif: return "serif"
        case .rounded: return "rounded"
        case .monospaced: return "monospaced"
        @unknown default: return "default"
        }
    }

    private func fontWeightToString(_ weight: Font.Weight) -> String {
        switch weight {
        case .ultraLight: return "ultraLight"
        case .thin: return "thin"
        case .light: return "light"
        case .regular: return "regular"
        case .medium: return "medium"
        case .semibold: return "semibold"
        case .bold: return "bold"
        case .heavy: return "heavy"
        case .black: return "black"
        default: return "regular"
        }
    }

    private func fontWeightFromString(_ string: String) -> Font.Weight {
        switch string {
        case "ultraLight": return .ultraLight
        case "thin": return .thin
        case "light": return .light
        case "medium": return .medium
        case "semibold": return .semibold
        case "bold": return .bold
        case "heavy": return .heavy
        case "black": return .black
        default: return .regular
        }
    }
}
