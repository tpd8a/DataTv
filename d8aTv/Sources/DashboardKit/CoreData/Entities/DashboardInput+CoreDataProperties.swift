import Foundation
import CoreData

extension DashboardInput {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DashboardInput> {
        return NSFetchRequest<DashboardInput>(entityName: "DashboardInput")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var inputId: String?
    @NSManaged public var type: String?
    @NSManaged public var title: String?
    @NSManaged public var token: String?
    @NSManaged public var defaultValue: String?
    @NSManaged public var optionsJSON: String?
    @NSManaged public var dashboard: Dashboard?
    @NSManaged public var layoutItem: LayoutItem?
}

extension DashboardInput: Identifiable {

}
