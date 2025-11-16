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

        // Convert inputs first
        if let fieldsets = simpleXML.fieldsets {
            for fieldset in fieldsets {
                for input in fieldset.inputs {
                    let inputId = "input_\(input.token)"

                    let studioInput = InputDefinition(
                        type: convertInputType(input.type),
                        title: input.label,
                        token: input.token,
                        defaultValue: input.defaultValue,
                        options: nil
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
                    let dsId = "ds_\(dsCounter)"
                    dsCounter += 1

                    let queryParams = QueryParameters(
                        earliest: search.earliest,
                        latest: search.latest
                    )

                    let options = DataSourceOptions(
                        query: search.query,
                        queryParameters: queryParams,
                        refresh: search.refresh,
                        refreshType: search.refreshType
                    )

                    let dataSource = DataSourceDefinition(
                        type: "ds.search",
                        options: options
                    )

                    dataSources[dsId] = dataSource
                    primaryDataSource = dsId
                }

                // Create visualization
                let vizType = convertVisualizationType(panel.visualization.type)
                let vizOptions = convertVisualizationOptions(panel.visualization.options)

                let visualization = VisualizationDefinition(
                    type: vizType,
                    title: panel.title,
                    dataSources: primaryDataSource != nil ? DataSourceReferences(primary: primaryDataSource) : nil,
                    options: vizOptions
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

        for layoutItem in studio.layout.structure {
            if layoutItem.type == .block {
                let y = layoutItem.position.y ?? 0
                let x = layoutItem.position.x ?? 0
                vizByY[y, default: []].append((item: layoutItem.item, x: x))
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

    private func convertVisualizationOptions(_ options: [String: String]) -> [String: AnyCodable]? {
        guard !options.isEmpty else { return nil }

        var converted: [String: AnyCodable] = [:]
        for (key, value) in options {
            // Try to parse as number or boolean
            if let intValue = Int(value) {
                converted[key] = AnyCodable(intValue)
            } else if let doubleValue = Double(value) {
                converted[key] = AnyCodable(doubleValue)
            } else if value.lowercased() == "true" {
                converted[key] = AnyCodable(true)
            } else if value.lowercased() == "false" {
                converted[key] = AnyCodable(false)
            } else {
                converted[key] = AnyCodable(value)
            }
        }

        return converted
    }
}
