import Foundation
import CoreData

/// Core Data model configuration helper
public class CoreDataModelConfiguration {
    
    /// Create Core Data model programmatically if .xcdatamodeld file is not available
    public static func createModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        // Create entities
        let dashboardEntity = createDashboardEntity()
        let rowEntity = createRowEntity()
        let panelEntity = createPanelEntity()
        let fieldsetEntity = createFieldsetEntity()
        let tokenEntity = createTokenEntity()
        let tokenChoiceEntity = createTokenChoiceEntity()
        let tokenConditionEntity = createTokenConditionEntity()
        let tokenActionEntity = createTokenActionEntity()
        let searchEntity = createSearchEntity()
        let visualizationEntity = createVisualizationEntity()
        let globalTokenOpEntity = createGlobalTokenOpEntity()
        let customContentEntity = createCustomContentEntity()
        let namespaceEntity = createNamespaceEntity()
        let searchExecutionEntity = createSearchExecutionEntity()
        let searchResultEntity = createSearchResultEntity()
        
        // Configure relationships
        configureRelationships(
            dashboard: dashboardEntity,
            row: rowEntity,
            panel: panelEntity,
            fieldset: fieldsetEntity,
            token: tokenEntity,
            tokenChoice: tokenChoiceEntity,
            tokenCondition: tokenConditionEntity,
            tokenAction: tokenActionEntity,
            search: searchEntity,
            visualization: visualizationEntity,
            globalTokenOp: globalTokenOpEntity,
            customContent: customContentEntity,
            namespace: namespaceEntity,
            searchExecution: searchExecutionEntity,
            searchResult: searchResultEntity
        )
        
        model.entities = [
            dashboardEntity,
            rowEntity,
            panelEntity,
            fieldsetEntity,
            tokenEntity,
            tokenChoiceEntity,
            tokenConditionEntity,
            tokenActionEntity,
            searchEntity,
            visualizationEntity,
            globalTokenOpEntity,
            customContentEntity,
            namespaceEntity,
            searchExecutionEntity,
            searchResultEntity
        ]
        
        return model
    }
    
    // MARK: - Entity Creation
    
    private static func createDashboardEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "DashboardEntity"
        entity.managedObjectClassName = NSStringFromClass(DashboardEntity.self)
        
        entity.properties = [
            createAttribute(name: "id", type: .stringAttributeType, optional: false),
            createAttribute(name: "appName", type: .stringAttributeType),
            createAttribute(name: "dashboardName", type: .stringAttributeType),
            createAttribute(name: "title", type: .stringAttributeType),
            createAttribute(name: "dashboardDescription", type: .stringAttributeType),
            createAttribute(name: "version", type: .stringAttributeType),
            createAttribute(name: "theme", type: .stringAttributeType),
            createAttribute(name: "stylesheet", type: .stringAttributeType),
            createAttribute(name: "script", type: .stringAttributeType),
            createAttribute(name: "xmlContent", type: .stringAttributeType),
            createAttribute(name: "xmlHash", type: .stringAttributeType),
            createAttribute(name: "lastParsed", type: .dateAttributeType, optional: false),
            createAttribute(name: "createdAt", type: .dateAttributeType, optional: false),
            createAttribute(name: "hideEdit", type: .booleanAttributeType),
            createAttribute(name: "hideExport", type: .booleanAttributeType),
            createAttribute(name: "refreshInterval", type: .integer32AttributeType),
            createAttribute(name: "refreshType", type: .stringAttributeType),
            createAttribute(name: "globalEarliestTime", type: .stringAttributeType),
            createAttribute(name: "globalLatestTime", type: .stringAttributeType)
        ]
        
        return entity
    }
    
    private static func createRowEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "RowEntity"
        entity.managedObjectClassName = NSStringFromClass(RowEntity.self)
        
        entity.properties = [
            createAttribute(name: "id", type: .stringAttributeType, optional: false),
            createAttribute(name: "xmlId", type: .stringAttributeType),
            createAttribute(name: "orderIndex", type: .integer32AttributeType),
            createAttribute(name: "depends", type: .stringAttributeType),
            createAttribute(name: "rejects", type: .stringAttributeType),
            createAttribute(name: "grouping", type: .stringAttributeType),
            createAttribute(name: "rawAttributes", type: .binaryDataAttributeType)
        ]
        
        return entity
    }
    
    private static func createPanelEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "PanelEntity"
        entity.managedObjectClassName = NSStringFromClass(PanelEntity.self)
        
        entity.properties = [
            createAttribute(name: "id", type: .stringAttributeType, optional: false),
            createAttribute(name: "xmlId", type: .stringAttributeType),
            createAttribute(name: "title", type: .stringAttributeType),
            createAttribute(name: "orderIndex", type: .integer32AttributeType),
            createAttribute(name: "depends", type: .stringAttributeType),
            createAttribute(name: "rejects", type: .stringAttributeType),
            createAttribute(name: "ref", type: .stringAttributeType),
            createAttribute(name: "width", type: .stringAttributeType),
            createAttribute(name: "height", type: .stringAttributeType),
            createAttribute(name: "rawAttributes", type: .binaryDataAttributeType)
        ]
        
        return entity
    }
    
    private static func createFieldsetEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "FieldsetEntity"
        entity.managedObjectClassName = NSStringFromClass(FieldsetEntity.self)
        
        entity.properties = [
            createAttribute(name: "id", type: .stringAttributeType, optional: false),
            createAttribute(name: "submitButton", type: .booleanAttributeType),
            createAttribute(name: "autoRun", type: .booleanAttributeType),
            createAttribute(name: "depends", type: .stringAttributeType),
            createAttribute(name: "rejects", type: .stringAttributeType),
            createAttribute(name: "rawAttributes", type: .binaryDataAttributeType)
        ]
        
        return entity
    }
    
    private static func createTokenEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "TokenEntity"
        entity.managedObjectClassName = NSStringFromClass(TokenEntity.self)
        
        entity.properties = [
            createAttribute(name: "name", type: .stringAttributeType, optional: false),
            createAttribute(name: "type", type: .stringAttributeType, optional: false),
            createAttribute(name: "label", type: .stringAttributeType),
            createAttribute(name: "defaultValue", type: .stringAttributeType),
            createAttribute(name: "depends", type: .stringAttributeType),
            createAttribute(name: "rejects", type: .stringAttributeType),
            createAttribute(name: "prefix", type: .stringAttributeType),
            createAttribute(name: "suffix", type: .stringAttributeType),
            createAttribute(name: "delimiter", type: .stringAttributeType),
            createAttribute(name: "searchWhenChanged", type: .booleanAttributeType),
            createAttribute(name: "submitOnChange", type: .booleanAttributeType),
            createAttribute(name: "selectFirstChoice", type: .booleanAttributeType),
            createAttribute(name: "required", type: .booleanAttributeType),
            createAttribute(name: "validation", type: .stringAttributeType),
            createAttribute(name: "initialValue", type: .stringAttributeType),
            createAttribute(name: "populatingSearch", type: .stringAttributeType),
            createAttribute(name: "populatingFieldForValue", type: .stringAttributeType),
            createAttribute(name: "populatingFieldForLabel", type: .stringAttributeType),
            createAttribute(name: "earliestTime", type: .stringAttributeType),
            createAttribute(name: "latestTime", type: .stringAttributeType),
            createAttribute(name: "rawAttributes", type: .binaryDataAttributeType),
            createAttribute(name: "rawContent", type: .stringAttributeType)
        ]
        
        return entity
    }
    
    private static func createTokenChoiceEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "TokenChoiceEntity"
        entity.managedObjectClassName = NSStringFromClass(TokenChoiceEntity.self)
        
        entity.properties = [
            createAttribute(name: "value", type: .stringAttributeType, optional: false),
            createAttribute(name: "label", type: .stringAttributeType, optional: false),
            createAttribute(name: "isDefault", type: .booleanAttributeType),
            createAttribute(name: "disabled", type: .booleanAttributeType),
            createAttribute(name: "depends", type: .stringAttributeType),
            createAttribute(name: "rejects", type: .stringAttributeType),
            createAttribute(name: "rawAttributes", type: .binaryDataAttributeType)
        ]
        
        return entity
    }
    
    private static func createTokenConditionEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "TokenConditionEntity"
        entity.managedObjectClassName = NSStringFromClass(TokenConditionEntity.self)
        
        entity.properties = [
            createAttribute(name: "id", type: .stringAttributeType, optional: false),
            createAttribute(name: "match", type: .stringAttributeType),
            createAttribute(name: "label", type: .stringAttributeType),
            createAttribute(name: "value", type: .stringAttributeType),
            createAttribute(name: "rawAttributes", type: .binaryDataAttributeType)
        ]
        
        return entity
    }
    
    private static func createTokenActionEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "TokenActionEntity"
        entity.managedObjectClassName = NSStringFromClass(TokenActionEntity.self)
        
        entity.properties = [
            createAttribute(name: "id", type: .stringAttributeType, optional: false),
            createAttribute(name: "action", type: .stringAttributeType, optional: false),
            createAttribute(name: "targetToken", type: .stringAttributeType, optional: false),
            createAttribute(name: "value", type: .stringAttributeType),
            createAttribute(name: "expression", type: .stringAttributeType),
            createAttribute(name: "rawAttributes", type: .binaryDataAttributeType)
        ]
        
        return entity
    }
    
    private static func createSearchEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "SearchEntity"
        entity.managedObjectClassName = NSStringFromClass(SearchEntity.self)
        
        entity.properties = [
            createAttribute(name: "id", type: .stringAttributeType, optional: false),
            createAttribute(name: "xmlId", type: .stringAttributeType),
            createAttribute(name: "ref", type: .stringAttributeType),
            createAttribute(name: "base", type: .stringAttributeType),
            createAttribute(name: "query", type: .stringAttributeType),
            createAttribute(name: "earliestTime", type: .stringAttributeType),
            createAttribute(name: "latestTime", type: .stringAttributeType),
            createAttribute(name: "sampleRatio", type: .stringAttributeType),
            createAttribute(name: "refresh", type: .stringAttributeType),
            createAttribute(name: "refreshType", type: .stringAttributeType),
            createAttribute(name: "refreshDisplay", type: .stringAttributeType),
            createAttribute(name: "autostart", type: .booleanAttributeType),
            createAttribute(name: "depends", type: .stringAttributeType),
            createAttribute(name: "rejects", type: .stringAttributeType),
            createAttribute(name: "progress", type: .stringAttributeType),
            createAttribute(name: "done", type: .stringAttributeType),
            createAttribute(name: "cancelled", type: .stringAttributeType),
            createAttribute(name: "error", type: .stringAttributeType),
            createAttribute(name: "finalized", type: .stringAttributeType),
            createAttribute(name: "rawAttributes", type: .binaryDataAttributeType),
            createAttribute(name: "tokenReferences", type: .binaryDataAttributeType)
        ]
        
        return entity
    }
    
    private static func createVisualizationEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "VisualizationEntity"
        entity.managedObjectClassName = NSStringFromClass(VisualizationEntity.self)
        
        entity.properties = [
            createAttribute(name: "id", type: .stringAttributeType, optional: false),
            createAttribute(name: "type", type: .stringAttributeType, optional: false),
            createAttribute(name: "title", type: .stringAttributeType),
            createAttribute(name: "depends", type: .stringAttributeType),
            createAttribute(name: "rejects", type: .stringAttributeType),
            createAttribute(name: "chartType", type: .stringAttributeType),
            createAttribute(name: "stackMode", type: .stringAttributeType),
            createAttribute(name: "legend", type: .stringAttributeType),
            createAttribute(name: "drilldown", type: .stringAttributeType),
            createAttribute(name: "showDataLabels", type: .booleanAttributeType),
            createAttribute(name: "showLegend", type: .booleanAttributeType),
            createAttribute(name: "showTooltip", type: .booleanAttributeType),
            createAttribute(name: "formatOptions", type: .binaryDataAttributeType),
            createAttribute(name: "colorPalette", type: .binaryDataAttributeType),
            createAttribute(name: "chartOptions", type: .binaryDataAttributeType),
            createAttribute(name: "rawAttributes", type: .binaryDataAttributeType),
            createAttribute(name: "rawContent", type: .stringAttributeType)
        ]
        
        return entity
    }
    
    private static func createGlobalTokenOpEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "GlobalTokenOpEntity"
        entity.managedObjectClassName = NSStringFromClass(GlobalTokenOpEntity.self)
        
        entity.properties = [
            createAttribute(name: "id", type: .stringAttributeType, optional: false),
            createAttribute(name: "operation", type: .stringAttributeType, optional: false),
            createAttribute(name: "targetToken", type: .stringAttributeType, optional: false),
            createAttribute(name: "value", type: .stringAttributeType),
            createAttribute(name: "expression", type: .stringAttributeType),
            createAttribute(name: "depends", type: .stringAttributeType),
            createAttribute(name: "rawAttributes", type: .binaryDataAttributeType)
        ]
        
        return entity
    }
    
    private static func createCustomContentEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "CustomContentEntity"
        entity.managedObjectClassName = NSStringFromClass(CustomContentEntity.self)
        
        entity.properties = [
            createAttribute(name: "id", type: .stringAttributeType, optional: false),
            createAttribute(name: "contentType", type: .stringAttributeType, optional: false),
            createAttribute(name: "content", type: .stringAttributeType, optional: false),
            createAttribute(name: "depends", type: .stringAttributeType),
            createAttribute(name: "rejects", type: .stringAttributeType),
            createAttribute(name: "tokenReferences", type: .binaryDataAttributeType),
            createAttribute(name: "rawAttributes", type: .binaryDataAttributeType)
        ]
        
        return entity
    }
    
    private static func createNamespaceEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "NamespaceEntity"
        entity.managedObjectClassName = NSStringFromClass(NamespaceEntity.self)
        
        entity.properties = [
            createAttribute(name: "prefix", type: .stringAttributeType, optional: false),
            createAttribute(name: "uri", type: .stringAttributeType, optional: false)
        ]
        
        return entity
    }
    
    private static func createSearchExecutionEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "SearchExecutionEntity"
        entity.managedObjectClassName = "d8aTvCore.SearchExecutionEntity"
        
        entity.properties = [
            createAttribute(name: "id", type: .stringAttributeType, optional: false),
            createAttribute(name: "searchId", type: .stringAttributeType, optional: false),
            createAttribute(name: "dashboardId", type: .stringAttributeType, optional: false),
            createAttribute(name: "status", type: .stringAttributeType, optional: false),
            createAttribute(name: "progress", type: .doubleAttributeType, optional: false, defaultValue: 0.0),
            createAttribute(name: "statusMessage", type: .stringAttributeType),
            createAttribute(name: "startTime", type: .dateAttributeType, optional: false),
            createAttribute(name: "endTime", type: .dateAttributeType),
            createAttribute(name: "jobId", type: .stringAttributeType),
            createAttribute(name: "resolvedQuery", type: .stringAttributeType),
            createAttribute(name: "resultCount", type: .integer32AttributeType, optional: false, defaultValue: 0),
            createAttribute(name: "resultsJsonData", type: .binaryDataAttributeType),
            createAttribute(name: "errorMessage", type: .stringAttributeType)
        ]
        
        return entity
    }
    
    private static func createSearchResultEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "SearchResultEntity"
        entity.managedObjectClassName = "d8aTvCore.SearchResultEntity"
        
        entity.properties = [
            createAttribute(name: "executionId", type: .stringAttributeType, optional: false),
            createAttribute(name: "resultIndex", type: .integer32AttributeType, optional: false, defaultValue: 0),
            createAttribute(name: "jsonData", type: .binaryDataAttributeType)
        ]
        
        return entity
    }
    
    // MARK: - Relationship Configuration
    
    private static func configureRelationships(
        dashboard: NSEntityDescription,
        row: NSEntityDescription,
        panel: NSEntityDescription,
        fieldset: NSEntityDescription,
        token: NSEntityDescription,
        tokenChoice: NSEntityDescription,
        tokenCondition: NSEntityDescription,
        tokenAction: NSEntityDescription,
        search: NSEntityDescription,
        visualization: NSEntityDescription,
        globalTokenOp: NSEntityDescription,
        customContent: NSEntityDescription,
        namespace: NSEntityDescription,
        searchExecution: NSEntityDescription,
        searchResult: NSEntityDescription
    ) {
        
        // Dashboard -> Rows (one-to-many)
        let dashboardRows = NSRelationshipDescription()
        dashboardRows.name = "rows"
        dashboardRows.destinationEntity = row
        dashboardRows.maxCount = 0
        dashboardRows.deleteRule = .cascadeDeleteRule
        
        let rowDashboard = NSRelationshipDescription()
        rowDashboard.name = "dashboard"
        rowDashboard.destinationEntity = dashboard
        rowDashboard.maxCount = 1
        rowDashboard.deleteRule = .nullifyDeleteRule
        
        dashboardRows.inverseRelationship = rowDashboard
        rowDashboard.inverseRelationship = dashboardRows
        
        dashboard.properties.append(dashboardRows)
        row.properties.append(rowDashboard)
        
        // Row -> Panels (one-to-many)
        let rowPanels = NSRelationshipDescription()
        rowPanels.name = "panels"
        rowPanels.destinationEntity = panel
        rowPanels.maxCount = 0
        rowPanels.deleteRule = .cascadeDeleteRule
        
        let panelRow = NSRelationshipDescription()
        panelRow.name = "row"
        panelRow.destinationEntity = row
        panelRow.maxCount = 1
        panelRow.deleteRule = .nullifyDeleteRule
        
        rowPanels.inverseRelationship = panelRow
        panelRow.inverseRelationship = rowPanels
        
        row.properties.append(rowPanels)
        panel.properties.append(panelRow)
        
        // Dashboard -> Fieldsets (one-to-many)
        let dashboardFieldsets = NSRelationshipDescription()
        dashboardFieldsets.name = "fieldsets"
        dashboardFieldsets.destinationEntity = fieldset
        dashboardFieldsets.maxCount = 0
        dashboardFieldsets.deleteRule = .cascadeDeleteRule
        
        let fieldsetDashboard = NSRelationshipDescription()
        fieldsetDashboard.name = "dashboard"
        fieldsetDashboard.destinationEntity = dashboard
        fieldsetDashboard.maxCount = 1
        fieldsetDashboard.deleteRule = .nullifyDeleteRule
        
        dashboardFieldsets.inverseRelationship = fieldsetDashboard
        fieldsetDashboard.inverseRelationship = dashboardFieldsets
        
        dashboard.properties.append(dashboardFieldsets)
        fieldset.properties.append(fieldsetDashboard)
        
        // Fieldset -> Tokens (one-to-many)
        let fieldsetTokens = NSRelationshipDescription()
        fieldsetTokens.name = "tokens"
        fieldsetTokens.destinationEntity = token
        fieldsetTokens.maxCount = 0
        fieldsetTokens.deleteRule = .cascadeDeleteRule
        
        let tokenFieldset = NSRelationshipDescription()
        tokenFieldset.name = "fieldset"
        tokenFieldset.destinationEntity = fieldset
        tokenFieldset.maxCount = 1
        tokenFieldset.deleteRule = .nullifyDeleteRule
        
        fieldsetTokens.inverseRelationship = tokenFieldset
        tokenFieldset.inverseRelationship = fieldsetTokens
        
        fieldset.properties.append(fieldsetTokens)
        token.properties.append(tokenFieldset)
        
        // Panel -> Tokens (one-to-many)
        let panelInputs = NSRelationshipDescription()
        panelInputs.name = "inputs"
        panelInputs.destinationEntity = token
        panelInputs.maxCount = 0
        panelInputs.deleteRule = .cascadeDeleteRule
        
        let tokenPanel = NSRelationshipDescription()
        tokenPanel.name = "panel"
        tokenPanel.destinationEntity = panel
        tokenPanel.maxCount = 1
        tokenPanel.deleteRule = .nullifyDeleteRule
        
        panelInputs.inverseRelationship = tokenPanel
        tokenPanel.inverseRelationship = panelInputs
        
        panel.properties.append(panelInputs)
        token.properties.append(tokenPanel)
        
        // Token -> TokenChoices (one-to-many)
        let tokenChoices = NSRelationshipDescription()
        tokenChoices.name = "choices"
        tokenChoices.destinationEntity = tokenChoice
        tokenChoices.maxCount = 0
        tokenChoices.deleteRule = .cascadeDeleteRule
        
        let choiceToken = NSRelationshipDescription()
        choiceToken.name = "token"
        choiceToken.destinationEntity = token
        choiceToken.maxCount = 1
        choiceToken.deleteRule = .nullifyDeleteRule
        
        tokenChoices.inverseRelationship = choiceToken
        choiceToken.inverseRelationship = tokenChoices
        
        token.properties.append(tokenChoices)
        tokenChoice.properties.append(choiceToken)
        
        // Panel -> Visualizations (one-to-many)
        let panelVisualizations = NSRelationshipDescription()
        panelVisualizations.name = "visualizations"
        panelVisualizations.destinationEntity = visualization
        panelVisualizations.maxCount = 0
        panelVisualizations.deleteRule = .cascadeDeleteRule
        
        let visualizationPanel = NSRelationshipDescription()
        visualizationPanel.name = "panel"
        visualizationPanel.destinationEntity = panel
        visualizationPanel.maxCount = 1
        visualizationPanel.deleteRule = .nullifyDeleteRule
        
        panelVisualizations.inverseRelationship = visualizationPanel
        visualizationPanel.inverseRelationship = panelVisualizations
        
        panel.properties.append(panelVisualizations)
        visualization.properties.append(visualizationPanel)
        
        // Panel -> Searches (one-to-many)
        let panelSearches = NSRelationshipDescription()
        panelSearches.name = "searches"
        panelSearches.destinationEntity = search
        panelSearches.maxCount = 0
        panelSearches.deleteRule = .cascadeDeleteRule
        
        let searchPanel = NSRelationshipDescription()
        searchPanel.name = "panel"
        searchPanel.destinationEntity = panel
        searchPanel.maxCount = 1
        searchPanel.deleteRule = .nullifyDeleteRule
        
        panelSearches.inverseRelationship = searchPanel
        searchPanel.inverseRelationship = panelSearches
        
        panel.properties.append(panelSearches)
        search.properties.append(searchPanel)
        
        // Search -> Visualization (one-to-one)
        let searchVisualization = NSRelationshipDescription()
        searchVisualization.name = "visualization"
        searchVisualization.destinationEntity = visualization
        searchVisualization.maxCount = 1
        searchVisualization.deleteRule = .nullifyDeleteRule
        
        let visualizationSearch = NSRelationshipDescription()
        visualizationSearch.name = "search"
        visualizationSearch.destinationEntity = search
        visualizationSearch.maxCount = 1
        visualizationSearch.deleteRule = .nullifyDeleteRule
        
        searchVisualization.inverseRelationship = visualizationSearch
        visualizationSearch.inverseRelationship = searchVisualization
        
        search.properties.append(searchVisualization)
        visualization.properties.append(visualizationSearch)
        
        // Dashboard -> Global Searches (one-to-many)
        let dashboardGlobalSearches = NSRelationshipDescription()
        dashboardGlobalSearches.name = "globalSearches"
        dashboardGlobalSearches.destinationEntity = search
        dashboardGlobalSearches.maxCount = 0
        dashboardGlobalSearches.deleteRule = .cascadeDeleteRule
        
        let globalSearchDashboard = NSRelationshipDescription()
        globalSearchDashboard.name = "dashboard"
        globalSearchDashboard.destinationEntity = dashboard
        globalSearchDashboard.maxCount = 1
        globalSearchDashboard.deleteRule = .nullifyDeleteRule
        
        dashboardGlobalSearches.inverseRelationship = globalSearchDashboard
        globalSearchDashboard.inverseRelationship = dashboardGlobalSearches
        
        dashboard.properties.append(dashboardGlobalSearches)
        search.properties.append(globalSearchDashboard)
        
        // Dashboard -> Global Token Ops (one-to-many)
        let dashboardGlobalTokenOps = NSRelationshipDescription()
        dashboardGlobalTokenOps.name = "globalTokenOps"
        dashboardGlobalTokenOps.destinationEntity = globalTokenOp
        dashboardGlobalTokenOps.maxCount = 0
        dashboardGlobalTokenOps.deleteRule = .cascadeDeleteRule
        
        let globalTokenOpDashboard = NSRelationshipDescription()
        globalTokenOpDashboard.name = "dashboard"
        globalTokenOpDashboard.destinationEntity = dashboard
        globalTokenOpDashboard.maxCount = 1
        globalTokenOpDashboard.deleteRule = .nullifyDeleteRule
        
        dashboardGlobalTokenOps.inverseRelationship = globalTokenOpDashboard
        globalTokenOpDashboard.inverseRelationship = dashboardGlobalTokenOps
        
        dashboard.properties.append(dashboardGlobalTokenOps)
        globalTokenOp.properties.append(globalTokenOpDashboard)
        
        // Dashboard -> Custom Content (one-to-many)
        let dashboardCustomContent = NSRelationshipDescription()
        dashboardCustomContent.name = "customContent"
        dashboardCustomContent.destinationEntity = customContent
        dashboardCustomContent.maxCount = 0
        dashboardCustomContent.deleteRule = .cascadeDeleteRule
        
        let customContentDashboard = NSRelationshipDescription()
        customContentDashboard.name = "dashboard"
        customContentDashboard.destinationEntity = dashboard
        customContentDashboard.maxCount = 1
        customContentDashboard.deleteRule = .nullifyDeleteRule
        
        dashboardCustomContent.inverseRelationship = customContentDashboard
        customContentDashboard.inverseRelationship = dashboardCustomContent
        
        dashboard.properties.append(dashboardCustomContent)
        customContent.properties.append(customContentDashboard)
        
        // Panel -> Custom Content (one-to-many)
        let panelCustomContent = NSRelationshipDescription()
        panelCustomContent.name = "customContent"
        panelCustomContent.destinationEntity = customContent
        panelCustomContent.maxCount = 0
        panelCustomContent.deleteRule = .cascadeDeleteRule
        
        let customContentPanel = NSRelationshipDescription()
        customContentPanel.name = "panel"
        customContentPanel.destinationEntity = panel
        customContentPanel.maxCount = 1
        customContentPanel.deleteRule = .nullifyDeleteRule
        
        panelCustomContent.inverseRelationship = customContentPanel
        customContentPanel.inverseRelationship = panelCustomContent
        
        panel.properties.append(panelCustomContent)
        customContent.properties.append(customContentPanel)
        
        // Dashboard -> Namespace Declarations (one-to-many)
        let dashboardNamespaces = NSRelationshipDescription()
        dashboardNamespaces.name = "namespaceDeclarations"
        dashboardNamespaces.destinationEntity = namespace
        dashboardNamespaces.maxCount = 0
        dashboardNamespaces.deleteRule = .cascadeDeleteRule
        
        let namespaceDashboard = NSRelationshipDescription()
        namespaceDashboard.name = "dashboard"
        namespaceDashboard.destinationEntity = dashboard
        namespaceDashboard.maxCount = 1
        namespaceDashboard.deleteRule = .nullifyDeleteRule
        
        dashboardNamespaces.inverseRelationship = namespaceDashboard
        namespaceDashboard.inverseRelationship = dashboardNamespaces
        
        dashboard.properties.append(dashboardNamespaces)
        namespace.properties.append(namespaceDashboard)
        
        // Token -> Token Conditions (one-to-many)
        let tokenConditions = NSRelationshipDescription()
        tokenConditions.name = "changeConditions"
        tokenConditions.destinationEntity = tokenCondition
        tokenConditions.maxCount = 0
        tokenConditions.deleteRule = .cascadeDeleteRule
        
        let conditionToken = NSRelationshipDescription()
        conditionToken.name = "token"
        conditionToken.destinationEntity = token
        conditionToken.maxCount = 1
        conditionToken.deleteRule = .nullifyDeleteRule
        
        tokenConditions.inverseRelationship = conditionToken
        conditionToken.inverseRelationship = tokenConditions
        
        token.properties.append(tokenConditions)
        tokenCondition.properties.append(conditionToken)
        
        // Token Condition -> Token Actions (one-to-many)
        let conditionActions = NSRelationshipDescription()
        conditionActions.name = "tokenActions"
        conditionActions.destinationEntity = tokenAction
        conditionActions.maxCount = 0
        conditionActions.deleteRule = .cascadeDeleteRule
        
        let actionCondition = NSRelationshipDescription()
        actionCondition.name = "condition"
        actionCondition.destinationEntity = tokenCondition
        actionCondition.maxCount = 1
        actionCondition.deleteRule = .nullifyDeleteRule
        
        conditionActions.inverseRelationship = actionCondition
        actionCondition.inverseRelationship = conditionActions
        
        tokenCondition.properties.append(conditionActions)
        tokenAction.properties.append(actionCondition)
        
        // Add more relationships as needed...
        // (This is a simplified version - full implementation would include all relationships)
    }
    
    // MARK: - Helper Methods
    
    private static func createAttribute(name: String, type: NSAttributeType, optional: Bool = true, defaultValue: Any? = nil) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        if let defaultValue = defaultValue {
            attribute.defaultValue = defaultValue
        }
        return attribute
    }
}
