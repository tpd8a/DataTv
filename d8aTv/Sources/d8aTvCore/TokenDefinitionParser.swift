import Foundation

// MARK: - Token Definition Types

/// Scope of token visibility in dashboard
public enum TokenScope: String, Codable, CaseIterable {
    case global = "global"      // Available across all panels
    case form = "form"         // Only visible in form inputs
    case panel = "panel"       // Panel-specific token
    case search = "search"     // Search-specific token
}

/// Type of token based on XML structure
public enum TokenType: String, Codable, CaseIterable {
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
    
    /// Whether this token type supports predefined choices
    public var supportsChoices: Bool {
        switch self {
        case .dropdown, .radio, .checkbox, .multiselect:
            return true
        case .text, .time, .link, .calculated, .timeComponent, .undefined:
            return false
        }
    }
}

/// Token action for form inputs
public enum TokenActionEnum: String, Codable, CaseIterable {
    case set = "set"
    case unset = "unset"
    case initialize = "initialize"
}

/// Token choice for dropdown/radio inputs
public struct TokenChoice: Codable, Equatable, Hashable {
    public let value: String
    public let label: String
    public let isDefault: Bool
    
    public init(value: String, label: String? = nil, isDefault: Bool = false) {
        self.value = value
        self.label = label ?? value
        self.isDefault = isDefault
    }
}

/// Configuration data for specific token types
public struct TokenConfig: Codable {
    public let earliest: String?
    public let latest: String?
    public let searchWhenChanged: Bool
    public let allowCustomValue: Bool
    
    public init(earliest: String? = nil, latest: String? = nil, 
               searchWhenChanged: Bool = false, allowCustomValue: Bool = true) {
        self.earliest = earliest
        self.latest = latest
        self.searchWhenChanged = searchWhenChanged
        self.allowCustomValue = allowCustomValue
    }
}

// MARK: - Token Definition

/// Complete token definition extracted from Splunk SimpleXML dashboard
public struct TokenDefinition: Codable, Equatable, Hashable {
    public let name: String                    // Token name (without $)
    public let fullName: String                // Full token reference ($token$)
    public let scope: TokenScope               // Where token is visible
    public let type: TokenType                 // Input type
    public let defaultValue: String?           // Default value
    public let prefix: String?                 // Value prefix in SPL
    public let suffix: String?                 // Value suffix in SPL
    public let dependsOn: Set<String>          // Dependencies on other tokens
    public let definedInForm: Bool             // Defined in form section
    public let generatedBySearch: String?      // Search that populates choices
    public let configData: Data?               // Encoded TokenConfig
    public let action: TokenActionEnum         // Action type
    public let label: String?                  // Display label
    public let choices: [TokenChoice]          // Predefined choices
    public let searchWhenChanged: Bool         // Trigger search on change
    public let allowCustomValue: Bool          // Allow custom input
    public let changeConditions: [String]      // Conditions for change events
    
    public init(name: String, fullName: String? = nil, scope: TokenScope = .global, 
               type: TokenType = .text, defaultValue: String? = nil,
               prefix: String? = nil, suffix: String? = nil,
               dependsOn: Set<String> = Set(), definedInForm: Bool = false,
               generatedBySearch: String? = nil, configData: Data? = nil,
               action: TokenActionEnum = .set, label: String? = nil,
               choices: [TokenChoice] = [], searchWhenChanged: Bool = false,
               allowCustomValue: Bool = true, changeConditions: [String] = []) {
        self.name = name
        self.fullName = fullName ?? "$\(name)$"
        self.scope = scope
        self.type = type
        self.defaultValue = defaultValue
        self.prefix = prefix
        self.suffix = suffix
        self.dependsOn = dependsOn
        self.definedInForm = definedInForm
        self.generatedBySearch = generatedBySearch
        self.configData = configData
        self.action = action
        self.label = label
        self.choices = choices
        self.searchWhenChanged = searchWhenChanged
        self.allowCustomValue = allowCustomValue
        self.changeConditions = changeConditions
    }
    
    /// Computed config property
    public var config: TokenConfig? {
        guard let data = configData else { return nil }
        return try? JSONDecoder().decode(TokenConfig.self, from: data)
    }
    
    /// Default choice if available
    public var defaultChoice: TokenChoice? {
        return choices.first(where: { $0.isDefault }) ?? choices.first
    }
    
    /// Check if token has dependencies
    public var hasDependencies: Bool {
        return !dependsOn.isEmpty
    }
    
    /// Check if token has choices
    public var hasChoices: Bool {
        return !choices.isEmpty && type.supportsChoices
    }
}

// MARK: - Token Definition Parser

/// Parser for extracting token definitions from Splunk SimpleXML dashboards
public class TokenDefinitionParser {
    private let dashboardID: String
    
    public init(dashboardID: String) {
        self.dashboardID = dashboardID
    }
    
    /// Parse token definitions from XML root element
    public func parseTokenDefinitions(from root: SimpleXMLElement) throws -> [TokenDefinition] {
        var definitions: [TokenDefinition] = []
        
        // Parse form inputs
        if let form = root.element(named: "form") {
            let formInputs = try parseFormInputs(form: form)
            definitions.append(contentsOf: formInputs)
        }
        
        // Parse tokens used in searches (but not already defined in form)
        let searchTokens = parseSearchTokens(from: root)
        let existingNames = Set(definitions.map { $0.name })
        let uniqueSearchTokens = searchTokens.filter { !existingNames.contains($0.name) }
        definitions.append(contentsOf: uniqueSearchTokens)
        
        // Parse global tokens and eval tokens
        let globalTokens = parseGlobalTokens(from: root)
        let existingAllNames = Set(definitions.map { $0.name })
        let uniqueGlobalTokens = globalTokens.filter { !existingAllNames.contains($0.name) }
        definitions.append(contentsOf: uniqueGlobalTokens)
        
        return definitions
    }
    
    // MARK: - Private Parsing Methods
    
    private func parseFormInputs(form: SimpleXMLElement) throws -> [TokenDefinition] {
        var definitions: [TokenDefinition] = []
        
        // Parse form fieldsets
        for fieldset in form.elements(named: "fieldset") {
            for input in fieldset.children {
                if let definition = try parseFormInput(input: input) {
                    definitions.append(definition)
                }
            }
        }
        
        // Parse direct form inputs (not in fieldsets)
        for input in form.children where input.name != "fieldset" {
            if let definition = try parseFormInput(input: input) {
                definitions.append(definition)
            }
        }
        
        return definitions
    }
    
    private func parseFormInput(input: SimpleXMLElement) throws -> TokenDefinition? {
        let inputType = TokenType(rawValue: input.name) ?? .text
        
        guard let token = input.attribute("token") else {
            // Skip inputs without tokens
            return nil
        }
        
        let label = input.element(named: "label")?.value
        let defaultValue = input.element(named: "default")?.value
        let prefix = input.element(named: "prefix")?.value
        let suffix = input.element(named: "suffix")?.value
        let searchWhenChanged = input.attribute("searchWhenChanged") == "true"
        
        // Parse choices for dropdown/radio inputs
        var choices: [TokenChoice] = []
        if inputType.supportsChoices {
            if let choiceElement = input.element(named: "choice") {
                choices = parseChoices(from: [choiceElement])
            } else {
                choices = parseChoices(from: input.elements(named: "choice"))
            }
        }
        
        // Parse dependencies
        let dependsOn = parseDependencies(from: input)
        
        // Parse search for dynamic choices
        let generatedBySearch = input.element(named: "search")?.value ?? 
                               input.element(named: "populatingSearch")?.value
        
        // Create config
        var configData: Data?
        if inputType == .time {
            let earliest = input.element(named: "earliest")?.value
            let latest = input.element(named: "latest")?.value
            let config = TokenConfig(earliest: earliest, latest: latest, 
                                   searchWhenChanged: searchWhenChanged, 
                                   allowCustomValue: true)
            configData = try? JSONEncoder().encode(config)
        } else {
            let config = TokenConfig(searchWhenChanged: searchWhenChanged, 
                                   allowCustomValue: true)
            configData = try? JSONEncoder().encode(config)
        }
        
        return TokenDefinition(
            name: token,
            fullName: "$\(token)$",
            scope: .form,
            type: inputType,
            defaultValue: defaultValue,
            prefix: prefix,
            suffix: suffix,
            dependsOn: dependsOn,
            definedInForm: true,
            generatedBySearch: generatedBySearch,
            configData: configData,
            action: .set,
            label: label,
            choices: choices,
            searchWhenChanged: searchWhenChanged,
            allowCustomValue: true,
            changeConditions: []
        )
    }
    
    private func parseChoices(from elements: [SimpleXMLElement]) -> [TokenChoice] {
        return elements.compactMap { element in
            guard let value = element.attribute("value") else { return nil }
            let label = element.value ?? value
            let isDefault = element.attribute("default") == "true"
            return TokenChoice(value: value, label: label, isDefault: isDefault)
        }
    }
    
    private func parseDependencies(from element: SimpleXMLElement) -> Set<String> {
        // Look for depends attribute or change events
        var dependencies: Set<String> = []
        
        if let depends = element.attribute("depends") {
            // Parse comma-separated dependencies
            let tokens = depends.split(separator: ",")
                .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
                .map { $0.replacingOccurrences(of: "$", with: "") }
            dependencies.formUnion(tokens)
        }
        
        // Look for conditional attributes that might reference tokens
        for (key, value) in element.attributes {
            if key.hasPrefix("depends") || key.contains("token") {
                let extractedTokens = TokenValidator.extractTokenReferences(from: value)
                dependencies.formUnion(extractedTokens)
            }
        }
        
        return dependencies
    }
    
    private func parseSearchTokens(from root: SimpleXMLElement) -> [TokenDefinition] {
        var definitions: [TokenDefinition] = []
        let allElements = root.allDescendants()
        
        for element in allElements {
            if element.name == "query" || element.name == "search" {
                if let queryText = element.value {
                    let tokens = TokenValidator.extractTokenReferences(from: queryText)
                    for tokenName in tokens {
                        let definition = TokenDefinition(
                            name: tokenName,
                            fullName: "$\(tokenName)$",
                            scope: .search,
                            type: .text,
                            definedInForm: false,
                            action: .set
                        )
                        definitions.append(definition)
                    }
                }
            }
        }
        
        return definitions
    }
    
    private func parseGlobalTokens(from root: SimpleXMLElement) -> [TokenDefinition] {
        var definitions: [TokenDefinition] = []
        
        // Parse init blocks for global token settings
        for initElement in root.elements(named: "init") {
            for setElement in initElement.elements(named: "set") {
                if let token = setElement.attribute("token"),
                   let value = setElement.value {
                    let definition = TokenDefinition(
                        name: token,
                        fullName: "$\(token)$",
                        scope: .global,
                        type: .calculated,
                        defaultValue: value,
                        definedInForm: false,
                        action: .initialize
                    )
                    definitions.append(definition)
                }
            }
        }
        
        return definitions
    }
}

// MARK: - Token Parsing Errors

public enum TokenParsingError: Error, LocalizedError {
    case invalidTokenName(String)
    case invalidTokenType(String)
    case missingRequiredAttribute(String)
    case parsingFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidTokenName(let name):
            return "Invalid token name: \(name)"
        case .invalidTokenType(let type):
            return "Invalid token type: \(type)"
        case .missingRequiredAttribute(let attr):
            return "Missing required attribute: \(attr)"
        case .parsingFailed(let reason):
            return "Token parsing failed: \(reason)"
        }
    }
}

// MARK: - Token Resolution Errors

public enum TokenError: Error, LocalizedError {
    case invalidExpression(String)
    case undefinedToken(String)
    case circularDependency([String])
    case validationFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidExpression(let message):
            return "Invalid expression: \(message)"
        case .undefinedToken(let name):
            return "Undefined token: \(name)"
        case .circularDependency(let tokens):
            return "Circular dependency detected: \(tokens.joined(separator: " -> "))"
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        }
    }
}