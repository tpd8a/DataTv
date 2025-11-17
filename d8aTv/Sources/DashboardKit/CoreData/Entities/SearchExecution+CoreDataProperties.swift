import Foundation
import CoreData

extension SearchExecution {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SearchExecution> {
        return NSFetchRequest<SearchExecution>(entityName: "SearchExecution")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var executionId: String?
    @NSManaged public var searchId: String?
    @NSManaged public var query: String?
    @NSManaged public var startTime: Date?
    @NSManaged public var endTime: Date?
    @NSManaged public var status: String?
    @NSManaged public var resultCount: Int64
    @NSManaged public var errorMessage: String?
    @NSManaged public var dataSource: DataSource?
    @NSManaged public var results: NSSet?
    @NSManaged public var dataSourceConfig: DataSourceConfig?
}

// MARK: Generated accessors for results
extension SearchExecution {

    @objc(addResultsObject:)
    @NSManaged public func addToResults(_ value: SearchResult)

    @objc(removeResultsObject:)
    @NSManaged public func removeFromResults(_ value: SearchResult)

    @objc(addResults:)
    @NSManaged public func addToResults(_ values: NSSet)

    @objc(removeResults:)
    @NSManaged public func removeFromResults(_ values: NSSet)
}

extension SearchExecution: Identifiable {

}
