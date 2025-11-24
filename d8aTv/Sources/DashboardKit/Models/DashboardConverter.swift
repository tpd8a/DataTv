import Foundation

/// Utility to convert between SimpleXML and Dashboard Studio formats
public struct DashboardConverter {

    public init() {}

    /// Convert SimpleXML configuration to Dashboard Studio format
    public func convertToStudio(_ simpleXML: SimpleXMLConfiguration) -> DashboardStudioConfiguration {
        var visualizations: [String: VisualizationDefinition] = [:]
        var dataSources: [String: DataSourceDefinition] = [:]
        var layoutStructure: [LayoutStructureItem] = []
        var inputs: [String: InputDefinition] = [:]

        var vizCounter = 0
        var dsCounter = 0
        var yPosition = 0

        // Track named searches for referencing
        var namedSearches: [String: String] = [:]  // searchId -> dataSourceId

        // Convert inputs first
        if let fieldsets = simpleXML.fieldsets {
            for fieldset in fieldsets {
                for input in fieldset.inputs {
                    let inputId = "input_\(input.token)"

                    // Convert choices to Studio input options
                    var inputOptions: [String: AnyCodable]? = nil
                    if !input.choices.isEmpty {
                        var items: [[String: String]] = []
                        for choice in input.choices {
                            items.append([
                                "label": choice.label,
                                "value": choice.value
                            ])
                        }
                        inputOptions = [
                            "items": AnyCodable(items),
                            "token": AnyCodable(input.token)
                        ]
                        if let defaultValue = input.defaultValue {
                            inputOptions?["defaultValue"] = AnyCodable(defaultValue)
                        }
                    }

                    let studioInput = InputDefinition(
                        type: convertInputType(input.type),
                        title: input.label,
                        token: input.token,
                        defaultValue: input.defaultValue,
                        options: inputOptions
                    )

                    inputs[inputId] = studioInput

                    // Add to layout
                    let layoutItem = LayoutStructureItem(
                        item: inputId,
                        type: .input,
                        position: PositionDefinition(
                            x: 0,
                            y: yPosition,
                            w: 1200,
                            h: 50
                        )
                    )
                    layoutStructure.append(layoutItem)
                    yPosition += 60
                }
            }
        }

        // Convert rows and panels
        for row in simpleXML.rows {
            let panelWidth = 1200 / max(row.panels.count, 1)
            var xPosition = 0

            for panel in row.panels {
                let vizId = "viz_\(vizCounter)"
                vizCounter += 1

                // Create data source if search exists
                var primaryDataSource: String?
                if let search = panel.search {
                    // Determine data source ID
                    let dsId: String
                    if let searchId = search.id {
                        // Use search ID as data source ID (prefixed with ds_)
                        dsId = "ds_\(searchId)"
                    } else {
                        // Generate ID
                        dsId = "ds_\(dsCounter)"
                        dsCounter += 1
                    }

                    // Check search type: saved search (ref), chained (base), or regular search
                    let isSavedSearch = search.ref != nil
                    let isChained = search.base != nil

                    let queryParams = QueryParameters(
                        earliest: search.earliest,
                        latest: search.latest
                    )

                    let options: DataSourceOptions
                    let dsType: String
                    let name: String?

                    if isSavedSearch, let ref = search.ref {
                        // Create saved search reference
                        dsType = "ds.savedSearch"
                        name = search.id ?? ref // Use search ID or ref as name
                        options = DataSourceOptions(
                            query: nil,  // Saved searches don't have inline queries
                            queryParameters: queryParams.earliest != nil || queryParams.latest != nil ? queryParams : nil,
                            refresh: search.refresh,
                            refreshType: search.refreshType,
                            ref: ref  // Reference to saved search
                        )
                    } else if isChained, let base = search.base {
                        // Create chained data source (post-processing)
                        dsType = "ds.chain"
                        name = search.id // Use the search ID as the name
                        options = DataSourceOptions(
                            query: search.query,
                            queryParameters: queryParams.earliest != nil || queryParams.latest != nil ? queryParams : nil,
                            refresh: search.refresh,
                            refreshType: search.refreshType,
                            extend: "ds_\(base)"  // Reference the base search
                        )
                    } else {
                        // Create standalone search data source
                        dsType = "ds.search"
                        name = search.id // Use the search ID as the name
                        options = DataSourceOptions(
                            query: search.query,
                            queryParameters: queryParams,
                            refresh: search.refresh,
                            refreshType: search.refreshType
                        )
                    }

                    let dataSource = DataSourceDefinition(
                        type: dsType,
                        name: name,
                        options: options
                    )

                    dataSources[dsId] = dataSource
                    primaryDataSource = dsId

                    // Track named searches for later reference
                    if let searchId = search.id {
                        namedSearches[searchId] = dsId
                    }
                }

                // Create visualization
                let vizType = convertVisualizationType(panel.visualization.type)

                // Convert options and formats to Studio format with proper structure
                let (vizOptions, vizContext) = convertVisualizationOptionsAndFormats(
                    options: panel.visualization.options,
                    formats: panel.visualization.formats
                )

                let visualization = VisualizationDefinition(
                    type: vizType,
                    title: panel.title,
                    dataSources: primaryDataSource != nil ? DataSourceReferences(primary: primaryDataSource) : nil,
                    options: vizOptions,
                    context: vizContext
                )

                visualizations[vizId] = visualization

                // Add to layout
                let layoutItem = LayoutStructureItem(
                    item: vizId,
                    type: .block,
                    position: PositionDefinition(
                        x: xPosition,
                        y: yPosition,
                        w: panelWidth,
                        h: 300
                    )
                )
                layoutStructure.append(layoutItem)

                xPosition += panelWidth
            }

            yPosition += 310
        }

        // Create layout
        let layout = LayoutDefinition(
            type: .absolute,
            structure: layoutStructure
        )

        return DashboardStudioConfiguration(
            title: simpleXML.label,
            description: simpleXML.description,
            visualizations: visualizations,
            dataSources: dataSources,
            layout: layout,
            inputs: inputs.isEmpty ? nil : inputs
        )
    }

    /// Convert Dashboard Studio to SimpleXML (lossy conversion)
    public func convertToSimpleXML(_ studio: DashboardStudioConfiguration) -> SimpleXMLConfiguration {
        var rows: [SimpleXMLRow] = []
        var fieldsets: [SimpleXMLFieldset] = []

        // Group visualizations by Y position (approximate rows)
        var vizByY: [Int: [(item: String, x: Int)]] = [:]

        // Handle structure array (for converted SimpleXML)
        if let structure = studio.layout.structure {
            for layoutItem in structure {
                if layoutItem.type == .block {
                    let y = layoutItem.position.y ?? 0
                    let x = layoutItem.position.x ?? 0
                    vizByY[y, default: []].append((item: layoutItem.item, x: x))
                }
            }
        }

        // Convert visualizations to panels
        for (_, items) in vizByY.sorted(by: { $0.key < $1.key }) {
            var panels: [SimpleXMLPanel] = []

            for (itemId, _) in items.sorted(by: { $0.x < $1.x }) {
                guard let viz = studio.visualizations[itemId] else { continue }

                // Get primary data source
                var search: SimpleXMLSearch?
                if let primaryDS = viz.dataSources?.primary,
                   let ds = studio.dataSources[primaryDS],
                   let query = ds.options?.query {

                    search = SimpleXMLSearch(
                        query: query,
                        earliest: ds.options?.queryParameters?.earliest,
                        latest: ds.options?.queryParameters?.latest,
                        refresh: ds.options?.refresh,
                        refreshType: ds.options?.refreshType
                    )
                }

                let vizType = convertStudioVisualizationType(viz.type)
                let visualization = SimpleXMLVisualization(type: vizType)

                let panel = SimpleXMLPanel(
                    title: viz.title,
                    visualization: visualization,
                    search: search
                )

                panels.append(panel)
            }

            if !panels.isEmpty {
                rows.append(SimpleXMLRow(panels: panels))
            }
        }

        // Convert inputs
        if let studioInputs = studio.inputs {
            var simpleInputs: [SimpleXMLInput] = []

            for (_, input) in studioInputs {
                let inputType = convertStudioInputType(input.type)

                let simpleInput = SimpleXMLInput(
                    type: inputType,
                    token: input.token ?? "token",
                    label: input.title,
                    defaultValue: input.defaultValue
                )

                simpleInputs.append(simpleInput)
            }

            if !simpleInputs.isEmpty {
                let fieldset = SimpleXMLFieldset(inputs: simpleInputs)
                fieldsets.append(fieldset)
            }
        }

        return SimpleXMLConfiguration(
            label: studio.title,
            description: studio.description,
            rows: rows,
            fieldsets: fieldsets.isEmpty ? nil : fieldsets
        )
    }

    // MARK: - Type Conversion Helpers

    private func convertVisualizationType(_ type: SimpleXMLVisualizationType) -> String {
        switch type {
        case .chart:
            return "splunk.line"
        case .table:
            return "splunk.table"
        case .single:
            return "splunk.singlevalue"
        case .event:
            return "splunk.events"
        case .map:
            return "splunk.choropleth.svg"
        case .custom:
            return "viz.custom"
        }
    }

    private func convertStudioVisualizationType(_ type: String) -> SimpleXMLVisualizationType {
        if type.contains("table") {
            return .table
        } else if type.contains("single") {
            return .single
        } else if type.contains("event") {
            return .event
        } else if type.contains("map") || type.contains("choropleth") {
            return .map
        } else if type.hasPrefix("splunk.") {
            return .chart
        } else {
            return .custom
        }
    }

    private func convertInputType(_ type: SimpleXMLInputType) -> String {
        switch type {
        case .time:
            return "input.timerange"
        case .dropdown:
            return "input.dropdown"
        case .radio:
            return "input.radio"
        case .multiselect:
            return "input.multiselect"
        case .text:
            return "input.text"
        case .checkbox:
            return "input.checkbox"
        }
    }

    private func convertStudioInputType(_ type: String) -> SimpleXMLInputType {
        if type.contains("timerange") || type.contains("time") {
            return .time
        } else if type.contains("dropdown") {
            return .dropdown
        } else if type.contains("radio") {
            return .radio
        } else if type.contains("multiselect") {
            return .multiselect
        } else if type.contains("checkbox") {
            return .checkbox
        } else {
            return .text
        }
    }

    /// Convert visualization options and format elements to Studio format
    /// Returns (options, context) with proper nested structures
    private func convertVisualizationOptionsAndFormats(
        options: [String: String],
        formats: [[String: AnyCodable]]
    ) -> (options: [String: AnyCodable]?, context: [String: AnyCodable]?) {

        // Convert simple options - parse strings back to proper types
        var studioOptions: [String: AnyCodable] = [:]
        for (key, value) in options {
            // Parse value to correct type
            if let intValue = Int(value) {
                studioOptions[key] = AnyCodable(intValue)
            } else if let doubleValue = Double(value) {
                studioOptions[key] = AnyCodable(doubleValue)
            } else if value.lowercased() == "true" {
                studioOptions[key] = AnyCodable(true)
            } else if value.lowercased() == "false" {
                studioOptions[key] = AnyCodable(false)
            } else {
                studioOptions[key] = AnyCodable(value)
            }
        }

        // Store formats directly in options with proper structure
        // This preserves the format data for VisualizationFormatting to use
        if !formats.isEmpty {
            print("📊 Converting \(formats.count) format elements")
            studioOptions["formats"] = AnyCodable(formats)
        }

        // Also add to context for Studio compatibility
        var studioContext: [String: AnyCodable]? = nil
        if !formats.isEmpty {
            studioContext = [:]
            studioContext?["formats"] = AnyCodable(formats)
        }

        // Legacy: Also populate options dict at top level for backward compatibility
        if !options.isEmpty {
            let optionsDict = options.mapValues { AnyCodable($0) }
            studioOptions["options"] = AnyCodable(optionsDict)
        }

        print("📊 Studio options keys: \(studioOptions.keys.joined(separator: ", "))")

        return (
            studioOptions.isEmpty ? nil : studioOptions,
            studioContext
        )
    }

    /// Convert color format to Studio format
    private func convertColorFormat(field: String, formats: [String: String]) -> (context: Any?, format: String?) {
        guard let paletteType = formats["palette.type"] else {
            return (nil, nil)
        }

        switch paletteType {
        case "list":
            // Threshold-based color mapping
            if let colorsStr = formats["palette.colors"],
               let thresholdsStr = formats["scale.thresholds"] {
                let colors = parseColorList(colorsStr)
                let thresholds = parseThresholdList(thresholdsStr)
                let config = createThresholdColorConfig(colors: colors, thresholds: thresholds)
                let format = "> table | seriesByName(\"\(field)\") | rangeValue(\(field)ColumnColorConfig)"
                return (config, format)
            }

        case "minMidMax":
            // Gradient color mapping
            if let minColor = formats["palette.minColor"],
               let maxColor = formats["palette.maxColor"] {
                let config = ["colors": [minColor, maxColor]]
                let format = "> table | seriesByName(\"\(field)\") | gradient(\(field)ColumnColorConfig)"
                return (config, format)
            }

        case "sharedList":
            // Simple color list
            if let colorStr = formats["palette.colors"] {
                let colors = parseColorList(colorStr)
                let format = "> table | seriesByName(\"\(field)\") | pick(\(field)ColumnColorConfig)"
                return (colors, format)
            }

        case "map":
            // Value-based color mapping
            if let colorsStr = formats["palette.colors"] {
                let config = parseColorMap(colorsStr)
                let format = "> table | seriesByName(\"\(field)\") | matchValue(\(field)ColumnColorConfig)"
                return (config, format)
            }

        default:
            break
        }

        return (nil, nil)
    }

    /// Convert number format to Studio format
    private func convertNumberFormat(field: String, formats: [String: String]) -> (context: Any?, format: String?) {
        var numberConfig: [String: Any] = [
            "precision": 2,
            "thousandSeparated": true
        ]

        if let unit = formats["unit"] {
            numberConfig["unit"] = unit
        }
        if let unitPosition = formats["unitPosition"] {
            numberConfig["unitPosition"] = unitPosition
        }

        let config = ["number": numberConfig]
        let format = "> table | seriesByName(\"\(field)\") | formatByType(\(field)ColumnNumberConfig)"

        return (config, format)
    }

    /// Convert flattened format elements to Studio visualization context
    /// Converts format.field.property to nested context structure
    private func convertFormatElementsToContext(_ formatElements: [String: String]) -> [String: AnyCodable]? {
        guard !formatElements.isEmpty else { return nil }

        var context: [String: Any] = [:]

        // Group format elements by field
        var fieldFormats: [String: [String: String]] = [:]
        for (key, value) in formatElements {
            let parts = key.split(separator: ".").map(String.init)
            guard parts.count >= 3, parts[0] == "format" else { continue }

            let field = parts[1]
            let property = parts[2...].joined(separator: ".")

            if fieldFormats[field] == nil {
                fieldFormats[field] = [:]
            }
            fieldFormats[field]?[property] = value
        }

        // Convert each field's format to context structure
        for (field, formats) in fieldFormats {
            let contextKey = "\(field)ColumnColorConfig"

            if let paletteType = formats["palette.type"] {
                switch paletteType {
                case "list":
                    // Threshold-based color mapping
                    if let colorsStr = formats["palette.colors"],
                       let thresholdsStr = formats["scale.thresholds"] {
                        let colors = parseColorList(colorsStr)
                        let thresholds = parseThresholdList(thresholdsStr)
                        context[contextKey] = createThresholdColorConfig(colors: colors, thresholds: thresholds)
                    }
                case "minMidMax":
                    // Gradient color mapping
                    var gradientConfig: [String: Any] = [:]
                    if let minColor = formats["palette.minColor"] {
                        gradientConfig["minColor"] = minColor
                    }
                    if let maxColor = formats["palette.maxColor"] {
                        gradientConfig["maxColor"] = maxColor
                    }
                    if !gradientConfig.isEmpty {
                        context[contextKey] = ["colors": [gradientConfig["minColor"] ?? "#FFFFFF", gradientConfig["maxColor"] ?? "#000000"]]
                    }
                default:
                    break
                }
            }

            // Handle number formatting
            if let unit = formats["unit"] {
                let numberConfigKey = "\(field)ColumnNumberConfig"
                var numberConfig: [String: Any] = [
                    "number": [
                        "precision": 2,
                        "thousandSeparated": true,
                        "unit": unit,
                        "unitPosition": formats["unitPosition"] ?? "after"
                    ]
                ]
                context[numberConfigKey] = numberConfig
            }
        }

        guard !context.isEmpty else { return nil }

        // Convert to AnyCodable
        var result: [String: AnyCodable] = [:]
        for (key, value) in context {
            result[key] = AnyCodable(value)
        }
        return result
    }

    private func parseColorList(_ colorStr: String) -> [String] {
        // Parse "[#118832,#1182F3,#CBA700]" to array
        let trimmed = colorStr.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        return trimmed.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
    }

    private func parseThresholdList(_ thresholdStr: String) -> [Double] {
        return thresholdStr.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
    }

    private func parseColorMap(_ mapStr: String) -> [[String: String]] {
        // Parse color map - handles both JSON array format and simple map format
        // JSON format: ["{\"/path1\":#color1}","{\"/path2\":#color2}"]
        // Simple format: {"/path1":#color1,"/path2":#color2}
        var result: [[String: String]] = []

        // Check if input is JSON array (from serialized format)
        if mapStr.hasPrefix("[") {
            // Decode JSON array
            if let data = mapStr.data(using: .utf8),
               let entries = try? JSONDecoder().decode([String].self, from: data) {
                // Each entry is like {"/path":#color}
                for entry in entries {
                    let trimmed = entry.trimmingCharacters(in: CharacterSet(charactersIn: "{}"))
                    // Split on : to get path and color
                    if let colonIndex = trimmed.lastIndex(of: ":") {
                        let match = String(trimmed[..<colonIndex]).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                        let value = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                        result.append(["match": match, "value": value])
                    }
                }
            }
        } else {
            // Simple format parsing
            let trimmed = mapStr.trimmingCharacters(in: CharacterSet(charactersIn: "{}"))
            let pairs = trimmed.components(separatedBy: ",")

            for pair in pairs {
                if let colonIndex = pair.lastIndex(of: ":") {
                    let match = String(pair[..<colonIndex]).trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                    let value = String(pair[pair.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                    result.append(["match": match, "value": value])
                }
            }
        }

        return result
    }

    private func createThresholdColorConfig(colors: [String], thresholds: [Double]) -> [[String: Any]] {
        var config: [[String: Any]] = []

        for (index, threshold) in thresholds.enumerated() {
            var entry: [String: Any] = [:]
            if index == 0 {
                entry["to"] = threshold
            } else {
                entry["from"] = thresholds[index - 1]
                entry["to"] = threshold
            }
            if index < colors.count {
                entry["value"] = colors[index]
            }
            config.append(entry)
        }

        // Add final range
        if !thresholds.isEmpty && thresholds.count < colors.count {
            config.append([
                "from": thresholds.last!,
                "value": colors[thresholds.count]
            ])
        }

        return config
    }
}
