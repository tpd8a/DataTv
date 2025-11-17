import Foundation

/// Represents a choice option for dashboard inputs (dropdown, radio, etc.)
/// Parsed from DashboardInput.optionsJSON
public struct InputChoice: Identifiable, Equatable {
    public let id = UUID()
    public let label: String
    public let value: String
    public let isDefault: Bool
    public let disabled: Bool

    public init(label: String, value: String, isDefault: Bool = false, disabled: Bool = false) {
        self.label = label
        self.value = value
        self.isDefault = isDefault
        self.disabled = disabled
    }
}

/// Parsed options from DashboardInput.optionsJSON
public struct InputOptions: Codable {
    public let choices: [ChoiceData]?
    public let defaultValue: String?
    public let token: String?

    public struct ChoiceData: Codable {
        public let label: String
        public let value: String
        public let isDefault: Bool?
        public let disabled: Bool?

        private enum CodingKeys: String, CodingKey {
            case label, value
            case isDefault = "default"
            case disabled
        }
    }
}
