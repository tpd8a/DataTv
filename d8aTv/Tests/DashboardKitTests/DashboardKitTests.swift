import XCTest
@testable import DashboardKit

final class DashboardKitTests: XCTestCase {

    func testDashboardStudioParsing() async throws {
        let jsonString = """
        {
          "title": "Test Dashboard",
          "visualizations": {
            "viz_1": {
              "type": "splunk.singlevalue",
              "title": "Test Viz"
            }
          },
          "dataSources": {
            "ds_1": {
              "type": "ds.search",
              "options": {
                "query": "search index=main"
              }
            }
          },
          "layout": {
            "type": "absolute",
            "structure": [
              {
                "item": "viz_1",
                "type": "block",
                "position": {
                  "x": 0,
                  "y": 0,
                  "w": 300,
                  "h": 200
                }
              }
            ]
          }
        }
        """

        let parser = await DashboardStudioParser()
        let config = try await parser.parse(jsonString)

        XCTAssertEqual(config.title, "Test Dashboard")
        XCTAssertEqual(config.visualizations.count, 1)
        XCTAssertEqual(config.dataSources.count, 1)
        XCTAssertEqual(config.layout.type, .absolute)
        XCTAssertEqual(config.layout.structure.count, 1)
    }

    func testDashboardStudioValidation() async throws {
        let jsonString = """
        {
          "title": "Invalid Dashboard",
          "visualizations": {
            "viz_1": {
              "type": "splunk.singlevalue",
              "dataSources": {
                "primary": "ds_missing"
              }
            }
          },
          "dataSources": {},
          "layout": {
            "type": "absolute",
            "structure": []
          }
        }
        """

        let parser = await DashboardStudioParser()
        let config = try await parser.parse(jsonString)

        do {
            try await parser.validate(config)
            XCTFail("Validation should have failed")
        } catch let error as ParserError {
            if case .invalidDataSourceReference = error {
                // Expected error
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    func testSimpleXMLParsing() async throws {
        let xmlString = """
        <form>
          <label>Test Dashboard</label>
          <description>Test description</description>
          <row>
            <panel>
              <title>Test Panel</title>
              <single>
                <search>
                  <query>search index=main | stats count</query>
                  <earliest>-24h</earliest>
                  <latest>now</latest>
                </search>
              </single>
            </panel>
          </row>
        </form>
        """

        let parser = await SimpleXMLParser()
        let config = try await parser.parse(xmlString)

        XCTAssertEqual(config.label, "Test Dashboard")
        XCTAssertEqual(config.description, "Test description")
        XCTAssertEqual(config.rows.count, 1)
        XCTAssertEqual(config.rows[0].panels.count, 1)
        XCTAssertEqual(config.rows[0].panels[0].title, "Test Panel")
    }

    func testConversionSimpleXMLToStudio() throws {
        let simpleXML = SimpleXMLConfiguration(
            label: "Test Dashboard",
            description: "Test",
            rows: [
                SimpleXMLRow(panels: [
                    SimpleXMLPanel(
                        title: "Test Panel",
                        visualization: SimpleXMLVisualization(type: .single),
                        search: SimpleXMLSearch(
                            query: "search index=main | stats count",
                            earliest: "-24h",
                            latest: "now"
                        )
                    )
                ])
            ]
        )

        let converter = DashboardConverter()
        let studio = converter.convertToStudio(simpleXML)

        XCTAssertEqual(studio.title, "Test Dashboard")
        XCTAssertEqual(studio.description, "Test")
        XCTAssertFalse(studio.visualizations.isEmpty)
        XCTAssertFalse(studio.dataSources.isEmpty)
        XCTAssertEqual(studio.layout.type, .absolute)
    }

    func testConversionStudioToSimpleXML() throws {
        let studio = DashboardStudioConfiguration(
            title: "Test Dashboard",
            visualizations: [
                "viz_1": VisualizationDefinition(
                    type: "splunk.singlevalue",
                    dataSources: DataSourceReferences(primary: "ds_1")
                )
            ],
            dataSources: [
                "ds_1": DataSourceDefinition(
                    type: "ds.search",
                    options: DataSourceOptions(query: "search index=main | stats count")
                )
            ],
            layout: LayoutDefinition(
                type: .absolute,
                structure: [
                    LayoutStructureItem(
                        item: "viz_1",
                        type: .block,
                        position: PositionDefinition(x: 0, y: 0, w: 300, h: 200)
                    )
                ]
            )
        )

        let converter = DashboardConverter()
        let simpleXML = converter.convertToSimpleXML(studio)

        XCTAssertEqual(simpleXML.label, "Test Dashboard")
        XCTAssertEqual(simpleXML.rows.count, 1)
        XCTAssertEqual(simpleXML.rows[0].panels.count, 1)
    }

    func testDataSourceChaining() async throws {
        let jsonString = """
        {
          "title": "Chained Dashboard",
          "visualizations": {
            "viz_1": {
              "type": "splunk.table",
              "dataSources": {
                "primary": "ds_derived"
              }
            }
          },
          "dataSources": {
            "ds_base": {
              "type": "ds.search",
              "options": {
                "query": "search index=main"
              }
            },
            "ds_derived": {
              "type": "ds.chain",
              "extends": "ds_base",
              "options": {
                "query": "| stats count by host"
              }
            }
          },
          "layout": {
            "type": "absolute",
            "structure": [
              {
                "item": "viz_1",
                "type": "block",
                "position": {
                  "x": 0,
                  "y": 0,
                  "w": 600,
                  "h": 400
                }
              }
            ]
          }
        }
        """

        let parser = await DashboardStudioParser()
        let config = try await parser.parse(jsonString)

        try await parser.validate(config)

        // Verify chaining structure
        XCTAssertEqual(config.dataSources["ds_derived"]?.extends, "ds_base")
        XCTAssertEqual(config.dataSources["ds_base"]?.type, "ds.search")
        XCTAssertEqual(config.dataSources["ds_derived"]?.type, "ds.chain")
    }

    func testSerialization() async throws {
        let config = DashboardStudioConfiguration(
            title: "Test",
            visualizations: [:],
            dataSources: [:],
            layout: LayoutDefinition(type: .absolute, structure: [])
        )

        let parser = await DashboardStudioParser()
        let jsonString = try await parser.serialize(config)

        XCTAssertTrue(jsonString.contains("\"title\""))
        XCTAssertTrue(jsonString.contains("Test"))

        // Verify round-trip
        let parsed = try await parser.parse(jsonString)
        XCTAssertEqual(parsed.title, config.title)
    }

    func testXMLWrapping() async throws {
        let jsonString = """
        {"title": "Test", "visualizations": {}, "dataSources": {}, "layout": {"type": "absolute", "structure": []}}
        """

        let parser = await DashboardStudioParser()
        let wrapped = await parser.wrapInXML(jsonString, dashboardId: "test_dashboard")

        XCTAssertTrue(wrapped.contains("<dashboard"))
        XCTAssertTrue(wrapped.contains("<![CDATA["))
        XCTAssertTrue(wrapped.contains("]]>"))
        XCTAssertTrue(wrapped.contains(jsonString))
    }
}
