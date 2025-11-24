import Foundation
import DashboardKit

/// Adapter that bridges DashboardKit's DashboardInput to the token interface expected by UI
/// Handles parsing of JSON fields and provides backwards-compatible interface
public struct TokenAdapter: Identifiable {
    public let id = UUID()
    public let input: DashboardInput

    // MARK: - Basic Properties

    public var name: String {
        input.token ?? input.inputId ?? "unknown"
    }

    public var label: String? {
        input.title
    }

    public var type: String {
        // Extract type from input.type (e.g., "input.dropdown" -> "dropdown")
        if let inputType = input.type {
            return inputType.replacingOccurrences(of: "input.", with: "")
        }
        return "text"
    }

    public var defaultValue: String? {
        input.defaultValue
    }

    // MARK: - Parsed Options

    /// Parse optionsJSON to get structured options
    public var parsedOptions: InputOptions? {
        guard let optionsJSON = input.optionsJSON,
              let data = optionsJSON.data(using: .utf8) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(InputOptions.self, from: data)
        } catch {
            print("⚠️ Failed to parse optionsJSON for input '\(name)': \(error)")
            return nil
        }
    }

    /// Get choices for dropdown, radio, multiselect, etc.
    public var choices: [InputChoice] {
        guard let options = parsedOptions,
              let choicesData = options.choices else {
            return []
        }

        return choicesData.map { choiceData in
            InputChoice(
                label: choiceData.label,
                value: choiceData.value,
                isDefault: choiceData.isDefault ?? false,
                disabled: choiceData.disabled ?? false
            )
        }
    }

    /// Get initial value (priority: defaultValue > first choice)
    public var initialValue: String? {
        if let defaultVal = defaultValue, !defaultVal.isEmpty {
            return defaultVal
        }

        // Return first choice value if available
        return choices.first?.value
    }

    /// Get change handler if present
    public var changeHandler: InputChangeHandler? {
        return parsedOptions?.changeHandler
    }

    /// Get the label for a given value (from choices)
    public func getLabel(forValue value: String) -> String? {
        return choices.first(where: { $0.value == value })?.label
    }

    // MARK: - Initialization

    public init(input: DashboardInput) {
        self.input = input
    }
}

// MARK: - Collection Helpers

extension Collection where Element == DashboardInput {
    /// Convert collection of DashboardInput to TokenAdapter array
    public var asTokenAdapters: [TokenAdapter] {
        return map { TokenAdapter(input: $0) }
    }
}
