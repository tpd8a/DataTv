import Foundation
import CoreData

extension LayoutItem {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<LayoutItem> {
        return NSFetchRequest<LayoutItem>(entityName: "LayoutItem")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var type: String?
    @NSManaged public var x: Int32
    @NSManaged public var y: Int32
    @NSManaged public var width: Int32
    @NSManaged public var height: Int32
    @NSManaged public var bootstrapWidth: String?
    @NSManaged public var position: Int32
    @NSManaged public var layout: DashboardLayout?
    @NSManaged public var visualization: Visualization?
    @NSManaged public var input: DashboardInput?
}

extension LayoutItem: Identifiable {

}
