import Foundation

/// Parser for Splunk SimpleXML dashboard format (legacy)
public actor SimpleXMLParser: NSObject, XMLParserDelegate {
    private var currentElement = ""
    private var currentAttributes: [String: String] = [:]
    private var elementStack: [String] = []

    // Dashboard components being built
    private var label = ""
    private var description: String?
    private var rows: [SimpleXMLRow] = []
    private var fieldsets: [SimpleXMLFieldset] = []

    // Current parsing context
    private var currentRow: [SimpleXMLPanel] = []
    private var currentPanel: SimpleXMLPanel?
    private var currentSearch: SimpleXMLSearch?
    private var currentFieldset: SimpleXMLFieldset?
    private var currentInputs: [SimpleXMLInput] = []
    private var currentOptions: [String: String] = [:]
    private var currentCharacters = ""

    public override init() {}

    /// Parse SimpleXML string
    public func parse(_ xmlString: String) throws -> SimpleXMLConfiguration {
        guard let data = xmlString.data(using: .utf8) else {
            throw ParserError.invalidEncoding
        }
        return try parse(data)
    }

    /// Parse SimpleXML data
    public func parse(_ xmlData: Data) throws -> SimpleXMLConfiguration {
        // Reset state
        label = ""
        description = nil
        rows = []
        fieldsets = []
        currentRow = []
        currentPanel = nil
        currentSearch = nil
        currentFieldset = nil
        currentInputs = []
        currentOptions = [:]
        elementStack = []

        let parser = XMLParser(data: xmlData)
        parser.delegate = self
        parser.shouldProcessNamespaces = false
        parser.shouldReportNamespacePrefixes = false

        guard parser.parse() else {
            let error = parser.parserError
            throw ParserError.xmlParsingFailed(message: error?.localizedDescription ?? "Unknown error")
        }

        return SimpleXMLConfiguration(
            label: label,
            description: description,
            rows: rows,
            fieldsets: fieldsets.isEmpty ? nil : fieldsets
        )
    }

    // MARK: - XMLParserDelegate

    nonisolated public func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        Task { @MainActor in
            await handleStartElement(elementName, attributes: attributeDict)
        }
    }

    nonisolated public func parser(_ parser: XMLParser, foundCharacters string: String) {
        Task { @MainActor in
            await handleFoundCharacters(string)
        }
    }

    nonisolated public func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        Task { @MainActor in
            await handleEndElement(elementName)
        }
    }

    // MARK: - Element Handlers

    private func handleStartElement(_ elementName: String, attributes: [String: String]) {
        currentElement = elementName
        currentAttributes = attributes
        elementStack.append(elementName)
        currentCharacters = ""

        switch elementName {
        case "row":
            currentRow = []
        case "panel":
            currentPanel = nil
            currentOptions = [:]
        case "search":
            currentSearch = nil
        case "fieldset":
            currentInputs = []
            currentFieldset = nil
        case "input":
            currentOptions = [:]
        default:
            break
        }
    }

    private func handleFoundCharacters(_ string: String) {
        currentCharacters += string.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func handleEndElement(_ elementName: String) {
        defer {
            elementStack.removeLast()
            currentCharacters = ""
        }

        switch elementName {
        case "label":
            if elementStack.count == 2 { // Top-level label
                label = currentCharacters
            }

        case "description":
            if elementStack.count == 2 { // Top-level description
                description = currentCharacters
            }

        case "query":
            // Will be handled in search end element
            break

        case "earliest", "latest", "refresh", "refreshType":
            // Will be handled in search end element
            break

        case "search":
            let query = currentCharacters.isEmpty ? "" : currentCharacters
            currentSearch = SimpleXMLSearch(
                query: query,
                earliest: currentAttributes["earliest"],
                latest: currentAttributes["latest"],
                refresh: currentAttributes["refresh"],
                refreshType: currentAttributes["refreshType"]
            )

        case "chart", "table", "single", "event", "map", "viz":
            let vizType: SimpleXMLVisualizationType
            switch elementName {
            case "chart": vizType = .chart
            case "table": vizType = .table
            case "single": vizType = .single
            case "event": vizType = .event
            case "map": vizType = .map
            default: vizType = .custom
            }

            let visualization = SimpleXMLVisualization(type: vizType, options: currentOptions)

            currentPanel = SimpleXMLPanel(
                title: currentAttributes["title"],
                visualization: visualization,
                search: currentSearch
            )
            currentOptions = [:]
            currentSearch = nil

        case "panel":
            if let panel = currentPanel {
                currentRow.append(panel)
            }
            currentPanel = nil

        case "row":
            if !currentRow.isEmpty {
                rows.append(SimpleXMLRow(panels: currentRow))
            }
            currentRow = []

        case "input":
            let inputType = SimpleXMLInputType(rawValue: currentAttributes["type"] ?? "text") ?? .text
            let input = SimpleXMLInput(
                type: inputType,
                token: currentAttributes["token"] ?? "",
                label: currentAttributes["label"],
                defaultValue: currentAttributes["default"],
                searchWhenChanged: currentAttributes["searchWhenChanged"] != "false"
            )
            currentInputs.append(input)

        case "fieldset":
            let submitButton = currentAttributes["submitButton"] == "true"
            let autoRun = currentAttributes["autoRun"] != "false"
            let fieldset = SimpleXMLFieldset(
                submitButton: submitButton,
                autoRun: autoRun,
                inputs: currentInputs
            )
            fieldsets.append(fieldset)
            currentInputs = []

        case "option":
            if let name = currentAttributes["name"] {
                currentOptions[name] = currentCharacters
            }

        default:
            break
        }
    }
}
