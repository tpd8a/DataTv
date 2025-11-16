# Splunk Dashboard CLI Test Information

This file provides information about how to run tests for the Splunk Dashboard CLI.

## Test Suites Available

The CLI includes built-in tests for the following components:

1. **TokenResolver Tests** - Token extraction and resolution logic
2. **SimpleXMLTokenExtractor Tests** - XML parsing and token extraction  
3. **TokenStateManager Tests** - CoreData persistence and state management
4. **EntityIDGenerator Tests** - ID generation and validation

## How to Run Tests

Once you build the CLI, you can run tests using:

```bash
# Build the CLI
swift build

# Run all test suites
.build/debug/splunk-dashboard test --suite all

# Run individual test suites
.build/debug/splunk-dashboard test --suite resolver
.build/debug/splunk-dashboard test --suite extractor
.build/debug/splunk-dashboard test --suite state  
.build/debug/splunk-dashboard test --suite ids
```

## Test Implementation

The actual test implementations are located within each respective Swift file:
- TokenResolver.runTests() in TokenResolver.swift
- SimpleXMLTokenExtractor.runTests() in SimpleXMLTokenExtractor.swift  
- TokenStateManager.runTests() in TokenStateManager.swift
- EntityIDGenerator.runTests() in EntityIDGenerator.swift

## Access Control Fix

The primary compilation issue has been resolved by making the following methods public in SimpleXMLElement:
- attribute(_:)
- element(named:)
- elements(named:)
- All properties and initializer

The CLI should now build and run successfully!