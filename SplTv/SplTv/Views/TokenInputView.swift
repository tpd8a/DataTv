import SwiftUI
import DashboardKit

/// Renders an individual token input control based on TokenAdapter
struct TokenInputView: View {
    let adapter: TokenAdapter

    @State private var textValue: String = ""
    @State private var selectedChoice: String = ""
    @State private var selectedChoices: Set<String> = []
    @State private var isExpanded: Bool = false

    @ObservedObject private var tokenManager = DashboardTokenManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Label
            labelView

            // Input control based on type
            inputControl
        }
        .onAppear {
            initializeValues()
        }
    }

    // MARK: - Label

    private var labelView: some View {
        Group {
            if let label = adapter.label, !label.isEmpty {
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
            } else {
                Text(adapter.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Input Control Router

    @ViewBuilder
    private var inputControl: some View {
        switch adapter.type.lowercased() {
        case "text":
            textInput
        case "dropdown":
            dropdownInput
        case "radio":
            radioInput
        case "checkbox":
            checkboxInput
        case "multiselect":
            multiselectInput
        case "time":
            timeInput
        case "link":
            linkInput
        default:
            unknownInput
        }
    }

    // MARK: - Input Types

    private var textInput: some View {
        TextField(adapter.name, text: $textValue)
            .textFieldStyle(.roundedBorder)
            .font(.caption)
            .onChange(of: textValue) { _, newValue in
                saveTokenValue(newValue)
            }
    }

    private var dropdownInput: some View {
        Picker(selection: $selectedChoice) {
            if adapter.choices.isEmpty {
                Text("No choices available")
                    .tag("")
            } else {
                ForEach(adapter.choices) { choice in
                    Text(choice.label)
                        .tag(choice.value)
                }
            }
        } label: {
            EmptyView()
        }
        .pickerStyle(.menu)
        .font(.caption)
        .disabled(adapter.choices.isEmpty)
        .onChange(of: selectedChoice) { _, newValue in
            saveTokenValue(newValue)
        }
    }

    private var radioInput: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(adapter.choices) { choice in
                Button {
                    selectedChoice = choice.value
                    saveTokenValue(choice.value)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: selectedChoice == choice.value ? "circle.circle.fill" : "circle")
                            .foregroundStyle(selectedChoice == choice.value ? .blue : .secondary)
                            .imageScale(.small)

                        Text(choice.label)
                            .font(.caption)
                            .foregroundStyle(.primary)

                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .disabled(choice.disabled)
            }
        }
    }

    private var checkboxInput: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(adapter.choices) { choice in
                Toggle(isOn: createBinding(for: choice)) {
                    Text(choice.label)
                        .font(.caption)
                }
                .toggleStyle(.checkbox)
                .disabled(choice.disabled)
            }
        }
    }

    private var multiselectInput: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("\(selectedChoices.count) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(adapter.choices) { choice in
                    Toggle(isOn: createBinding(for: choice)) {
                        Text(choice.label)
                            .font(.caption)
                    }
                    .toggleStyle(.checkbox)
                    .disabled(choice.disabled)
                }
            }
        }
    }

    private var timeInput: some View {
        Menu {
            Button("Last 15 minutes") { setTimeRange("-15m", "now") }
            Button("Last hour") { setTimeRange("-1h", "now") }
            Button("Last 4 hours") { setTimeRange("-4h", "now") }
            Button("Last 24 hours") { setTimeRange("-24h", "now") }
            Button("Last 7 days") { setTimeRange("-7d", "now") }
            Button("Last 30 days") { setTimeRange("-30d", "now") }
        } label: {
            HStack {
                Text(textValue.isEmpty ? "Select time range" : textValue)
                    .font(.caption)
                    .foregroundStyle(textValue.isEmpty ? .secondary : .primary)

                Spacer()

                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
    }

    private var linkInput: some View {
        Menu {
            ForEach(adapter.choices) { choice in
                Button(choice.label) {
                    selectedChoice = choice.value
                    saveTokenValue(choice.value)
                }
            }
        } label: {
            HStack {
                Text(selectedChoice.isEmpty ? "Select..." : selectedChoiceLabel)
                    .font(.caption)
                    .foregroundStyle(selectedChoice.isEmpty ? .secondary : .primary)

                Spacer()

                Image(systemName: "link")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
        .disabled(adapter.choices.isEmpty)
    }

    private var unknownInput: some View {
        HStack {
            Image(systemName: "questionmark.circle")
                .foregroundStyle(.orange)
                .font(.caption)

            VStack(alignment: .leading, spacing: 2) {
                Text("Unsupported type: \(adapter.type)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !adapter.choices.isEmpty {
                    Text("\(adapter.choices.count) choices defined")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .help("Token '\(adapter.name)' has unsupported type '\(adapter.type)'")
    }

    // MARK: - Helper Methods

    private func initializeValues() {
        let initialValue = adapter.initialValue ?? ""
        textValue = initialValue
        selectedChoice = initialValue

        // For multiselect/checkbox, parse comma-separated values
        if ["multiselect", "checkbox"].contains(adapter.type.lowercased()) {
            let values = initialValue.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
            selectedChoices = Set(values)
        }

        print("🎛️ Initialized token '\(adapter.name)' with value: \(initialValue)")
    }

    private func saveTokenValue(_ value: String) {
        textValue = value

        // Apply formatting (prefix/suffix) before saving
        let formattedValue = adapter.formatTokenValue(value)
        tokenManager.setTokenValue(formattedValue, forToken: adapter.name, source: .user)
        print("🎛️ Token '\(adapter.name)' set to: '\(formattedValue)' (raw: '\(value)')")

        // Execute change handler if present (use raw value, not formatted)
        if let handler = adapter.changeHandler {
            let label = adapter.getLabel(forValue: value) ?? value
            tokenManager.executeChangeHandler(handler, selectedValue: value, selectedLabel: label)
            print("🎛️ Executed change handler for '\(adapter.name)'")
        }
    }

    private func setTimeRange(_ earliest: String, _ latest: String) {
        let rangeText = "\(earliest) to \(latest)"
        textValue = rangeText
        saveTokenValue(rangeText)
    }

    private func createBinding(for choice: InputChoice) -> Binding<Bool> {
        Binding(
            get: { selectedChoices.contains(choice.value) },
            set: { isSelected in
                if isSelected {
                    selectedChoices.insert(choice.value)
                } else {
                    selectedChoices.remove(choice.value)
                }

                // For multiselect, use array-based formatting with valuePrefix/valueSuffix/delimiter
                let valuesArray = Array(selectedChoices)

                if valuesArray.isEmpty {
                    // No selections - UNSET the token (remove from dictionary)
                    tokenManager.unsetTokenValue(forToken: adapter.name)
                } else {
                    // Format and set token value
                    let formattedValue = adapter.formatTokenValue("", values: valuesArray)
                    tokenManager.setTokenValue(formattedValue, forToken: adapter.name, source: .user)
                    print("🎛️ Multiselect token '\(adapter.name)' set to: '\(formattedValue)' (raw values: \(valuesArray))")
                }

                // Execute change handler if present (use joined raw values)
                if let handler = adapter.changeHandler {
                    let joinedValue = valuesArray.joined(separator: ",")
                    tokenManager.executeChangeHandler(handler, selectedValue: joinedValue, selectedLabel: joinedValue)
                    print("🎛️ Executed change handler for '\(adapter.name)'")
                }
            }
        )
    }

    private var selectedChoiceLabel: String {
        adapter.choices.first(where: { $0.value == selectedChoice })?.label ?? selectedChoice
    }
}
