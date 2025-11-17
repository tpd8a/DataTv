import Foundation
import CoreData

extension DashboardLayout {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DashboardLayout> {
        return NSFetchRequest<DashboardLayout>(entityName: "DashboardLayout")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var type: String?
    @NSManaged public var optionsJSON: String?
    @NSManaged public var globalInputs: String?
    @NSManaged public var dashboard: Dashboard?
    @NSManaged public var layoutItems: NSSet?
}

// MARK: Generated accessors for layoutItems
extension DashboardLayout {

    @objc(addLayoutItemsObject:)
    @NSManaged public func addToLayoutItems(_ value: LayoutItem)

    @objc(removeLayoutItemsObject:)
    @NSManaged public func removeFromLayoutItems(_ value: LayoutItem)

    @objc(addLayoutItems:)
    @NSManaged public func addToLayoutItems(_ values: NSSet)

    @objc(removeLayoutItems:)
    @NSManaged public func removeFromLayoutItems(_ values: NSSet)
}

extension DashboardLayout: Identifiable {

}
