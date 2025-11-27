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
            // Check if default matches a choice value directly
            if choices.contains(where: { $0.value == defaultVal }) {
                return defaultVal
            }

            // If not, check if it matches a label and return that choice's value
            if let matchingChoice = choices.first(where: { $0.label == defaultVal }) {
                print("⚠️ Default '\(defaultVal)' is a label, using value '\(matchingChoice.value)' instead")
                return matchingChoice.value
            }

            // Otherwise use the default as-is (for text inputs, etc.)
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

    // MARK: - Token Formatting Properties

    /// Prefix for token value (all types)
    public var prefix: String? {
        return parsedOptions?.prefix
    }

    /// Suffix for token value (all types)
    public var suffix: String? {
        return parsedOptions?.suffix
    }

    /// Prefix for each selected value (multiselect)
    public var valuePrefix: String? {
        return parsedOptions?.valuePrefix
    }

    /// Suffix for each selected value (multiselect)
    public var valueSuffix: String? {
        return parsedOptions?.valueSuffix
    }

    /// Delimiter between values (multiselect)
    public var delimiter: String? {
        return parsedOptions?.delimiter
    }

    /// Format a token value with prefix/suffix
    /// For multiselect (array of values), applies valuePrefix/valueSuffix/delimiter
    /// For single values, applies prefix/suffix
    public func formatTokenValue(_ rawValue: String, values: [String]? = nil) -> String {
        // Multiselect formatting (values is an array of selected values)
        if let values = values, !values.isEmpty {
            let formattedValues = values.map { value in
                let vPrefix = valuePrefix ?? ""
                let vSuffix = valueSuffix ?? ""
                return "\(vPrefix)\(value)\(vSuffix)"
            }

            let delim = delimiter ?? ","
            let joined = formattedValues.joined(separator: delim)

            // Apply outer prefix/suffix
            let outerPrefix = prefix ?? ""
            let outerSuffix = suffix ?? ""
            return "\(outerPrefix)\(joined)\(outerSuffix)"
        }

        // Single value formatting
        let p = prefix ?? ""
        let s = suffix ?? ""
        return "\(p)\(rawValue)\(s)"
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
