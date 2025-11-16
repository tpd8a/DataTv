# Splunk SimpleXML Dashboard Loader

A Swift CLI tool for loading and querying Splunk SimpleXML dashboards in Core Data.

## Features

- 📥 Load SimpleXML dashboard files into Core Data persistence
- 🔍 Query dashboard structure, tokens, and searches
- 🏷️ Search for specific tokens and their usage across dashboards
- 📊 Generate statistics and summaries
- 🗂️ Support for batch loading from directories

## Installation

1. Clone the repository
2. Build the CLI tool:
   ```bash
   swift build -c release
   ```

3. (Optional) Copy the built executable to your PATH:
   ```bash
   cp .build/release/splunk-dashboard /usr/local/bin/
   ```

## Usage

### Loading Dashboards

```bash
# Load a single dashboard
swift run splunk-dashboard load /path/to/dashboard.xml

# Load with custom ID
swift run splunk-dashboard load /path/to/dashboard.xml --id my-dashboard

# Load all XML files in a directory
swift run splunk-dashboard load /path/to/dashboards/ --recursive

# Load with verbose output
swift run splunk-dashboard load /path/to/dashboard.xml --verbose
```

### Querying Data

```bash
# List all loaded dashboards
swift run splunk-dashboard query list

# Show detailed information about a specific dashboard
swift run splunk-dashboard query show my-dashboard

# List all tokens across all dashboards
swift run splunk-dashboard query tokens

# Find tokens matching a pattern
swift run splunk-dashboard query find-tokens "time"

# Show detailed information about a specific token
swift run splunk-dashboard query token time_picker

# List all searches (optionally filtered by dashboard)
swift run splunk-dashboard query searches --dashboard my-dashboard

# Find searches that use a specific token
swift run splunk-dashboard query find-searches time_picker

# Show overall statistics
swift run splunk-dashboard query stats
```

### Data Management

```bash
# Clear all data (with confirmation prompt)
swift run splunk-dashboard clear

# Force clear without confirmation
swift run splunk-dashboard clear --force
```

## Core Data Model

The tool uses a comprehensive Core Data model to represent Splunk dashboards:

- **DashboardEntity**: Root dashboard with metadata and relationships
- **RowEntity**: Dashboard layout rows
- **PanelEntity**: Individual panels within rows
- **TokenEntity**: Form inputs and their configurations
- **TokenChoiceEntity**: Dropdown/radio button choices
- **SearchEntity**: SPL searches with token references
- **VisualizationEntity**: Charts, tables, and other viz components

## Examples

### Loading a Dashboard Directory

```bash
# Load all XML files recursively from a directory
swift run splunk-dashboard load ~/splunk/dashboards --recursive --verbose
```

### Analyzing Token Usage

```bash
# Find all time-related tokens
swift run splunk-dashboard query find-tokens "time"

# See which searches use the "earliest" token
swift run splunk-dashboard query find-searches "earliest"

# Get detailed info about a specific token
swift run splunk-dashboard query token "time_range" --dashboard "security_overview"
```

### Dashboard Analysis

```bash
# Get overview statistics
swift run splunk-dashboard query stats

# Examine a specific dashboard structure
swift run splunk-dashboard query show "network_monitoring"

# List all searches in a dashboard
swift run splunk-dashboard query searches --dashboard "network_monitoring"
```

## Architecture

### Core Components

1. **XMLParsingUtilities**: SimpleXML parsing with token extraction
2. **DashboardLoader**: Converts XML to Core Data entities
3. **DashboardQueryEngine**: Query interface for loaded data
4. **CoreDataManager**: Core Data stack management
5. **CLI**: ArgumentParser-based command interface

### Token Analysis

The system automatically extracts and analyzes:
- Token references in searches (`$token$`, `$$token$$`)
- Form input definitions and their properties
- Token dependencies and conditional logic
- Choice-based tokens (dropdowns, radio buttons)
- Time range tokens with earliest/latest settings

### Data Persistence

- Uses Core Data for robust persistence
- SHA256 hashing for change detection
- Automatic relationship management
- Support for batch operations

## Error Handling

The tool provides comprehensive error handling for:
- Invalid XML files
- Missing Core Data model files
- File system access issues
- Network or permission errors

All errors include descriptive messages to help with troubleshooting.

## Requirements

- Swift 5.9+
- macOS 13+ (for Core Data and file system access)
- Core Data model file: `tmpDashboardModel.xcdatamodeld`

## Notes

- Dashboard IDs default to the filename without extension
- Duplicate dashboards are detected by XML content hash
- Token references are automatically extracted from SPL queries
- All raw XML attributes are preserved for full fidelity