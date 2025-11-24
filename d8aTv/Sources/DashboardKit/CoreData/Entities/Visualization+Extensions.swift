import Foundation
import CoreData

// MARK: - Visualization Options Extension

extension Visualization {

    /// Get all options as a dictionary parsed from optionsJSON
    /// Returns a structured dictionary with "options" and "formats" keys
    public var allOptions: [String: Any] {
        guard let jsonString = optionsJSON,
              let jsonData = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return [:]
        }
        return dict
    }

    /// Get all context options parsed from contextJSON
    public var contextOptions: [String: Any] {
        guard let jsonString = contextJSON,
              let jsonData = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return [:]
        }
        return dict
    }

    /// Get a specific option value from optionsJSON
    public func option(_ name: String) -> String? {
        return allOptions[name] as? String
    }

    /// Set options from a dictionary (stores as JSON in optionsJSON)
    public func setOptions(_ options: [String: Any]) throws {
        let jsonData = try JSONSerialization.data(withJSONObject: options)
        self.optionsJSON = String(data: jsonData, encoding: .utf8)
    }

    /// Set context from a dictionary (stores as JSON in contextJSON)
    public func setContext(_ context: [String: Any]) throws {
        let jsonData = try JSONSerialization.data(withJSONObject: context)
        self.contextJSON = String(data: jsonData, encoding: .utf8)
    }

    /// Get all visualizations for a specific data source
    public static func visualizations(
        forDataSource dataSource: DataSource,
        in context: NSManagedObjectContext
    ) -> [Visualization] {
        let request: NSFetchRequest<Visualization> = Visualization.fetchRequest()
        request.predicate = NSPredicate(format: "dataSource == %@", dataSource)
        request.sortDescriptors = [NSSortDescriptor(key: "vizId", ascending: true)]

        do {
            return try context.fetch(request)
        } catch {
            print("❌ Error fetching visualizations for dataSource: \(error)")
            return []
        }
    }

    /// Get table visualization for a specific data source
    public static func tableVisualization(
        forDataSource dataSource: DataSource,
        in context: NSManagedObjectContext
    ) -> Visualization? {
        let request: NSFetchRequest<Visualization> = Visualization.fetchRequest()
        request.predicate = NSPredicate(
            format: "dataSource == %@ AND (type == %@ OR type == %@)",
            dataSource,
            "table",
            "splunk.table"
        )
        request.fetchLimit = 1

        do {
            return try context.fetch(request).first
        } catch {
            print("❌ Error fetching table visualization: \(error)")
            return nil
        }
    }
}
