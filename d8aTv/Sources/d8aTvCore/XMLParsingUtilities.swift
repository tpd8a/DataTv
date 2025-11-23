import Foundation

// MARK: - Shared Errors

/// Simple parsing error for XML utilities
public enum XMLParsingError: Error, LocalizedError {
    case invalidXMLString
    case noRootElement
    case parsingFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidXMLString:
            return "Invalid XML string encoding"
        case .noRootElement:
            return "No root element found in XML"
        case .parsingFailed(let message):
            return "XML parsing failed: \(message)"
        }
    }
}

// MARK: - Shared XML Parsing Utilities

/// Lightweight XML element wrapper for easier parsing
public class SimpleXMLElement {
    public let name: String
    public var attributes: [String: String]
    public var value: String?
    public var children: [SimpleXMLElement] = []
    public weak var parent: SimpleXMLElement?
    
    public init(name: String, attributes: [String: String] = [:]) {
        self.name = name
        self.attributes = attributes
    }
    
    public func attribute(_ name: String) -> String? {
        return attributes[name]
    }
    
    public func element(named name: String) -> SimpleXMLElement? {
        return children.first { $0.name == name }
    }
    
    public func elements(named name: String) -> [SimpleXMLElement] {
        return children.filter { $0.name == name }
    }
    
    public func allDescendants() -> [SimpleXMLElement] {
        var descendants: [SimpleXMLElement] = []
        for child in children {
            descendants.append(child)
            descendants.append(contentsOf: child.allDescendants())
        }
        return descendants
    }
    
    /// Extract all options and formats as structured data
    public func extractAllOptions() -> [String: Any] {
        var result: [String: Any] = [:]
        
        // Get direct options
        var options: [String: String] = [:]
        for child in children where child.name == "option" {
            if let name = child.attribute("name"), let value = child.value {
                options[name] = value
            }
        }
        
        // Get format elements as structured data
        var formats: [[String: Any]] = []
        for child in children where child.name == "format" {
            if let formatDict = extractFormat(from: child) {
                formats.append(formatDict)
            }
        }
        
        // Build result
        if !options.isEmpty {
            result["options"] = options
        }
        if !formats.isEmpty {
            result["formats"] = formats
        }
        
        return result
    }
    
    /// Extract a single format element as a structured dictionary
    private func extractFormat(from formatElement: SimpleXMLElement) -> [String: Any]? {
        guard let formatType = formatElement.attribute("type") else {
            return nil
        }
        
        var format: [String: Any] = [
            "type": formatType
        ]
        
        // Field attribute
        if let field = formatElement.attribute("field") {
            format["field"] = field
        }
        
        // Extract colorPalette
        if let paletteElement = formatElement.element(named: "colorPalette") {
            var palette: [String: Any] = [:]
            
            if let paletteType = paletteElement.attribute("type") {
                palette["type"] = paletteType
            }
            
            // Extract color values
            if let colorsValue = paletteElement.value, !colorsValue.isEmpty {
                // Parse color list - handle both "[#FF0000,#00FF00]" and "#FF0000,#00FF00" formats
                let cleanedColors = colorsValue
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "[", with: "")
                    .replacingOccurrences(of: "]", with: "")
                
                let colorArray = cleanedColors
                    .components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                
                if !colorArray.isEmpty {
                    palette["colors"] = colorArray
                }
            }
            
            // Extract min/mid/max colors
            if let minColor = paletteElement.attribute("minColor") {
                palette["minColor"] = minColor
            }
            if let midColor = paletteElement.attribute("midColor") {
                palette["midColor"] = midColor
            }
            if let maxColor = paletteElement.attribute("maxColor") {
                palette["maxColor"] = maxColor
            }
            
            if !palette.isEmpty {
                format["palette"] = palette
            }
        }
        
        // Extract scale
        if let scaleElement = formatElement.element(named: "scale") {
            var scale: [String: Any] = [:]
            
            if let scaleType = scaleElement.attribute("type") {
                scale["type"] = scaleType
            }
            
            // Extract threshold values
            if let thresholdValue = scaleElement.value, !thresholdValue.isEmpty {
                let thresholdArray = thresholdValue
                    .components(separatedBy: ",")
                    .compactMap { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                
                if !thresholdArray.isEmpty {
                    scale["values"] = thresholdArray
                }
            }
            
            // Extract min/mid/max values
            if let minValue = scaleElement.attribute("minValue"), let min = Double(minValue) {
                scale["minValue"] = min
            }
            if let midValue = scaleElement.attribute("midValue"), let mid = Double(midValue) {
                scale["midValue"] = mid
            }
            if let maxValue = scaleElement.attribute("maxValue"), let max = Double(maxValue) {
                scale["maxValue"] = max
            }
            
            if !scale.isEmpty {
                format["scale"] = scale
            }
        }
        
        // Extract nested options within format
        for optionElement in formatElement.elements(named: "option") {
            if let name = optionElement.attribute("name"), let value = optionElement.value {
                format[name] = value
            }
        }
        
        return format
    }
}

/// Simple XML Parser for Splunk SimpleXML dashboards
public class SimpleXMLParser: NSObject, XMLParserDelegate {
    private var root: SimpleXMLElement?
    private var currentElement: SimpleXMLElement?
    private var elementStack: [SimpleXMLElement] = []
    private var currentValue: String = ""
    
    public func parse(xmlString: String) throws -> SimpleXMLElement {
        guard let data = xmlString.data(using: .utf8) else {
            throw XMLParsingError.invalidXMLString
        }
        
        let parser = XMLParser(data: data)
        parser.delegate = self
        
        if parser.parse() {
            guard let root = root else {
                throw XMLParsingError.noRootElement
            }
            return root
        } else {
            if let error = parser.parserError {
                throw XMLParsingError.parsingFailed(error.localizedDescription)
            } else {
                throw XMLParsingError.parsingFailed("Unknown parsing error")
            }
        }
    }
    
    // MARK: - XMLParserDelegate
    
    public func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        let element = SimpleXMLElement(name: elementName, attributes: attributes)
        
        if root == nil {
            root = element
        }
        
        if let current = currentElement {
            current.children.append(element)
            element.parent = current
        }
        
        elementStack.append(element)
        currentElement = element
        currentValue = ""
    }
    
    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentValue += string
    }
    
    public func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        if let current = currentElement {
            let trimmed = currentValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                current.value = trimmed
            }
        }
        
        elementStack.removeLast()
        currentElement = elementStack.last
        currentValue = ""
    }
}

// MARK: - Token Validation Utilities

/// Shared token validation logic
public struct TokenValidator {
    
    /// Validates that a token name conforms to Splunk token naming rules
    public static func isValidTokenName(_ name: String) -> Bool {
        // Token names must:
        // 1. Start with a letter or underscore
        // 2. Contain only letters, numbers, underscores, and dots (for time components)
        // 3. Not be empty
        // 4. Not exceed reasonable length (e.g., 64 characters)
        
        guard !name.isEmpty && name.count <= 64 else {
            return false
        }
        
        // Check first character
        let firstChar = name.first!
        guard firstChar.isLetter || firstChar == "_" else {
            return false
        }
        
        // Check remaining characters
        for char in name.dropFirst() {
            guard char.isLetter || char.isNumber || char == "_" || char == "." else {
                return false
            }
        }
        
        return true
    }
    
    /// Extract token references from a string using regex
    /// Handles: $token$, $$token$$, $token.field$
    public static func extractTokenReferences(from text: String) -> Set<String> {
        var tokens: Set<String> = []
        
        // Pattern 1: $token$ (single dollar - will be escaped in SPL)
        let singleDollarPattern = #"\$([a-zA-Z_][a-zA-Z0-9_\.]*)\$"#
        if let regex = try? NSRegularExpression(pattern: singleDollarPattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                if let range = Range(match.range(at: 1), in: text) {
                    tokens.insert(String(text[range]))
                }
            }
        }
        
        // Pattern 2: $$token$$ (double dollar - no escaping)
        let doubleDollarPattern = #"\$\$([a-zA-Z_][a-zA-Z0-9_\.]*)\$\$"#
        if let regex = try? NSRegularExpression(pattern: doubleDollarPattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                if let range = Range(match.range(at: 1), in: text) {
                    tokens.insert(String(text[range]))
                }
            }
        }
        
        return tokens
    }
}
