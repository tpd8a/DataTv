import Foundation
import CoreData

extension SearchResult {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SearchResult> {
        return NSFetchRequest<SearchResult>(entityName: "SearchResult")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var timestamp: Date?
    @NSManaged public var resultJSON: String?
    @NSManaged public var rowIndex: Int32
    @NSManaged public var execution: SearchExecution?
}

extension SearchResult: Identifiable {

}
