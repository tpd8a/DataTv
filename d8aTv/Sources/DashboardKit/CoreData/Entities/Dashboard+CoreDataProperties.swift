import Foundation
import CoreData

extension Dashboard {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Dashboard> {
        return NSFetchRequest<Dashboard>(entityName: "Dashboard")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var dashboardId: String?
    @NSManaged public var title: String?
    @NSManaged public var dashboardDescription: String?
    @NSManaged public var formatType: String?
    @NSManaged public var rawJSON: String?
    @NSManaged public var rawXML: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var defaultsJSON: String?
    @NSManaged public var dataSources: NSSet?
    @NSManaged public var visualizations: NSSet?
    @NSManaged public var inputs: NSSet?
    @NSManaged public var layout: DashboardLayout?
    @NSManaged public var dataSourceConfig: DataSourceConfig?
}

// MARK: Generated accessors for dataSources
extension Dashboard {

    @objc(addDataSourcesObject:)
    @NSManaged public func addToDataSources(_ value: DataSource)

    @objc(removeDataSourcesObject:)
    @NSManaged public func removeFromDataSources(_ value: DataSource)

    @objc(addDataSources:)
    @NSManaged public func addToDataSources(_ values: NSSet)

    @objc(removeDataSources:)
    @NSManaged public func removeFromDataSources(_ values: NSSet)
}

// MARK: Generated accessors for visualizations
extension Dashboard {

    @objc(addVisualizationsObject:)
    @NSManaged public func addToVisualizations(_ value: Visualization)

    @objc(removeVisualizationsObject:)
    @NSManaged public func removeFromVisualizations(_ value: Visualization)

    @objc(addVisualizations:)
    @NSManaged public func addToVisualizations(_ values: NSSet)

    @objc(removeVisualizations:)
    @NSManaged public func removeFromVisualizations(_ values: NSSet)
}

// MARK: Generated accessors for inputs
extension Dashboard {

    @objc(addInputsObject:)
    @NSManaged public func addToInputs(_ value: DashboardInput)

    @objc(removeInputsObject:)
    @NSManaged public func removeFromInputs(_ value: DashboardInput)

    @objc(addInputs:)
    @NSManaged public func addToInputs(_ values: NSSet)

    @objc(removeInputs:)
    @NSManaged public func removeFromInputs(_ values: NSSet)
}

extension Dashboard: Identifiable {

}
