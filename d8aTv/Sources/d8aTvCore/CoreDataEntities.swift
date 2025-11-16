import Foundation
import CoreData

// MARK: - Core Data Entity Definitions
// These match the entities defined in tmpDashboardModel.xcdatamodeld

@objc(DashboardEntity)
public class DashboardEntity: NSManagedObject, @unchecked Sendable {
    @NSManaged public var id: String
    @NSManaged public var appName: String?
    @NSManaged public var dashboardName: String?
    @NSManaged public var title: String?
    @NSManaged public var dashboardDescription: String?
    @NSManaged public var version: String?
    @NSManaged public var theme: String?
    @NSManaged public var stylesheet: String?
    @NSManaged public var script: String?
    @NSManaged public var xmlContent: String?
    @NSManaged public var xmlHash: String?
    @NSManaged public var lastParsed: Date
    @NSManaged public var createdAt: Date
    @NSManaged public var hideEdit: Bool
    @NSManaged public var hideExport: Bool
    @NSManaged public var refreshInterval: Int32
    @NSManaged public var refreshType: String?
    @NSManaged public var globalEarliestTime: String?
    @NSManaged public var globalLatestTime: String?
    
    // Relationships
    @NSManaged public var rows: NSSet?
    @NSManaged public var fieldsets: NSSet?
    @NSManaged public var globalSearches: NSSet?
    @NSManaged public var customContent: NSSet?
    @NSManaged public var globalTokenOps: NSSet?
    @NSManaged public var namespaceDeclarations: NSSet?
}

@objc(RowEntity)
public class RowEntity: NSManagedObject, @unchecked Sendable {
    @NSManaged public var id: String
    @NSManaged public var xmlId: String?
    @NSManaged public var orderIndex: Int32
    @NSManaged public var depends: String?
    @NSManaged public var rejects: String?
    @NSManaged public var grouping: String?
    @NSManaged public var rawAttributes: Data?
    
    // Relationships
    @NSManaged public var dashboard: DashboardEntity?
    @NSManaged public var panels: NSSet?
}

@objc(PanelEntity)
public class PanelEntity: NSManagedObject, @unchecked Sendable {
    @NSManaged public var id: String
    @NSManaged public var xmlId: String?
    @NSManaged public var title: String?
    @NSManaged public var orderIndex: Int32
    @NSManaged public var depends: String?
    @NSManaged public var rejects: String?
    @NSManaged public var ref: String?
    @NSManaged public var width: String?
    @NSManaged public var height: String?
    @NSManaged public var rawAttributes: Data?
    
    // Relationships
    @NSManaged public var row: RowEntity?
    @NSManaged public var visualizations: NSSet?
    @NSManaged public var searches: NSSet?
    @NSManaged public var inputs: NSSet?
}

@objc(FieldsetEntity)
public class FieldsetEntity: NSManagedObject, @unchecked Sendable {
    @NSManaged public var id: String
    @NSManaged public var submitButton: Bool
    @NSManaged public var autoRun: Bool
    @NSManaged public var depends: String?
    @NSManaged public var rejects: String?
    @NSManaged public var rawAttributes: Data?
    
    // Relationships
    @NSManaged public var dashboard: DashboardEntity?
    @NSManaged public var tokens: NSSet?
}

@objc(TokenEntity)
public class TokenEntity: NSManagedObject, @unchecked Sendable {
    @NSManaged public var name: String
    @NSManaged public var type: String
    @NSManaged public var label: String?
    @NSManaged public var defaultValue: String?
    @NSManaged public var depends: String?
    @NSManaged public var rejects: String?
    @NSManaged public var prefix: String?
    @NSManaged public var suffix: String?
    @NSManaged public var delimiter: String?
    @NSManaged public var searchWhenChanged: Bool
    @NSManaged public var submitOnChange: Bool
    @NSManaged public var selectFirstChoice: Bool
    @NSManaged public var required: Bool
    @NSManaged public var validation: String?
    @NSManaged public var initialValue: String?
    @NSManaged public var populatingSearch: String?
    @NSManaged public var populatingFieldForValue: String?
    @NSManaged public var populatingFieldForLabel: String?
    @NSManaged public var earliestTime: String?
    @NSManaged public var latestTime: String?
    @NSManaged public var rawAttributes: Data?
    @NSManaged public var rawContent: String?
    
    // Relationships
    @NSManaged public var fieldset: FieldsetEntity?
    @NSManaged public var panel: PanelEntity?
    @NSManaged public var choices: NSSet?
    @NSManaged public var changeConditions: NSSet?
    @NSManaged public var evalExpressions: NSSet?
}

@objc(TokenChoiceEntity)
public class TokenChoiceEntity: NSManagedObject, @unchecked Sendable {
    @NSManaged public var value: String
    @NSManaged public var label: String
    @NSManaged public var isDefault: Bool
    @NSManaged public var disabled: Bool
    @NSManaged public var depends: String?
    @NSManaged public var rejects: String?
    @NSManaged public var rawAttributes: Data?
    
    // Relationships
    @NSManaged public var token: TokenEntity?
}

@objc(TokenConditionEntity)
public class TokenConditionEntity: NSManagedObject, @unchecked Sendable {
    @NSManaged public var id: String
    @NSManaged public var match: String?
    @NSManaged public var label: String?
    @NSManaged public var value: String?
    @NSManaged public var rawAttributes: Data?
    
    // Relationships
    @NSManaged public var token: TokenEntity?
    @NSManaged public var tokenActions: NSSet?
}

@objc(TokenActionEntity)
public class TokenActionEntity: NSManagedObject, @unchecked Sendable {
    @NSManaged public var id: String
    @NSManaged public var action: String
    @NSManaged public var targetToken: String
    @NSManaged public var value: String?
    @NSManaged public var expression: String?
    @NSManaged public var rawAttributes: Data?
    
    // Relationships
    @NSManaged public var condition: TokenConditionEntity?
}

@objc(SearchEntity)
public class SearchEntity: NSManagedObject, @unchecked Sendable {
    @NSManaged public var id: String
    @NSManaged public var xmlId: String?
    @NSManaged public var ref: String?
    @NSManaged public var base: String?
    @NSManaged public var query: String?
    @NSManaged public var earliestTime: String?
    @NSManaged public var latestTime: String?
    @NSManaged public var sampleRatio: String?
    @NSManaged public var refresh: String?
    @NSManaged public var refreshType: String?
    @NSManaged public var refreshDisplay: String?
    @NSManaged public var autostart: Bool
    @NSManaged public var depends: String?
    @NSManaged public var rejects: String?
    @NSManaged public var progress: String?
    @NSManaged public var done: String?
    @NSManaged public var cancelled: String?
    @NSManaged public var error: String?
    @NSManaged public var finalized: String?
    @NSManaged public var rawAttributes: Data?
    @NSManaged public var tokenReferences: Data?
    
    // Relationships
    @NSManaged public var panel: PanelEntity?
    @NSManaged public var dashboard: DashboardEntity?
    @NSManaged public var visualization: VisualizationEntity?
}

@objc(VisualizationEntity)
public class VisualizationEntity: NSManagedObject, @unchecked Sendable {
    @NSManaged public var id: String
    @NSManaged public var type: String
    @NSManaged public var title: String?
    @NSManaged public var depends: String?
    @NSManaged public var rejects: String?
    @NSManaged public var chartType: String?
    @NSManaged public var stackMode: String?
    @NSManaged public var legend: String?
    @NSManaged public var drilldown: String?
    @NSManaged public var showDataLabels: Bool
    @NSManaged public var showLegend: Bool
    @NSManaged public var showTooltip: Bool
    @NSManaged public var formatOptions: Data?
    @NSManaged public var colorPalette: Data?
    @NSManaged public var chartOptions: Data?  // Stores all options as JSON
    @NSManaged public var rawAttributes: Data?
    @NSManaged public var rawContent: String?
    
    // Relationships
    @NSManaged public var panel: PanelEntity?
    @NSManaged public var search: SearchEntity?
    
    // MARK: - Convenience Methods for Options
    
    /// Get all options as a dictionary
    public var allOptions: [String: Any] {
        guard let data = chartOptions,
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return dict
    }
    
    /// Get a specific option value
    public func option(_ name: String) -> String? {
        return allOptions[name] as? String
    }
    
    /// Set options from a dictionary (stores as JSON in chartOptions)
    public func setOptions(_ options: [String: Any]) throws {
        self.chartOptions = try JSONSerialization.data(withJSONObject: options)
    }
}

@objc(GlobalTokenOpEntity)
public class GlobalTokenOpEntity: NSManagedObject, @unchecked Sendable {
    @NSManaged public var id: String
    @NSManaged public var operation: String
    @NSManaged public var targetToken: String
    @NSManaged public var value: String?
    @NSManaged public var expression: String?
    @NSManaged public var depends: String?
    @NSManaged public var rawAttributes: Data?
    
    // Relationships
    @NSManaged public var dashboard: DashboardEntity?
}

@objc(CustomContentEntity)
public class CustomContentEntity: NSManagedObject, @unchecked Sendable {
    @NSManaged public var id: String
    @NSManaged public var contentType: String
    @NSManaged public var content: String
    @NSManaged public var depends: String?
    @NSManaged public var rejects: String?
    @NSManaged public var tokenReferences: Data?
    @NSManaged public var rawAttributes: Data?
    
    // Relationships
    @NSManaged public var dashboard: DashboardEntity?
    @NSManaged public var panel: PanelEntity?
}

@objc(NamespaceEntity)
public class NamespaceEntity: NSManagedObject, @unchecked Sendable {
    @NSManaged public var prefix: String
    @NSManaged public var uri: String
    
    // Relationships
    @NSManaged public var dashboard: DashboardEntity?
}
