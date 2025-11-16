import Foundation

// MARK: - Token Definition Types

/// Scope of token visibility in dashboard
public enum TokenScope: String, Codable, Sendable, CaseIterable {
    case global = "global"      // Available across all panels
    case form = "form"         // Only visible in form inputs
    case panel = "panel"       // Panel-specific token
    case search = "search"     // Search-specific token
}

/// Type of token based on input structure
public enum TokenType: String, Codable, Sendable, CaseIterable {
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
public enum TokenActionEnum: String, Codable, Sendable, CaseIterable {
    case set = "set"
    case unset = "unset"
    case initialize = "initialize"
}

/// Token choice for dropdown/radio inputs
public struct TokenChoice: Codable, Sendable, Equatable, Hashable {
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
public struct TokenConfig: Codable, Sendable {
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

/// Complete token definition extracted from dashboard
public struct TokenDefinition: Codable, Sendable, Equatable, Hashable {
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
    public let configJSON: String?             // Encoded TokenConfig
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
               generatedBySearch: String? = nil, configJSON: String? = nil,
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
        self.configJSON = configJSON
        self.action = action
        self.label = label
        self.choices = choices
        self.searchWhenChanged = searchWhenChanged
        self.allowCustomValue = allowCustomValue
        self.changeConditions = changeConditions
    }

    /// Computed config property
    public var config: TokenConfig? {
        guard let jsonString = configJSON,
              let data = jsonString.data(using: .utf8) else { return nil }
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

// MARK: - Token Resolution

/// Token resolver for substituting token values in queries
public actor TokenResolver {
    private var tokenValues: [String: String] = [:]

    public init(tokenValues: [String: String] = [:]) {
        self.tokenValues = tokenValues
    }

    /// Update token value
    public func setToken(name: String, value: String) {
        tokenValues[name] = value
    }

    /// Get token value
    public func getToken(name: String) -> String? {
        return tokenValues[name]
    }

    /// Resolve all tokens in a query string
    public func resolveTokens(in query: String, definitions: [TokenDefinition] = []) -> String {
        var resolved = query

        // First resolve from explicit values
        for (name, value) in tokenValues {
            let fullToken = "$\(name)$"

            // Find definition for prefix/suffix
            if let definition = definitions.first(where: { $0.name == name }) {
                var finalValue = value
                if let prefix = definition.prefix {
                    finalValue = prefix + finalValue
                }
                if let suffix = definition.suffix {
                    finalValue = finalValue + suffix
                }
                resolved = resolved.replacingOccurrences(of: fullToken, with: finalValue)
            } else {
                resolved = resolved.replacingOccurrences(of: fullToken, with: value)
            }
        }

        // Then apply defaults from definitions
        for definition in definitions {
            let fullToken = definition.fullName
            if resolved.contains(fullToken), let defaultValue = definition.defaultValue {
                var finalValue = defaultValue
                if let prefix = definition.prefix {
                    finalValue = prefix + finalValue
                }
                if let suffix = definition.suffix {
                    finalValue = finalValue + suffix
                }
                resolved = resolved.replacingOccurrences(of: fullToken, with: finalValue)
            }
        }

        return resolved
    }

    /// Extract token references from a query string
    public func extractTokenReferences(from query: String) -> Set<String> {
        var tokens = Set<String>()
        let pattern = "\\$([a-zA-Z0-9_\\.]+)\\$"

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return tokens
        }

        let nsString = query as NSString
        let matches = regex.matches(in: query, range: NSRange(location: 0, length: nsString.length))

        for match in matches {
            if match.numberOfRanges > 1 {
                let tokenRange = match.range(at: 1)
                let tokenName = nsString.substring(with: tokenRange)
                tokens.insert(tokenName)
            }
        }

        return tokens
    }
}
