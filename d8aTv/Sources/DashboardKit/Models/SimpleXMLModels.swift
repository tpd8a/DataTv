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

    public init(
        title: String? = nil,
        visualization: SimpleXMLVisualization,
        search: SimpleXMLSearch? = nil
    ) {
        self.title = title
        self.visualization = visualization
        self.search = search
    }
}

/// SimpleXML visualization
public struct SimpleXMLVisualization: Sendable {
    public let type: SimpleXMLVisualizationType
    public let options: [String: String]

    public init(type: SimpleXMLVisualizationType, options: [String: String] = [:]) {
        self.type = type
        self.options = options
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

    public init(
        query: String,
        earliest: String? = nil,
        latest: String? = nil,
        refresh: String? = nil,
        refreshType: String? = nil
    ) {
        self.query = query
        self.earliest = earliest
        self.latest = latest
        self.refresh = refresh
        self.refreshType = refreshType
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
    public let searchWhenChanged: Bool

    public init(
        type: SimpleXMLInputType,
        token: String,
        label: String? = nil,
        defaultValue: String? = nil,
        searchWhenChanged: Bool = true
    ) {
        self.type = type
        self.token = token
        self.label = label
        self.defaultValue = defaultValue
        self.searchWhenChanged = searchWhenChanged
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
