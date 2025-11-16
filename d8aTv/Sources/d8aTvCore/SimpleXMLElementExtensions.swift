import Foundation

// MARK: - Convenience Extensions for SimpleXMLElement

extension SimpleXMLElement {
    
   
    /// Check if this element represents a visualization type
    var isVisualizationType: Bool {
        return ["chart", "table", "single", "map", "event", "viz", "html"].contains(name)
    }
    
    /// Find all visualization elements in this tree
    var allVisualizations: [SimpleXMLElement] {
        return allDescendants().filter { $0.isVisualizationType }
    }
    
    /// Get search element (common in panels)
    var searchElement: SimpleXMLElement? {
        return element(named: "search")
    }
    
    /// Extract search query from nested search element
    var searchQuery: String? {
        return searchElement?.element(named: "query")?.value
    }
    
    /// Extract earliest time from nested search element
    var earliestTime: String? {
        return searchElement?.element(named: "earliest")?.value
    }
    
    /// Extract latest time from nested search element
    var latestTime: String? {
        return searchElement?.element(named: "latest")?.value
    }
    
    /// Extract all panel elements from a dashboard
    var panels: [SimpleXMLElement] {
        if name == "dashboard" {
            // Panels can be direct children or in rows
            var allPanels: [SimpleXMLElement] = []
            
            // Direct panels
            allPanels.append(contentsOf: elements(named: "panel"))
            
            // Panels in rows
            for row in elements(named: "row") {
                allPanels.append(contentsOf: row.elements(named: "panel"))
            }
            
            return allPanels
        }
        return []
    }
    
    /// Extract all row elements from a dashboard
    var rows: [SimpleXMLElement] {
        return elements(named: "row")
    }
    
    /// Extract all fieldset elements (for input controls)
    var fieldsets: [SimpleXMLElement] {
        return elements(named: "fieldset")
    }
    
    /// Extract all input elements from a fieldset
    var inputs: [SimpleXMLElement] {
        if name == "fieldset" {
            let inputTypes = ["input", "text", "dropdown", "time", "radio", "checkbox", "multiselect", "link"]
            return children.filter { inputTypes.contains($0.name) }
        }
        return []
    }
    
    /// Check if element has a specific attribute value
    func hasAttribute(_ name: String, withValue value: String) -> Bool {
        return attribute(name) == value
    }
    
    /// Get boolean attribute value (handles "true", "false", "1", "0")
    func boolAttribute(_ name: String, default defaultValue: Bool = false) -> Bool {
        guard let value = attribute(name) else { return defaultValue }
        let lowercased = value.lowercased()
        return lowercased == "true" || lowercased == "1" || lowercased == "yes"
    }
    
    /// Get integer attribute value
    func intAttribute(_ name: String, default defaultValue: Int = 0) -> Int {
        guard let value = attribute(name) else { return defaultValue }
        return Int(value) ?? defaultValue
    }
    
    /// Get double attribute value
    func doubleAttribute(_ name: String, default defaultValue: Double = 0.0) -> Double {
        guard let value = attribute(name) else { return defaultValue }
        return Double(value) ?? defaultValue
    }
}

// MARK: - Dashboard Structure Navigation

extension SimpleXMLElement {
    
    /// Get dashboard metadata (title, description, etc.)
    var dashboardMetadata: DashboardMetadata? {
        guard name == "dashboard" || name == "form" else { return nil }
        
        let title = element(named: "label")?.value
        let description = element(named: "description")?.value
        let version = attribute("version")
        let theme = attribute("theme")
        let hideEdit = boolAttribute("hideEdit")
        let hideExport = boolAttribute("hideExport")
        
        return DashboardMetadata(
            title: title,
            description: description,
            version: version,
            theme: theme,
            hideEdit: hideEdit,
            hideExport: hideExport
        )
    }
    
    /// Get panel metadata
    var panelMetadata: PanelMetadata? {
        guard name == "panel" else { return nil }
        
        let title = element(named: "title")?.value
        let id = attribute("id")
        let depends = attribute("depends")
        let rejects = attribute("rejects")
        let ref = attribute("ref")
        
        return PanelMetadata(
            id: id,
            title: title,
            depends: depends,
            rejects: rejects,
            ref: ref
        )
    }
}

// MARK: - Supporting Metadata Structures

/// Dashboard-level metadata
struct DashboardMetadata {
    let title: String?
    let description: String?
    let version: String?
    let theme: String?
    let hideEdit: Bool
    let hideExport: Bool
}

/// Panel-level metadata
struct PanelMetadata {
    let id: String?
    let title: String?
    let depends: String?
    let rejects: String?
    let ref: String?
}

// MARK: - Query Helpers

extension SimpleXMLElement {
    
    /// Find all elements matching a predicate
    func findAll(where predicate: (SimpleXMLElement) -> Bool) -> [SimpleXMLElement] {
        var results: [SimpleXMLElement] = []
        
        if predicate(self) {
            results.append(self)
        }
        
        for child in children {
            results.append(contentsOf: child.findAll(where: predicate))
        }
        
        return results
    }
    
    /// Find first element matching a predicate
    func findFirst(where predicate: (SimpleXMLElement) -> Bool) -> SimpleXMLElement? {
        if predicate(self) {
            return self
        }
        
        for child in children {
            if let found = child.findFirst(where: predicate) {
                return found
            }
        }
        
        return nil
    }
    
    /// Find elements by name at any depth
    func findElements(named name: String) -> [SimpleXMLElement] {
        return findAll { $0.name == name }
    }
    
    /// Find element by id attribute at any depth
    func findElement(withId id: String) -> SimpleXMLElement? {
        return findFirst { $0.attribute("id") == id }
    }
}

// MARK: - Debugging Helpers

extension SimpleXMLElement {
    
    /// Generate a tree representation for debugging
    func treeDescription(indent: Int = 0) -> String {
        let prefix = String(repeating: "  ", count: indent)
        var description = "\(prefix)<\(name)"
        
        // Add attributes
        for (key, value) in attributes.sorted(by: { $0.key < $1.key }) {
            description += " \(key)=\"\(value)\""
        }
        description += ">"
        
        // Add value if present
        if let value = value, !value.isEmpty {
            description += " \(value)"
        }
        
        // Add children
        if !children.isEmpty {
            description += "\n"
            for child in children {
                description += child.treeDescription(indent: indent + 1) + "\n"
            }
            description += "\(prefix)</\(name)>"
        } else {
            description += "</\(name)>"
        }
        
        return description
    }
    
    /// Get a summary of this element
    var summary: String {
        var parts: [String] = [name]
        
        if let id = attribute("id") {
            parts.append("id=\(id)")
        }
        
        if let title = element(named: "title")?.value {
            parts.append("title=\(title)")
        }
        
        if !children.isEmpty {
            parts.append("\(children.count) children")
        }
        
        return parts.joined(separator: ", ")
    }
    
    /// Count elements by type
    func countElements() -> [String: Int] {
        var counts: [String: Int] = [:]
        
        func count(_ element: SimpleXMLElement) {
            counts[element.name, default: 0] += 1
            for child in element.children {
                count(child)
            }
        }
        
        count(self)
        return counts
    }
}

// MARK: - Validation Helpers

extension SimpleXMLElement {
    
    /// Validate that required attributes are present
    func validateAttributes(_ required: [String]) -> [String] {
        var missing: [String] = []
        
        for attr in required {
            if attribute(attr) == nil {
                missing.append(attr)
            }
        }
        
        return missing
    }
    
    /// Validate that required child elements are present
    func validateChildren(_ required: [String]) -> [String] {
        var missing: [String] = []
        
        for childName in required {
            if element(named: childName) == nil {
                missing.append(childName)
            }
        }
        
        return missing
    }
    
    /// Check if element structure is valid
    var isValid: Bool {
        // Basic validation - can be extended
        if name.isEmpty {
            return false
        }
        
        // Check for circular references via parent chain
        var current = parent
        var depth = 0
        while let p = current {
            depth += 1
            if depth > 100 { // Arbitrary limit
                return false
            }
            current = p.parent
        }
        
        return true
    }
}
