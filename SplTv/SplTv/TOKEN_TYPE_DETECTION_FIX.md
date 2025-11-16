# Token Input Type Detection Fix

## Problem

The `TokenEntity.type` field in CoreData stores a generic value like "input", but the **actual token type** (dropdown, text, radio, etc.) is stored in `rawAttributes["type"]`.

### Example CoreData Structure
```json
{
  "name": "filename",
  "type": "input",  // ❌ Generic, not useful
  "rawAttributes": {
    "type": "dropdown",  // ✅ Actual type we need
    "token": "filename",
    "searchWhenChanged": "true"
  },
  "label": "File Chooser",
  "initialValue": "*.log",
  "defaultValue": "*.log",
  "choices": [
    { "label": "splunk ui", "value": "splunk_ui_access.log" },
    { "label": "splunk d", "value": "splunkd.log" },
    { "label": "python", "value": "python.log" },
    { "label": "all", "value": "*.log" }
  ]
}
```

## Solution

Updated `TokenInputView` to:
1. ✅ Parse the actual type from `rawAttributes["type"]`
2. ✅ Fall back to entity's `type` field if rawAttributes not available
3. ✅ Initialize values from `initialValue` or `defaultValue`
4. ✅ Properly display choices with their labels
5. ✅ Track selected choice in state variable

## Code Changes

### 1. Type Detection Method
```swift
/// Get the actual token type from rawAttributes["type"]
private var actualTokenType: String {
    guard let rawAttrs = token.attributesDictionary["rawAttributes"] as? [String: Any],
          let typeString = rawAttrs["type"] as? String else {
        // Fallback to the entity's type field
        return token.type.lowercased()
    }
    return typeString.lowercased()
}
```

### 2. Input Control Switching
```swift
@ViewBuilder
private var inputControl: some View {
    let tokenType = actualTokenType  // ✅ Use parsed type
    
    switch tokenType {
    case "text":
        textInput
    case "dropdown":
        dropdownInput  // ✅ Shows choices with labels
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
        unknownInput(typeString: tokenType)  // ✅ Shows unsupported types
    }
}
```

### 3. Dropdown Implementation
```swift
private var dropdownInput: some View {
    Picker(selection: $selectedChoice) {
        if token.choicesArray.isEmpty {
            Text("No choices available")
                .tag("")
        } else {
            ForEach(token.choicesArray, id: \.value) { choice in
                Text(choice.label)  // ✅ Shows label (e.g., "splunk ui")
                    .tag(choice.value)  // ✅ Stores value (e.g., "splunk_ui_access.log")
            }
        }
    } label: {
        EmptyView()
    }
    .pickerStyle(.menu)
    .font(.caption)
    .disabled(token.choicesArray.isEmpty)
    .onChange(of: selectedChoice) { _, newValue in
        saveTokenValue(newValue)  // ✅ Saves when changed
    }
}
```

### 4. Value Initialization
```swift
private func initializeValues() {
    // Priority: initialValue > defaultValue > first choice
    var initialValue: String? = nil
    
    if let initial = token.initialValue, !initial.isEmpty {
        initialValue = initial
    } else if let defaultVal = token.defaultValue, !defaultVal.isEmpty {
        initialValue = defaultVal
    } else if !token.choicesArray.isEmpty {
        // Use first choice if no default specified
        initialValue = token.choicesArray.first?.value
    }
    
    // Set the value
    if let value = initialValue {
        textValue = value
        selectedChoice = value  // ✅ Sets initial selection
        
        // For multiselect/checkbox, parse comma-separated values
        if actualTokenType == "multiselect" || actualTokenType == "checkbox" {
            let values = value.split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespaces) }
            selectedChoices = Set(values)
        }
        
        print("🎛️ Initialized token '\(token.name)' with value: \(value)")
    }
}
```

## Result

### Before
❌ Token type was always "input" (generic)  
❌ Couldn't determine which control to show  
❌ Dropdown choices not displayed  
❌ Initial values not set  

### After
✅ Reads actual type from `rawAttributes["type"]`  
✅ Correctly renders dropdown with choices  
✅ Shows choice **labels** (user-friendly)  
✅ Stores choice **values** (for search queries)  
✅ Initializes with `initialValue` or `defaultValue`  
✅ Tracks selection in `@State` variable  

## Example UI Output

For the token shown above, the UI now displays:

```
File Chooser
┌─────────────────────────┐
│ all                  ▼ │  ← Dropdown shows "all" (label)
└─────────────────────────┘

When expanded:
┌─────────────────────────┐
│ splunk ui               │
│ splunk d                │
│ python                  │
│ all                  ✓  │  ← Currently selected
└─────────────────────────┘
```

Internal state stores: `selectedChoice = "*.log"` (value, not label)

## Debug Output

When token initializes:
```
🎛️ Initialized token 'filename' with value: *.log
```

When user changes selection:
```
Token 'filename' set to: splunk_ui_access.log
```

## Supported Token Types

| Type | Status | Control |
|------|--------|---------|
| text | ✅ Working | TextField |
| dropdown | ✅ Working | Picker (menu) |
| radio | ✅ Working | Radio buttons |
| checkbox | ✅ Working | Checkboxes |
| multiselect | ✅ Working | Collapsible checkboxes |
| time | ✅ Working | Time range menu |
| link | ✅ Working | Link menu |
| (unknown) | ✅ Handled | Warning message |

## Next Steps (TODO)

1. **Token State Persistence**
   - Store token values in a central manager
   - Persist across app restarts
   
2. **Search Integration**
   - Substitute `$token_name$` in search queries
   - Example: `index=_internal source=$filename$`
   
3. **Auto-refresh on Change**
   - Respect `searchWhenChanged` attribute
   - Trigger search execution when token changes
   
4. **Submit Button**
   - Connect fieldset submit button to search execution
   - Batch all token changes together
   
5. **Dynamic Population**
   - Support tokens populated from search results
   - Parse `populatingSearch`, `populatingFieldForValue`, `populatingFieldForLabel`

6. **Validation**
   - Implement `required` validation
   - Support custom validation patterns
   
7. **Dependencies**
   - Handle `depends` and `rejects` attributes
   - Show/hide tokens based on other token values
