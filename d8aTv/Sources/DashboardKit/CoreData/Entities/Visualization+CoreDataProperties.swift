import Foundation
import CoreData

extension Visualization {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Visualization> {
        return NSFetchRequest<Visualization>(entityName: "Visualization")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var vizId: String?
    @NSManaged public var type: String?
    @NSManaged public var title: String?
    @NSManaged public var optionsJSON: String?
    @NSManaged public var contextJSON: String?
    @NSManaged public var encoding: String?
    @NSManaged public var dashboard: Dashboard?
    @NSManaged public var dataSource: DataSource?
    @NSManaged public var layoutItem: LayoutItem?
}

extension Visualization: Identifiable {

}
