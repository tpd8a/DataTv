import Foundation

/// Dashboard Studio configuration model (matches JSON format)
public struct DashboardStudioConfiguration: Codable, Sendable {
    public let title: String
    public let description: String?
    public let visualizations: [String: VisualizationDefinition]
    public let dataSources: [String: DataSourceDefinition]
    public let layout: LayoutDefinition
    public let inputs: [String: InputDefinition]?
    public let defaults: DefaultsDefinition?

    public init(
        title: String,
        description: String? = nil,
        visualizations: [String: VisualizationDefinition],
        dataSources: [String: DataSourceDefinition],
        layout: LayoutDefinition,
        inputs: [String: InputDefinition]? = nil,
        defaults: DefaultsDefinition? = nil
    ) {
        self.title = title
        self.description = description
        self.visualizations = visualizations
        self.dataSources = dataSources
        self.layout = layout
        self.inputs = inputs
        self.defaults = defaults
    }
}

/// Visualization definition
public struct VisualizationDefinition: Codable, Sendable {
    public let type: String
    public let title: String?
    public let dataSources: DataSourceReferences?
    public let options: [String: AnyCodable]?
    public let context: [String: AnyCodable]?
    public let encoding: String?

    public init(
        type: String,
        title: String? = nil,
        dataSources: DataSourceReferences? = nil,
        options: [String: AnyCodable]? = nil,
        context: [String: AnyCodable]? = nil,
        encoding: String? = nil
    ) {
        self.type = type
        self.title = title
        self.dataSources = dataSources
        self.options = options
        self.context = context
        self.encoding = encoding
    }
}

/// Data source references within a visualization
public struct DataSourceReferences: Codable, Sendable {
    public let primary: String?
    public let secondary: String?
    public let annotation: [String]?

    public init(primary: String? = nil, secondary: String? = nil, annotation: [String]? = nil) {
        self.primary = primary
        self.secondary = secondary
        self.annotation = annotation
    }
}

/// Data source definition
public struct DataSourceDefinition: Codable, Sendable {
    public let type: String
    public let name: String?
    public let options: DataSourceOptions?
    public let extends: String?

    public init(
        type: String,
        name: String? = nil,
        options: DataSourceOptions? = nil,
        extends: String? = nil
    ) {
        self.type = type
        self.name = name
        self.options = options
        self.extends = extends
    }
}

/// Data source options
public struct DataSourceOptions: Codable, Sendable {
    public let query: String?
    public let queryParameters: QueryParameters?
    public let refresh: String?
    public let refreshType: String?
    public let enableSmartSources: Bool?

    public init(
        query: String? = nil,
        queryParameters: QueryParameters? = nil,
        refresh: String? = nil,
        refreshType: String? = nil,
        enableSmartSources: Bool? = nil
    ) {
        self.query = query
        self.queryParameters = queryParameters
        self.refresh = refresh
        self.refreshType = refreshType
        self.enableSmartSources = enableSmartSources
    }
}

/// Query parameters
public struct QueryParameters: Codable, Sendable {
    public let earliest: String?
    public let latest: String?

    public init(earliest: String? = nil, latest: String? = nil) {
        self.earliest = earliest
        self.latest = latest
    }
}

/// Layout definition
public struct LayoutDefinition: Codable, Sendable {
    public let type: LayoutType
    public let options: [String: AnyCodable]?
    public let structure: [LayoutStructureItem]
    public let globalInputs: [String]?

    public init(
        type: LayoutType,
        options: [String: AnyCodable]? = nil,
        structure: [LayoutStructureItem],
        globalInputs: [String]? = nil
    ) {
        self.type = type
        self.options = options
        self.structure = structure
        self.globalInputs = globalInputs
    }
}

/// Layout type enumeration
public enum LayoutType: String, Codable, Sendable {
    case absolute
    case grid
    case bootstrap // Legacy SimpleXML
}

/// Layout structure item
public struct LayoutStructureItem: Codable, Sendable {
    public let item: String
    public let type: LayoutItemType
    public let position: PositionDefinition

    public init(item: String, type: LayoutItemType, position: PositionDefinition) {
        self.item = item
        self.type = type
        self.position = position
    }
}

/// Layout item type
public enum LayoutItemType: String, Codable, Sendable {
    case block
    case input
    case line
}

/// Position definition (supports both absolute/grid and bootstrap)
public struct PositionDefinition: Codable, Sendable {
    // Absolute/Grid positioning
    public let x: Int?
    public let y: Int?
    public let w: Int?
    public let h: Int?

    // Bootstrap positioning
    public let width: BootstrapWidth?
    public let position: Int?

    public init(
        x: Int? = nil,
        y: Int? = nil,
        w: Int? = nil,
        h: Int? = nil,
        width: BootstrapWidth? = nil,
        position: Int? = nil
    ) {
        self.x = x
        self.y = y
        self.w = w
        self.h = h
        self.width = width
        self.position = position
    }
}

/// Bootstrap width values
public enum BootstrapWidth: String, Codable, Sendable {
    case col12 = "12"
    case col11 = "11"
    case col10 = "10"
    case col9 = "9"
    case col8 = "8"
    case col7 = "7"
    case col6 = "6"
    case col5 = "5"
    case col4 = "4"
    case col3 = "3"
    case col2 = "2"
    case col1 = "1"
}

/// Input definition
public struct InputDefinition: Codable, Sendable {
    public let type: String
    public let title: String?
    public let token: String?
    public let defaultValue: String?
    public let options: [String: AnyCodable]?

    public init(
        type: String,
        title: String? = nil,
        token: String? = nil,
        defaultValue: String? = nil,
        options: [String: AnyCodable]? = nil
    ) {
        self.type = type
        self.title = title
        self.token = token
        self.defaultValue = defaultValue
        self.options = options
    }
}

/// Defaults definition
public struct DefaultsDefinition: Codable, Sendable {
    public let dataSources: [String: AnyCodable]?

    public init(dataSources: [String: AnyCodable]? = nil) {
        self.dataSources = dataSources
    }
}

/// Type-erased codable wrapper for any value
public struct AnyCodable: Codable, Sendable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported type"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Unsupported type"
                )
            )
        }
    }
}
