import Foundation

/// SimpleXML dashboard configuration (legacy format)
public struct SimpleXMLConfiguration: Sendable {
    public let label: String
    public let description: String?
    public let rows: [SimpleXMLRow]
    public let fieldsets: [SimpleXMLFieldset]?

    public init(
        label: String,
        description: String? = nil,
        rows: [SimpleXMLRow],
        fieldsets: [SimpleXMLFieldset]? = nil
    ) {
        self.label = label
        self.description = description
        self.rows = rows
        self.fieldsets = fieldsets
    }
}

/// SimpleXML row (bootstrap-style layout)
public struct SimpleXMLRow: Sendable {
    public let panels: [SimpleXMLPanel]

    public init(panels: [SimpleXMLPanel]) {
        self.panels = panels
    }
}

/// SimpleXML panel
public struct SimpleXMLPanel: Sendable {
    public let title: String?
    public let visualization: SimpleXMLVisualization
    public let search: SimpleXMLSearch?
    public let inputs: [SimpleXMLInput]

    public init(
        title: String? = nil,
        visualization: SimpleXMLVisualization,
        search: SimpleXMLSearch? = nil,
        inputs: [SimpleXMLInput] = []
    ) {
        self.title = title
        self.visualization = visualization
        self.search = search
        self.inputs = inputs
    }
}

/// SimpleXML visualization
public struct SimpleXMLVisualization: Sendable {
    public let type: SimpleXMLVisualizationType
    public let options: [String: String]           // Flattened options
    public let formats: [[String: AnyCodable]]     // Structured format elements array

    public init(
        type: SimpleXMLVisualizationType,
        options: [String: String] = [:],
        formats: [[String: AnyCodable]] = []
    ) {
        self.type = type
        self.options = options
        self.formats = formats
    }
}

/// SimpleXML visualization types
public enum SimpleXMLVisualizationType: String, Sendable {
    case chart
    case table
    case single
    case event
    case map
    case custom
}

/// SimpleXML search definition
public struct SimpleXMLSearch: Sendable {
    public let query: String
    public let earliest: String?
    public let latest: String?
    public let refresh: String?
    public let refreshType: String?
    public let id: String?          // Search ID for named searches
    public let base: String?        // Base search to chain from
    public let ref: String?         // Reference to existing search

    public init(
        query: String,
        earliest: String? = nil,
        latest: String? = nil,
        refresh: String? = nil,
        refreshType: String? = nil,
        id: String? = nil,
        base: String? = nil,
        ref: String? = nil
    ) {
        self.query = query
        self.earliest = earliest
        self.latest = latest
        self.refresh = refresh
        self.refreshType = refreshType
        self.id = id
        self.base = base
        self.ref = ref
    }
}

/// SimpleXML fieldset (inputs)
public struct SimpleXMLFieldset: Sendable {
    public let submitButton: Bool
    public let autoRun: Bool
    public let inputs: [SimpleXMLInput]

    public init(submitButton: Bool = false, autoRun: Bool = true, inputs: [SimpleXMLInput]) {
        self.submitButton = submitButton
        self.autoRun = autoRun
        self.inputs = inputs
    }
}

/// SimpleXML input
public struct SimpleXMLInput: Sendable {
    public let type: SimpleXMLInputType
    public let token: String
    public let label: String?
    public let defaultValue: String?
    public let initialValue: String?
    public let searchWhenChanged: Bool
    public let choices: [SimpleXMLInputChoice]  // Static dropdown/radio choices
    public let changeHandler: InputChangeHandler?  // Change event actions
    public let search: SimpleXMLSearch?  // Search to populate choices dynamically
    public let fieldForLabel: String?  // Field from search results to use as choice label
    public let fieldForValue: String?  // Field from search results to use as choice value

    // Formatting properties (for token value manipulation)
    public let prefix: String?          // Prefix for token value (all types)
    public let suffix: String?          // Suffix for token value (all types)
    public let valuePrefix: String?     // Prefix for each selected value (multiselect)
    public let valueSuffix: String?     // Suffix for each selected value (multiselect)
    public let delimiter: String?       // Delimiter between values (multiselect)

    public init(
        type: SimpleXMLInputType,
        token: String,
        label: String? = nil,
        defaultValue: String? = nil,
        initialValue: String? = nil,
        searchWhenChanged: Bool = true,
        choices: [SimpleXMLInputChoice] = [],
        changeHandler: InputChangeHandler? = nil,
        search: SimpleXMLSearch? = nil,
        fieldForLabel: String? = nil,
        fieldForValue: String? = nil,
        prefix: String? = nil,
        suffix: String? = nil,
        valuePrefix: String? = nil,
        valueSuffix: String? = nil,
        delimiter: String? = nil
    ) {
        self.type = type
        self.token = token
        self.label = label
        self.defaultValue = defaultValue
        self.initialValue = initialValue
        self.searchWhenChanged = searchWhenChanged
        self.choices = choices
        self.changeHandler = changeHandler
        self.search = search
        self.fieldForLabel = fieldForLabel
        self.fieldForValue = fieldForValue
        self.prefix = prefix
        self.suffix = suffix
        self.valuePrefix = valuePrefix
        self.valueSuffix = valueSuffix
        self.delimiter = delimiter
    }
}

/// SimpleXML input choice (for dropdown/radio/multiselect)
public struct SimpleXMLInputChoice: Sendable {
    public let value: String
    public let label: String

    public init(value: String, label: String? = nil) {
        self.value = value
        self.label = label ?? value
    }
}

/// SimpleXML input types
public enum SimpleXMLInputType: String, Sendable {
    case time
    case dropdown
    case radio
    case multiselect
    case text
    case checkbox
}

// MARK: - Input Change Handlers

/// Action type for input change handlers
public enum ChangeActionType: String, Sendable, Codable {
    case set
    case unset
    case eval
    case link
}

/// Single action within a change handler
public struct ChangeAction: Sendable, Codable, Equatable {
    public let type: ChangeActionType
    public let token: String
    public let value: String?  // For set/eval/link, can contain $label$, $value$, $form.xxx$

    public init(type: ChangeActionType, token: String, value: String? = nil) {
        self.type = type
        self.token = token
        self.value = value
    }
}

/// Condition match type
public enum ConditionMatchType: String, Sendable, Codable {
    case label      // Match on choice label
    case value      // Match on choice value
    case match      // Regex match on value
}

/// Conditional block with actions
public struct ChangeCondition: Sendable, Codable, Equatable {
    public let matchType: ConditionMatchType
    public let matchValue: String  // Label, value, or regex pattern
    public let actions: [ChangeAction]

    public init(matchType: ConditionMatchType, matchValue: String, actions: [ChangeAction]) {
        self.matchType = matchType
        self.matchValue = matchValue
        self.actions = actions
    }
}

/// Complete change handler for an input
public struct InputChangeHandler: Sendable, Codable, Equatable {
    public let unconditionalActions: [ChangeAction]  // Top-level actions, execute always
    public let conditions: [ChangeCondition]          // Conditional blocks

    public init(unconditionalActions: [ChangeAction] = [], conditions: [ChangeCondition] = []) {
        self.unconditionalActions = unconditionalActions
        self.conditions = conditions
    }
}
