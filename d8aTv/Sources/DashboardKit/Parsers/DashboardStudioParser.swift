import Foundation

/// Parser for Splunk Dashboard Studio JSON format
public actor DashboardStudioParser {

    public init() {}

    /// Parse Dashboard Studio JSON string
    public func parse(_ jsonString: String) throws -> DashboardStudioConfiguration {
        guard let data = jsonString.data(using: .utf8) else {
            throw ParserError.invalidEncoding
        }
        return try parse(data)
    }

    /// Parse Dashboard Studio JSON data
    public func parse(_ jsonData: Data) throws -> DashboardStudioConfiguration {
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(DashboardStudioConfiguration.self, from: jsonData)
        } catch {
            throw ParserError.invalidJSON(underlying: error)
        }
    }

    /// Parse Dashboard Studio from XML wrapper (CDATA format)
    public func parseFromXMLWrapper(_ xmlString: String) throws -> DashboardStudioConfiguration {
        // Extract JSON from CDATA section
        guard let cdataContent = extractCDATAContent(from: xmlString) else {
            throw ParserError.missingCDATA
        }
        return try parse(cdataContent)
    }

    /// Extract CDATA content from XML
    private func extractCDATAContent(from xml: String) -> String? {
        // Pattern: <![CDATA[ ... ]]>
        let pattern = #"<!\[CDATA\[(.*?)\]\]>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators) else {
            return nil
        }

        let nsString = xml as NSString
        let matches = regex.matches(in: xml, range: NSRange(location: 0, length: nsString.length))

        guard let match = matches.first,
              match.numberOfRanges > 1 else {
            return nil
        }

        let contentRange = match.range(at: 1)
        return nsString.substring(with: contentRange)
    }

    /// Validate dashboard configuration
    public func validate(_ configuration: DashboardStudioConfiguration) throws {
        // Validate visualizations reference existing data sources
        for (vizId, viz) in configuration.visualizations {
            if let primary = viz.dataSources?.primary {
                guard configuration.dataSources[primary] != nil else {
                    throw ParserError.invalidDataSourceReference(
                        visualization: vizId,
                        dataSource: primary
                    )
                }
            }

            if let secondary = viz.dataSources?.secondary {
                guard configuration.dataSources[secondary] != nil else {
                    throw ParserError.invalidDataSourceReference(
                        visualization: vizId,
                        dataSource: secondary
                    )
                }
            }
        }

        // Validate data source chaining
        for (dsId, ds) in configuration.dataSources {
            if let extends = ds.extends {
                guard configuration.dataSources[extends] != nil else {
                    throw ParserError.invalidDataSourceChain(
                        dataSource: dsId,
                        extends: extends
                    )
                }
            }
        }

        // Validate layout references
        for structureItem in configuration.layout.structure {
            switch structureItem.type {
            case .block:
                guard configuration.visualizations[structureItem.item] != nil else {
                    throw ParserError.invalidLayoutReference(
                        itemType: "visualization",
                        item: structureItem.item
                    )
                }
            case .input:
                guard configuration.inputs?[structureItem.item] != nil else {
                    throw ParserError.invalidLayoutReference(
                        itemType: "input",
                        item: structureItem.item
                    )
                }
            case .line:
                break // No validation needed for lines
            }
        }
    }

    /// Serialize dashboard configuration to JSON
    public func serialize(_ configuration: DashboardStudioConfiguration) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(configuration)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw ParserError.serializationFailed
        }
        return jsonString
    }

    /// Wrap JSON in XML CDATA for deployment
    public func wrapInXML(_ jsonString: String, dashboardId: String) -> String {
        return """
        <dashboard version="2" theme="dark">
            <label>\(dashboardId)</label>
            <definition><![CDATA[
        \(jsonString)
            ]]></definition>
        </dashboard>
        """
    }
}

/// Parser error types
public enum ParserError: Error, CustomStringConvertible {
    case invalidEncoding
    case invalidJSON(underlying: Error)
    case missingCDATA
    case invalidDataSourceReference(visualization: String, dataSource: String)
    case invalidDataSourceChain(dataSource: String, extends: String)
    case invalidLayoutReference(itemType: String, item: String)
    case serializationFailed
    case xmlParsingFailed(message: String)

    public var description: String {
        switch self {
        case .invalidEncoding:
            return "Invalid string encoding"
        case .invalidJSON(let error):
            return "Invalid JSON: \(error.localizedDescription)"
        case .missingCDATA:
            return "Missing CDATA section in XML"
        case .invalidDataSourceReference(let viz, let ds):
            return "Visualization '\(viz)' references non-existent data source '\(ds)'"
        case .invalidDataSourceChain(let ds, let ext):
            return "Data source '\(ds)' extends non-existent data source '\(ext)'"
        case .invalidLayoutReference(let type, let item):
            return "Layout references non-existent \(type) '\(item)'"
        case .serializationFailed:
            return "Failed to serialize configuration to JSON"
        case .xmlParsingFailed(let message):
            return "XML parsing failed: \(message)"
        }
    }
}
