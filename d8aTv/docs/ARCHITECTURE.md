# d8aTv Architecture

## Overview

d8aTv is designed as a multi-process system for parsing and rendering Splunk dashboards on tvOS.

## Core Components

### 1. Token System

The token system consists of three main parts:

#### TokenResolver
- Resolves tokens in search queries
- Handles dependency ordering via topological sort
- Detects circular dependencies
- Applies prefix/suffix transformations

#### SimpleXMLTokenExtractor
- Parses Splunk SimpleXML
- Extracts all token types
- Builds dependency graphs
- Preserves configuration

#### TokenStateManager
- Manages token values with CoreData
- Provides Combine publishers for reactivity
- Tracks dirty tokens for re-execution
- Handles session persistence

### 2. ID Generation

EntityIDGenerator creates unique, deterministic IDs:
- Multiple fallback strategies
- Collision detection and resolution
- Content-based hashing (SHA256)
- Validation and sanitization

### 3. Dashboard Structure

Hierarchy:
```
Dashboard
  ├── Tokens
  └── Rows
       └── Panels
            ├── Search
            └── Visualization
```

## Data Flow

```
XML Input → Parser → Token Extractor → State Manager → Resolver → Splunk API
                                                            ↓
                                                      CoreData Cache
```

## Future Architecture

The complete system will include:

1. **Dashboard Parser Service** (✅ Complete)
2. **Data Engine Service** (🚧 In Progress)
   - Search execution
   - Result caching
   - Scheduling
3. **Splunk REST API Client** (📋 Planned)
4. **Visualization Renderers** (📋 Planned)
5. **tvOS GUI** (📋 Planned)

## Threading Model

- Main thread: UI and state updates
- Background contexts: CoreData operations
- Async/await: Network requests and parsing

## Performance Considerations

- CoreData batch operations
- Token resolution caching via SHA256 hashes
- Lazy loading of dashboard components
- Search result TTL management

