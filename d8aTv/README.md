# d8aTv

**Splunk Dashboard Parser and Token Manager for tvOS**

A pure Swift implementation for parsing Splunk SimpleXML dashboards and rendering them natively on Apple TV.

## Features

- 📊 **Dashboard Parser** - Parse Splunk SimpleXML dashboards with full fidelity
- 🎯 **Token Management** - Extract, resolve, and manage dashboard tokens with dependency tracking
- 💾 **State Persistence** - CoreData-backed token state with session management
- 🆔 **Smart ID Generation** - Collision-resistant entity IDs with automatic fallbacks
- 🔧 **CLI Tool** - Complete command-line interface for testing and development
- 📱 **Multi-Platform** - Supports tvOS, iOS, and macOS

## Architecture

d8aTv uses a multi-process architecture designed for tvOS:

```
┌─────────────────────────────────────────────────────────────┐
│                      tvOS Swift App (GUI)                    │
│  • SwiftUI Interface                                         │
│  • Swift Charts Rendering                                    │
│  • Token Input Controls                                      │
└────────────────┬────────────────────────────────────────────┘
                 │
┌────────────────┴────────────────────────────────────────────┐
│  ┌───────────────────────────────┐  ┌────────────────────┐  │
│  │   Dashboard Parser Service    │  │  Data Engine       │  │
│  │  • Discovers dashboards       │  │  • Search executor │  │
│  │  • Parses SimpleXML/JSON      │  │  • Token resolver  │  │
│  │  • Extracts structure         │  │  • Result cacher   │  │
│  └───────────────────────────────┘  └────────────────────┘  │
│                                                               │
│                  ┌──────────────────────┐                    │
│                  │   Shared CoreData    │                    │
│                  └──────────────────────┘                    │
└───────────────────────────────────────────────────────────── ┘
```

## Components

### 1. TokenResolver
Resolves tokens in search queries with full dependency resolution:
- Circular dependency detection
- Prefix/suffix application
- Token validation
- SHA256-based hashing for cache keys

### 2. SimpleXMLTokenExtractor
Extracts tokens from Splunk dashboard XML:
- All token types (time, dropdown, text, multiselect, etc.)
- Form inputs, init blocks, and dynamic tokens
- Dependency graph building
- Configuration preservation

### 3. TokenStateManager
Manages token state with persistence:
- CoreData storage
- Combine publishers for reactive updates
- Dirty tracking for re-execution
- Session management

### 4. EntityIDGenerator
Generates collision-resistant IDs:
- Smart fallback strategies
- ID registry and collision detection
- Deterministic hashing
- Validation and sanitization

### 5. CLI Tool
Complete command-line interface:
- Parse dashboards
- Manage tokens
- Resolve queries
- Run tests
- Generate IDs

## Installation

### As a Library

Add d8aTv to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/d8aTv", from: "1.0.0")
]
```

### CLI Tool

```bash
# Clone the repository
git clone https://github.com/yourusername/d8aTv
cd d8aTv

# Build
swift build -c release

# Install
cp .build/release/d8atv-cli /usr/local/bin/
```

## Usage

### Library Usage

```swift
import d8aTvCore

// Parse a dashboard
let parser = SimpleXMLParser()
let root = try parser.parse(xmlString: dashboardXML)

// Extract tokens
let extractor = SimpleXMLTokenExtractor(dashboardID: "my_dashboard")
let tokens = try extractor.extractTokens(from: root)

// Manage state
let stateManager = TokenStateManager(dashboardID: "my_dashboard")
try stateManager.storeTokenDefinitions(tokens)
try stateManager.initializeDefaults()

// Resolve queries
let context = try stateManager.getTokenContext()
let resolver = TokenResolver(context: context)
let resolved = try resolver.resolve(query: "$index$ $host$ | stats count")
```

### CLI Usage

```bash
# Parse a dashboard
d8atv-cli parse --file dashboard.xml --verbose

# Manage tokens
d8atv-cli tokens --dashboard-id my_dashboard --file dashboard.xml --initialize --list

# Resolve a query
d8atv-cli resolve --dashboard-id my_dashboard --file dashboard.xml \
    '$index$ $host$ | stats count'

# Run tests
d8atv-cli test --suite all

# Generate IDs
d8atv-cli id --dashboard "Server Monitoring"
```

## Testing

```bash
# Run all tests
swift test

# Run CLI tests
d8atv-cli test --suite all

# Run specific test suite
d8atv-cli test --suite resolver
d8atv-cli test --suite extractor
d8atv-cli test --suite state
d8atv-cli test --suite ids
```

## Token Types Supported

- ✅ **Time tokens** - With `.earliest` and `.latest` sub-tokens
- ✅ **Dropdown** - Static and dynamic choices
- ✅ **Text input**
- ✅ **Multiselect** - With delimiter support
- ✅ **Radio buttons**
- ✅ **Checkbox**
- ✅ **Link lists**
- ✅ **Calculated tokens** - From `<init>` and `<set>` blocks

## Roadmap

- [ ] Complete Data Engine Service (search execution, caching)
- [ ] Splunk REST API client
- [ ] Dashboard Studio (JSON) support
- [ ] SwiftUI tvOS viewer
- [ ] Swift Charts visualization renderers
- [ ] Search result transformers
- [ ] Drilldown support
- [ ] Real-time search support
- [ ] Custom visualization support

## Requirements

- Swift 5.9+
- macOS 13+ / iOS 16+ / tvOS 16+
- Xcode 15+

## Contributing

Contributions are welcome! Please read our contributing guidelines before submitting PRs.

## License

MIT License - see LICENSE file for details

## Author

Built for parsing and rendering Splunk dashboards natively on Apple TV.

## Acknowledgments

- Inspired by Splunk's SimpleXML dashboard format
- Built with Swift's modern concurrency and Combine framework
- Uses CoreData for persistent storage
