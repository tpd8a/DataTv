import Foundation
import CoreData

extension DataSourceConfig {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DataSourceConfig> {
        return NSFetchRequest<DataSourceConfig>(entityName: "DataSourceConfig")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var type: String?
    @NSManaged public var host: String?
    @NSManaged public var port: Int32
    @NSManaged public var username: String?
    @NSManaged public var authToken: String?
    @NSManaged public var isDefault: Bool
    @NSManaged public var configJSON: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var dashboards: NSSet?
    @NSManaged public var executions: NSSet?
}

// MARK: Generated accessors for dashboards
extension DataSourceConfig {

    @objc(addDashboardsObject:)
    @NSManaged public func addToDashboards(_ value: Dashboard)

    @objc(removeDashboardsObject:)
    @NSManaged public func removeFromDashboards(_ value: Dashboard)

    @objc(addDashboards:)
    @NSManaged public func addToDashboards(_ values: NSSet)

    @objc(removeDashboards:)
    @NSManaged public func removeFromDashboards(_ values: NSSet)
}

// MARK: Generated accessors for executions
extension DataSourceConfig {

    @objc(addExecutionsObject:)
    @NSManaged public func addToExecutions(_ value: SearchExecution)

    @objc(removeExecutionsObject:)
    @NSManaged public func removeFromExecutions(_ value: SearchExecution)

    @objc(addExecutions:)
    @NSManaged public func addToExecutions(_ values: NSSet)

    @objc(removeExecutions:)
    @NSManaged public func removeFromExecutions(_ values: NSSet)
}

extension DataSourceConfig: Identifiable {

}
