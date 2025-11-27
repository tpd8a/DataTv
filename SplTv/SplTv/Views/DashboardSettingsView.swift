import SwiftUI

// MARK: - Dashboard Settings View

struct DashboardSettingsView: View {
    @StateObject private var settings = DashboardMonitorSettings.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Configure how cell changes are highlighted in search results")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Label("Cell Change Display", systemImage: "paintbrush.fill")
                }
                
                Section {
                    Picker("Highlight Style", selection: $settings.cellChangeSettings.highlightStyle) {
                        ForEach(CellChangeSettings.HighlightStyle.allCases) { style in
                            VStack(alignment: .leading) {
                                Text(style.rawValue)
                                Text(style.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(style)
                        }
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text("Style")
                }
                
                if settings.cellChangeSettings.highlightStyle != .splunkDefault {
                    Section {
                        if settings.cellChangeSettings.highlightStyle == .customColor {
                            ColorPicker("Custom Color", selection: $settings.cellChangeSettings.customColor)
                        }
                        
                        if settings.cellChangeSettings.highlightStyle == .directional {
                            ColorPicker("Increase Color", selection: $settings.cellChangeSettings.increaseColor)
                            ColorPicker("Decrease Color", selection: $settings.cellChangeSettings.decreaseColor)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Fill Opacity")
                                Spacer()
                                Text("\(Int(settings.cellChangeSettings.fillOpacity * 100))%")
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $settings.cellChangeSettings.fillOpacity, in: 0.1...1.0, step: 0.05)
                        }
                        
                        Toggle("Show Frame Overlay", isOn: $settings.cellChangeSettings.showOverlay)
                        
                        if settings.cellChangeSettings.showOverlay {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Frame Width")
                                    Spacer()
                                    Text("\(Int(settings.cellChangeSettings.frameWidth))pt")
                                        .foregroundStyle(.secondary)
                                }
                                Slider(value: $settings.cellChangeSettings.frameWidth, in: 1...4, step: 0.5)
                            }
                        }
                    } header: {
                        Text("Appearance")
                    }
                    
                    Section {
                        Toggle("Glow and Fade Animation", isOn: $settings.cellChangeSettings.animateChanges)
                        
                        if settings.cellChangeSettings.animateChanges {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Animation Duration")
                                    Spacer()
                                    Text(String(format: "%.1fs", settings.cellChangeSettings.animationDuration))
                                        .foregroundStyle(.secondary)
                                }
                                Slider(value: $settings.cellChangeSettings.animationDuration, in: 0.5...3.0, step: 0.1)
                            }
                        }
                    } header: {
                        Text("Animation")
                    } footer: {
                        Text("Cells will glow when changes are detected, then fade to the configured opacity")
                            .font(.caption)
                    }
                    
                    Section {
                        previewSection
                    } header: {
                        Text("Preview")
                    }
                }
                
                // Table Appearance Section
                Section {
                    // Font Design Picker
                    Picker("Font", selection: $settings.tableAppearance.fontDesign) {
                        Text("Default").tag(Font.Design.default)
                        Text("Serif").tag(Font.Design.serif)
                        Text("Rounded").tag(Font.Design.rounded)
                        Text("Monospaced").tag(Font.Design.monospaced)
                    }
                    
                    // Font Size Slider
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Font Size")
                            Spacer()
                            Text("\(Int(settings.tableAppearance.fontSize))pt")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $settings.tableAppearance.fontSize, in: 9...24, step: 1)
                    }
                    
                    // Font Weight Picker
                    Picker("Weight", selection: $settings.tableAppearance.fontWeight) {
                        Text("Ultralight").tag(Font.Weight.ultraLight)
                        Text("Thin").tag(Font.Weight.thin)
                        Text("Light").tag(Font.Weight.light)
                        Text("Regular").tag(Font.Weight.regular)
                        Text("Medium").tag(Font.Weight.medium)
                        Text("Semibold").tag(Font.Weight.semibold)
                        Text("Bold").tag(Font.Weight.bold)
                        Text("Heavy").tag(Font.Weight.heavy)
                        Text("Black").tag(Font.Weight.black)
                    }
                    
                    // Italic Toggle
                    Toggle("Italic", isOn: $settings.tableAppearance.isItalic)
                    
                } header: {
                    Label("Table Appearance", systemImage: "tablecells")
                }
                
                // Text & Cell Options (grouped together)
                Section {
                    // Text color options
                    HStack {
                        Text("Text Color")
                        Spacer()
                        if settings.tableAppearance.customTextColor != nil {
                            Button("Reset") {
                                settings.tableAppearance.customTextColor = nil
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                        }
                    }
                    
                    if let textColor = Binding(
                        get: { settings.tableAppearance.customTextColor ?? .primary },
                        set: { settings.tableAppearance.customTextColor = $0 }
                    ) as Binding<Color>? {
                        ColorPicker("", selection: textColor, supportsOpacity: false)
                            .labelsHidden()
                            .disabled(settings.tableAppearance.customTextColor == nil)
                    }
                    
                    Toggle(settings.tableAppearance.customTextColor == nil ? "Use Custom Text Color" : "Using Custom Text Color",
                           isOn: Binding(
                        get: { settings.tableAppearance.customTextColor != nil },
                        set: { enabled in
                            if enabled {
                                settings.tableAppearance.customTextColor = .primary
                            } else {
                                settings.tableAppearance.customTextColor = nil
                            }
                        }
                    ))
                    
                    Divider()
                    
                    // Changed cell text color
                    HStack {
                        Text("Changed Cell Text Color")
                        Spacer()
                        if settings.tableAppearance.changedCellTextColor != nil {
                            Button("Reset") {
                                settings.tableAppearance.changedCellTextColor = nil
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                        }
                    }
                    
                    if let changedTextColor = Binding(
                        get: { settings.tableAppearance.changedCellTextColor ?? .orange },
                        set: { settings.tableAppearance.changedCellTextColor = $0 }
                    ) as Binding<Color>? {
                        ColorPicker("", selection: changedTextColor, supportsOpacity: false)
                            .labelsHidden()
                            .disabled(settings.tableAppearance.changedCellTextColor == nil)
                    }
                    
                    Toggle(settings.tableAppearance.changedCellTextColor == nil ? "Use Custom Changed Text Color" : "Using Custom Changed Text Color",
                           isOn: Binding(
                        get: { settings.tableAppearance.changedCellTextColor != nil },
                        set: { enabled in
                            if enabled {
                                settings.tableAppearance.changedCellTextColor = .orange
                            } else {
                                settings.tableAppearance.changedCellTextColor = nil
                            }
                        }
                    ))
                    
                    Divider()
                    
                    // Cell background
                    Toggle("Custom Cell Background", isOn: $settings.tableAppearance.useCustomCellBackground)
                    
                    if settings.tableAppearance.useCustomCellBackground {
                        ColorPicker("Background Color", selection: $settings.tableAppearance.customCellBackgroundColor, supportsOpacity: false)
                    }
                }
                
                // Zebra Striping (separate section as requested)
                Section {
                    Toggle("Zebra Striping", isOn: $settings.tableAppearance.enableZebraStriping)
                    
                    if settings.tableAppearance.enableZebraStriping {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Stripe Opacity")
                                Spacer()
                                Text("\(Int(settings.tableAppearance.zebraStripeOpacity * 100))%")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            Slider(value: $settings.tableAppearance.zebraStripeOpacity, in: 0.01...0.5, step: 0.01)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Dashboard Settings")
            #if os(macOS)
            .frame(minWidth: 500, minHeight: 600)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        settings.loadSettings()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        settings.saveSettings()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var previewSection: some View {
        VStack(spacing: 12) {
            Text("Preview of highlighted cells:")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 20) {
                previewCell(label: "Changed", isIncrease: nil)
                
                if settings.cellChangeSettings.highlightStyle == .directional {
                    previewCell(label: "Increased", isIncrease: true)
                    previewCell(label: "Decreased", isIncrease: false)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func previewCell(label: String, isIncrease: Bool?) -> some View {
        let color = cellColor(isIncrease: isIncrease)
        
        return Text(label)
            .font(.caption)
            .padding(8)
            .frame(minWidth: 100)
            .background(color.opacity(settings.cellChangeSettings.fillOpacity))
            .overlay(
                settings.cellChangeSettings.showOverlay ?
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(color, lineWidth: settings.cellChangeSettings.frameWidth)
                        .padding(2)
                : nil
            )
            .cornerRadius(4)
    }
    
    private func cellColor(isIncrease: Bool?) -> Color {
        switch settings.cellChangeSettings.highlightStyle {
        case .splunkDefault:
            return .clear
        case .systemColors:
            #if os(macOS)
            return Color(nsColor: .controlAccentColor)
            #else
            return .accentColor
            #endif
        case .customColor:
            return settings.cellChangeSettings.customColor
        case .directional:
            if let isIncrease = isIncrease {
                return isIncrease ? settings.cellChangeSettings.increaseColor : settings.cellChangeSettings.decreaseColor
            }
            return settings.cellChangeSettings.customColor
        }
    }
}
