import Foundation
import CoreData

// MARK: - Core Data Entity Extensions
// These correspond to the entities in tmpDashboardModel.xcdatamodeld

extension DashboardEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<DashboardEntity> {
        return NSFetchRequest<DashboardEntity>(entityName: "DashboardEntity")
    }
    
    public var rowsArray: [RowEntity] {
        let set = rows as? Set<RowEntity> ?? []
        return set.sorted { $0.orderIndex < $1.orderIndex }
    }
    
    public var fieldsetsArray: [FieldsetEntity] {
        let set = fieldsets as? Set<FieldsetEntity> ?? []
        return set.sorted { $0.id < $1.id }
    }
    
    public var globalSearchesArray: [SearchEntity] {
        let set = globalSearches as? Set<SearchEntity> ?? []
        return set.sorted { $0.id < $1.id }
    }
    
    public var customContentArray: [CustomContentEntity] {
        let set = customContent as? Set<CustomContentEntity> ?? []
        return set.sorted { $0.id < $1.id }
    }
    
    public var globalTokenOpsArray: [GlobalTokenOpEntity] {
        let set = globalTokenOps as? Set<GlobalTokenOpEntity> ?? []
        return set.sorted { $0.id < $1.id }
    }
    
    public var namespacesArray: [NamespaceEntity] {
        let set = namespaceDeclarations as? Set<NamespaceEntity> ?? []
        return set.sorted { $0.prefix < $1.prefix }
    }
    
    public var allTokens: [TokenEntity] {
        var tokens: [TokenEntity] = []
        
        // Get tokens from fieldsets
        for fieldset in fieldsetsArray {
            tokens.append(contentsOf: fieldset.tokensArray)
        }
        
        // Get tokens from panels
        for row in rowsArray {
            for panel in row.panelsArray {
                tokens.append(contentsOf: panel.inputsArray)
            }
        }
        
        return tokens.sorted { $0.name < $1.name }
    }
    
    public var allSearches: [SearchEntity] {
        var searches: [SearchEntity] = []
        
        // Global searches
        searches.append(contentsOf: globalSearchesArray)
        
        // Panel searches
        for row in rowsArray {
            for panel in row.panelsArray {
                searches.append(contentsOf: panel.searchesArray)
            }
        }
        
        return searches
    }
}

extension RowEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<RowEntity> {
        return NSFetchRequest<RowEntity>(entityName: "RowEntity")
    }
    
    public var panelsArray: [PanelEntity] {
        let set = panels as? Set<PanelEntity> ?? []
        return set.sorted { $0.orderIndex < $1.orderIndex }
    }
    
    /// Get raw attributes as dictionary
    public var attributesDictionary: [String: Any] {
        guard let data = rawAttributes else { return [:] }
        do {
            return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        } catch {
            return [:]
        }
    }
}

extension PanelEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PanelEntity> {
        return NSFetchRequest<PanelEntity>(entityName: "PanelEntity")
    }
    
    public var visualizationsArray: [VisualizationEntity] {
        let set = visualizations as? Set<VisualizationEntity> ?? []
        return set.sorted { $0.id < $1.id }
    }
    
    public var searchesArray: [SearchEntity] {
        let set = searches as? Set<SearchEntity> ?? []
        return set.sorted { $0.id < $1.id }
    }
    
    public var inputsArray: [TokenEntity] {
        let set = inputs as? Set<TokenEntity> ?? []
        return set.sorted { $0.name < $1.name }
    }
    
    /// Get raw attributes as dictionary
    public var attributesDictionary: [String: Any] {
        guard let data = rawAttributes else { return [:] }
        do {
            return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        } catch {
            return [:]
        }
    }
}

extension FieldsetEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<FieldsetEntity> {
        return NSFetchRequest<FieldsetEntity>(entityName: "FieldsetEntity")
    }
    
    public var tokensArray: [TokenEntity] {
        let set = tokens as? Set<TokenEntity> ?? []
        return set.sorted { $0.name < $1.name }
    }
    
    /// Get raw attributes as dictionary
    public var attributesDictionary: [String: Any] {
        guard let data = rawAttributes else { return [:] }
        do {
            return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        } catch {
            return [:]
        }
    }
}

extension TokenEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<TokenEntity> {
        return NSFetchRequest<TokenEntity>(entityName: "TokenEntity")
    }
    
    public var choicesArray: [TokenChoiceEntity] {
        let set = choices as? Set<TokenChoiceEntity> ?? []
        return set.sorted { 
            if $0.isDefault != $1.isDefault { return $0.isDefault }
            return $0.value < $1.value 
        }
    }
    
    public var conditionsArray: [TokenConditionEntity] {
        let set = changeConditions as? Set<TokenConditionEntity> ?? []
        return set.sorted { $0.id < $1.id }
    }
    
    public var evalExpressionsArray: [TokenActionEntity] {
        let set = evalExpressions as? Set<TokenActionEntity> ?? []
        return set.sorted { $0.id < $1.id }
    }
    
    /// Get raw attributes as dictionary
    public var attributesDictionary: [String: Any] {
        guard let data = rawAttributes else { return [:] }
        do {
            return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        } catch {
            return [:]
        }
    }
    
    // MARK: - Token Type Enum for compatibility
    public var tokenType: CoreDataTokenType {
        return CoreDataTokenType(rawValue: type) ?? .undefined
    }
    
    // MARK: - Convenience properties
    public var hasChoices: Bool {
        return !choicesArray.isEmpty
    }
    
    public var hasConditions: Bool {
        return !conditionsArray.isEmpty
    }
    
    public var hasDependencies: Bool {
        return depends != nil && !depends!.isEmpty
    }
    
    public var defaultChoice: TokenChoiceEntity? {
        return choicesArray.first(where: { $0.isDefault })
    }
}

extension TokenChoiceEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<TokenChoiceEntity> {
        return NSFetchRequest<TokenChoiceEntity>(entityName: "TokenChoiceEntity")
    }
    
    /// Get raw attributes as dictionary
    public var attributesDictionary: [String: Any] {
        guard let data = rawAttributes else { return [:] }
        do {
            return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        } catch {
            return [:]
        }
    }
}

extension TokenConditionEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<TokenConditionEntity> {
        return NSFetchRequest<TokenConditionEntity>(entityName: "TokenConditionEntity")
    }
    
    public var actionsArray: [TokenActionEntity] {
        let set = tokenActions as? Set<TokenActionEntity> ?? []
        return set.sorted { $0.id < $1.id }
    }
    
    /// Get raw attributes as dictionary
    public var attributesDictionary: [String: Any] {
        guard let data = rawAttributes else { return [:] }
        do {
            return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        } catch {
            return [:]
        }
    }
}

extension TokenActionEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<TokenActionEntity> {
        return NSFetchRequest<TokenActionEntity>(entityName: "TokenActionEntity")
    }
    
    /// Get raw attributes as dictionary
    public var attributesDictionary: [String: Any] {
        guard let data = rawAttributes else { return [:] }
        do {
            return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        } catch {
            return [:]
        }
    }
}

extension SearchEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<SearchEntity> {
        return NSFetchRequest<SearchEntity>(entityName: "SearchEntity")
    }
    
    /// Get raw attributes as dictionary
    public var attributesDictionary: [String: Any] {
        guard let data = rawAttributes else { return [:] }
        do {
            return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        } catch {
            return [:]
        }
    }
    
    // Helper to get token references from stored JSON
    public var tokenReferencesArray: [String] {
        guard let data = tokenReferences,
              let references = try? JSONSerialization.jsonObject(with: data) as? [String] else {
            return []
        }
        return references
    }
    
    /// Extract token references from query
    public var extractedTokenReferences: Set<String> {
        guard let query = query else { return Set() }
        return TokenValidator.extractTokenReferences(from: query)
    }
}

extension VisualizationEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<VisualizationEntity> {
        return NSFetchRequest<VisualizationEntity>(entityName: "VisualizationEntity")
    }
    
    /// Get raw attributes as dictionary
    public var attributesDictionary: [String: Any] {
        guard let data = rawAttributes else { return [:] }
        do {
            return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        } catch {
            return [:]
        }
    }
    
    /// Get format options as dictionary
    public var formatOptionsDict: [String: Any] {
        guard let data = formatOptions else { return [:] }
        do {
            return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        } catch {
            return [:]
        }
    }
    
    /// Get chart options as dictionary
    public var chartOptionsDict: [String: Any] {
        guard let data = chartOptions else { return [:] }
        do {
            return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        } catch {
            return [:]
        }
    }
    
    /// Get color palette as array
    public var colorPaletteArray: [String] {
        guard let data = colorPalette else { return [] }
        do {
            return try JSONSerialization.jsonObject(with: data) as? [String] ?? []
        } catch {
            return []
        }
    }

}

extension GlobalTokenOpEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<GlobalTokenOpEntity> {
        return NSFetchRequest<GlobalTokenOpEntity>(entityName: "GlobalTokenOpEntity")
    }
    
    /// Get raw attributes as dictionary
    public var attributesDictionary: [String: Any] {
        guard let data = rawAttributes else { return [:] }
        do {
            return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        } catch {
            return [:]
        }
    }
}

extension CustomContentEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CustomContentEntity> {
        return NSFetchRequest<CustomContentEntity>(entityName: "CustomContentEntity")
    }
    
    /// Get raw attributes as dictionary
    public var attributesDictionary: [String: Any] {
        guard let data = rawAttributes else { return [:] }
        do {
            return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        } catch {
            return [:]
        }
    }
    
    // Helper to get token references from stored JSON
    public var tokenReferencesArray: [String] {
        guard let data = tokenReferences,
              let references = try? JSONSerialization.jsonObject(with: data) as? [String] else {
            return []
        }
        return references
    }
}

extension NamespaceEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<NamespaceEntity> {
        return NSFetchRequest<NamespaceEntity>(entityName: "NamespaceEntity")
    }
}

// MARK: - Token Type Enum for Core Data (Enhanced)
public enum CoreDataTokenType: String, CaseIterable, Codable {
    case text = "text"
    case dropdown = "dropdown" 
    case time = "time"
    case radio = "radio"
    case checkbox = "checkbox"
    case multiselect = "multiselect"
    case link = "link"
    case calculated = "calculated"
    case timeComponent = "timeComponent"
    case undefined = "undefined"
    
    public var displayName: String {
        switch self {
        case .text: return "Text Input"
        case .dropdown: return "Dropdown"
        case .time: return "Time Range"
        case .radio: return "Radio Buttons"
        case .checkbox: return "Checkbox"
        case .multiselect: return "Multi-Select"
        case .link: return "Link List"
        case .calculated: return "Calculated"
        case .timeComponent: return "Time Component"
        case .undefined: return "Unknown Type"
        }
    }
    
    public var supportsChoices: Bool {
        switch self {
        case .dropdown, .radio, .checkbox, .multiselect, .link:
            return true
        case .text, .time, .calculated, .timeComponent, .undefined:
            return false
        }
    }
    
    public var supportsTimeRange: Bool {
        return self == .time
    }
    
    public var requiresPopulatingSearch: Bool {
        switch self {
        case .dropdown, .radio, .multiselect, .link:
            return true
        default:
            return false
        }
    }
}
