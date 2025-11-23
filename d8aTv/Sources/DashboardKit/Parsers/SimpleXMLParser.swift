import Foundation

/// Parser for Splunk SimpleXML dashboard format (legacy)
@objc(SimpleXMLParser)
public class SimpleXMLParser: NSObject, XMLParserDelegate {
    private var currentElement = ""
    private var currentAttributes: [String: String] = [:]
    private var elementStack: [String] = []

    // Dashboard components being built
    private var label = ""
    private var dashboardDescription: String?
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

    // Temporary storage for search attributes
    private var currentQuery = ""
    private var currentEarliest: String?
    private var currentLatest: String?
    private var currentRefresh: String?
    private var currentRefreshType: String?
    private var searchAttributes: [String: String] = [:]  // Preserved search element attributes

    // Temporary storage for input attributes
    private var currentInputLabel: String?
    private var currentInputDefault: String?
    private var currentInputAttributes: [String: String] = [:]
    private var currentInputChoices: [SimpleXMLInputChoice] = []

    // Temporary storage for panel/viz title
    private var currentTitle: String?

    // Format extraction state
    private var currentFormats: [[String: AnyCodable]] = []
    private var currentFormatElement: [String: AnyCodable] = [:]
    private var currentPaletteElement: [String: AnyCodable] = [:]
    private var currentScaleElement: [String: AnyCodable] = [:]
    private var inFormatElement = false
    private var inPaletteElement = false
    private var inScaleElement = false

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
        NSLog("🔵 PARSE CALLED with \(xmlData.count) bytes")

        // Reset state
        label = ""
        dashboardDescription = nil
        rows = []
        fieldsets = []
        currentRow = []
        currentPanel = nil
        currentSearch = nil
        currentFieldset = nil
        currentInputs = []
        currentOptions = [:]
        elementStack = []
        currentQuery = ""
        currentEarliest = nil
        currentLatest = nil
        searchAttributes = [:]
        currentRefresh = nil
        currentRefreshType = nil
        currentInputLabel = nil
        currentInputDefault = nil
        currentInputAttributes = [:]
        currentInputChoices = []
        currentFormats = []
        currentFormatElement = [:]
        currentPaletteElement = [:]
        currentScaleElement = [:]
        inFormatElement = false
        inPaletteElement = false
        inScaleElement = false

        let parser = Foundation.XMLParser(data: xmlData)
        NSLog("🔵 Setting delegate to self: \(type(of: self))")
        parser.delegate = self
        NSLog("🔵 Delegate is set: \(parser.delegate != nil), delegate type: \(type(of: parser.delegate))")
        NSLog("🔵 First 100 chars of XML: \(String(data: xmlData.prefix(100), encoding: .utf8) ?? "invalid")")

        parser.shouldProcessNamespaces = false
        parser.shouldReportNamespacePrefixes = false

        NSLog("🔵 Starting XML parse...")
        let success = parser.parse()
        NSLog("🔵 Parse completed: success=\(success), error=\(String(describing: parser.parserError))")
        NSLog("🔵 After parse: label='\(label)', rows=\(rows.count), elementStack=\(elementStack)")

        guard success else {
            let error = parser.parserError
            throw ParserError.xmlParsingFailed(message: error?.localizedDescription ?? "Unknown error")
        }

        NSLog("🔵 Returning config: label='\(label)', rows=\(rows.count)")
        return SimpleXMLConfiguration(
            label: label,
            description: dashboardDescription,
            rows: rows,
            fieldsets: fieldsets.isEmpty ? nil : fieldsets
        )
    }

    // MARK: - Element Handlers

    private func handleStartElement(_ elementName: String, attributes: [String: String]) {
        let msg = "📍 START: \(elementName) (depth: \(elementStack.count + 1))\n"
        if let data = msg.data(using: .utf8),
           let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: "/tmp/parser_debug.log")) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else if let data = msg.data(using: .utf8) {
            try? data.write(to: URL(fileURLWithPath: "/tmp/parser_debug.log"))
        }
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
            currentFormats = []  // Reset formats for new panel
        case "search":
            currentSearch = nil
            currentQuery = ""
            currentEarliest = nil
            currentLatest = nil
            currentRefresh = nil
            currentRefreshType = nil
            // Save search element attributes before they get overwritten by child elements
            searchAttributes = attributes
        case "fieldset":
            currentInputs = []
            currentFieldset = nil
        case "input":
            currentOptions = [:]
            currentInputLabel = nil
            currentInputDefault = nil
            currentInputAttributes = attributes  // Save input's attributes before they get overwritten
            currentInputChoices = []
        case "format":
            // Start a new format element
            currentFormatElement = [:]
            if let type = attributes["type"] {
                currentFormatElement["type"] = AnyCodable(type)
            }
            if let field = attributes["field"] {
                currentFormatElement["field"] = AnyCodable(field)
            }
            inFormatElement = true
        case "colorPalette":
            currentPaletteElement = [:]
            if let paletteType = attributes["type"] {
                currentPaletteElement["type"] = AnyCodable(paletteType)
            }
            if let minColor = attributes["minColor"] {
                currentPaletteElement["minColor"] = AnyCodable(minColor)
            }
            if let midColor = attributes["midColor"] {
                currentPaletteElement["midColor"] = AnyCodable(midColor)
            }
            if let maxColor = attributes["maxColor"] {
                currentPaletteElement["maxColor"] = AnyCodable(maxColor)
            }
            inPaletteElement = true
        case "scale":
            currentScaleElement = [:]
            if let scaleType = attributes["type"] {
                currentScaleElement["type"] = AnyCodable(scaleType)
            }
            if let minValue = attributes["minValue"], let min = Double(minValue) {
                currentScaleElement["minValue"] = AnyCodable(min)
            }
            if let midValue = attributes["midValue"], let mid = Double(midValue) {
                currentScaleElement["midValue"] = AnyCodable(mid)
            }
            if let maxValue = attributes["maxValue"], let max = Double(maxValue) {
                currentScaleElement["maxValue"] = AnyCodable(max)
            }
            inScaleElement = true
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
            if elementStack.count == 2 { // Top-level label (form/dashboard label)
                label = currentCharacters
                print("✅ LABEL SET: '\(label)'")
            } else if elementStack.count > 2 && elementStack[elementStack.count - 2] == "input" {
                // Input label
                currentInputLabel = currentCharacters
            } else {
                print("⚠️  Label at depth \(elementStack.count), ignoring")
            }

        case "description":
            if elementStack.count == 2 { // Top-level description
                dashboardDescription = currentCharacters
            }

        case "query":
            currentQuery = currentCharacters

        case "earliest":
            currentEarliest = currentCharacters

        case "latest":
            currentLatest = currentCharacters

        case "refresh":
            currentRefresh = currentCharacters

        case "refreshType":
            currentRefreshType = currentCharacters

        case "title":
            // Could be panel title (inside table/chart/etc) - not input or dashboard label
            if elementStack.count > 2 {
                currentTitle = currentCharacters
            }

        case "choice":
            // Dropdown/radio/multiselect choice
            if let value = currentAttributes["value"] {
                let label = currentCharacters.isEmpty ? value : currentCharacters
                currentInputChoices.append(SimpleXMLInputChoice(value: value, label: label))
            }

        case "default", "initialValue":
            // Could be input default or search default - check parent
            if elementStack.count > 1 && elementStack[elementStack.count - 2] == "input" {
                currentInputDefault = currentCharacters
            }

        case "search":
            // Use accumulated values from child elements or saved search attributes
            print("🔍 Parser: Creating search with base=\(searchAttributes["base"] ?? "nil"), ref=\(searchAttributes["ref"] ?? "nil"), id=\(searchAttributes["id"] ?? "nil")")

            currentSearch = SimpleXMLSearch(
                query: currentQuery,
                earliest: currentEarliest ?? searchAttributes["earliest"],
                latest: currentLatest ?? searchAttributes["latest"],
                refresh: currentRefresh ?? searchAttributes["refresh"],
                refreshType: currentRefreshType ?? searchAttributes["refreshType"],
                id: searchAttributes["id"],
                base: searchAttributes["base"],
                ref: searchAttributes["ref"]
            )

            print("🔍 Parser: Created search: base=\(currentSearch?.base ?? "nil"), ref=\(currentSearch?.ref ?? "nil"), id=\(currentSearch?.id ?? "nil")")

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

            let visualization = SimpleXMLVisualization(
                type: vizType,
                options: currentOptions,
                formats: currentFormats
            )

            print("📊 Created visualization with \(currentFormats.count) format(s)")

            currentPanel = SimpleXMLPanel(
                title: currentTitle ?? currentAttributes["title"],
                visualization: visualization,
                search: currentSearch
            )
            currentOptions = [:]
            currentFormats = []
            currentSearch = nil
            currentTitle = nil

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
            let inputType = SimpleXMLInputType(rawValue: currentInputAttributes["type"] ?? "text") ?? .text
            let input = SimpleXMLInput(
                type: inputType,
                token: currentInputAttributes["token"] ?? "",
                label: currentInputLabel ?? currentInputAttributes["label"],
                defaultValue: currentInputDefault ?? currentInputAttributes["default"],
                searchWhenChanged: currentInputAttributes["searchWhenChanged"] != "false",
                choices: currentInputChoices
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
            // Handle options within format elements
            if inFormatElement, let name = currentAttributes["name"] {
                currentFormatElement[name] = AnyCodable(currentCharacters)
            } else if let name = currentAttributes["name"] {
                currentOptions[name] = currentCharacters
            }

        case "colorPalette":
            // Parse color array from element text
            if !currentCharacters.isEmpty {
                let cleanedColors = currentCharacters
                    .replacingOccurrences(of: "[", with: "")
                    .replacingOccurrences(of: "]", with: "")
                    .replacingOccurrences(of: "{", with: "")
                    .replacingOccurrences(of: "}", with: "")

                // Check if it's a map format (key:value pairs)
                if currentCharacters.contains(":") {
                    // Map format: {"/path/to/file":#COLOR,...}
                    var mapping: [String: String] = [:]
                    let pairs = cleanedColors.components(separatedBy: ",")
                    for pair in pairs {
                        let parts = pair.components(separatedBy: ":")
                        if parts.count == 2 {
                            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "")
                            let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                            mapping[key] = value
                        }
                    }
                    if !mapping.isEmpty {
                        currentPaletteElement["mapping"] = AnyCodable(mapping)
                    }
                } else {
                    // Array format: [#COLOR1,#COLOR2,...]
                    let colorArray = cleanedColors
                        .components(separatedBy: ",")
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }

                    if !colorArray.isEmpty {
                        currentPaletteElement["colors"] = AnyCodable(colorArray)
                    }
                }
            }
            if !currentPaletteElement.isEmpty {
                currentFormatElement["palette"] = AnyCodable(currentPaletteElement)
            }
            inPaletteElement = false

        case "scale":
            // Parse threshold values from element text
            if !currentCharacters.isEmpty {
                let thresholdArray = currentCharacters
                    .components(separatedBy: ",")
                    .compactMap { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }

                if !thresholdArray.isEmpty {
                    currentScaleElement["values"] = AnyCodable(thresholdArray)
                }
            }
            if !currentScaleElement.isEmpty {
                currentFormatElement["scale"] = AnyCodable(currentScaleElement)
            }
            inScaleElement = false

        case "format":
            // Complete the format element and add to formats array
            if !currentFormatElement.isEmpty {
                currentFormats.append(currentFormatElement)
                print("📊 Extracted format: \(currentFormatElement)")
            }
            currentFormatElement = [:]
            inFormatElement = false

        default:
            break
        }
    }

    // MARK: - XMLParserDelegate Methods

    @objc public func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String]
    ) {
        print("🟢🟢🟢 DELEGATE didStartElement CALLED: \(elementName) 🟢🟢🟢")
        NSLog("🟢🟢🟢 DELEGATE didStartElement CALLED: \(elementName) 🟢🟢🟢")
        handleStartElement(elementName, attributes: attributeDict)
    }

    @objc public func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            NSLog("🟢 DELEGATE foundCharacters: \(trimmed)")
        }
        handleFoundCharacters(string)
    }

    @objc public func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        NSLog("🟢 DELEGATE didEndElement: \(elementName)")
        handleEndElement(elementName)
    }
}
