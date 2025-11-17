import Foundation
import CoreData

extension DataSource {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DataSource> {
        return NSFetchRequest<DataSource>(entityName: "DataSource")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var sourceId: String?
    @NSManaged public var name: String?
    @NSManaged public var type: String?
    @NSManaged public var query: String?
    @NSManaged public var refresh: String?
    @NSManaged public var refreshType: String?
    @NSManaged public var optionsJSON: String?
    @NSManaged public var extendsId: String?
    @NSManaged public var dashboard: Dashboard?
    @NSManaged public var executions: NSSet?
    @NSManaged public var visualizations: NSSet?
}

// MARK: Generated accessors for executions
extension DataSource {

    @objc(addExecutionsObject:)
    @NSManaged public func addToExecutions(_ value: SearchExecution)

    @objc(removeExecutionsObject:)
    @NSManaged public func removeFromExecutions(_ value: SearchExecution)

    @objc(addExecutions:)
    @NSManaged public func addToExecutions(_ values: NSSet)

    @objc(removeExecutions:)
    @NSManaged public func removeFromExecutions(_ values: NSSet)
}

// MARK: Generated accessors for visualizations
extension DataSource {

    @objc(addVisualizationsObject:)
    @NSManaged public func addToVisualizations(_ value: Visualization)

    @objc(removeVisualizationsObject:)
    @NSManaged public func removeFromVisualizations(_ value: Visualization)

    @objc(addVisualizations:)
    @NSManaged public func addToVisualizations(_ values: NSSet)

    @objc(removeVisualizations:)
    @NSManaged public func removeFromVisualizations(_ values: NSSet)
}

extension DataSource: Identifiable {

}
