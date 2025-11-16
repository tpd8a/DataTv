# Swift Concurrency Data Race Fixes - Comprehensive Guide

## Overview of Changes

The original code had several data race issues stemming from improper mixing of `@MainActor` isolation with background operations and unsafe notification handling. Here's how the fixes address each issue:

## Key Problems and Solutions

### 1. **Actor Isolation Violations**

**Problem:** The original `@MainActor` class was trying to handle notifications from arbitrary threads, causing data races when accessing properties.

**Solution:** 
- Introduced a separate `ExecutionState` actor to manage all mutable state
- Removed `@MainActor` from the main class, using it only for `@Published` properties
- All state mutations go through the actor's async methods

```swift
// Thread-safe state container
private actor ExecutionState {
    var activeExecutions: [SearchExecutionSummary] = []
    var isMonitoring: Bool = false
    
    // All mutations are isolated to the actor
    func addOrUpdateExecution(_ execution: SearchExecutionSummary) {
        // Safe mutation within actor isolation
    }
}
```

### 2. **NotificationCenter Thread Safety**

**Problem:** Notification observers were capturing `self` and accessing properties from arbitrary threads.

**Solution:**
- Use block-based observers instead of selectors
- Process all notifications through a concurrent queue
- Convert notification handling to async/await pattern

```swift
private func setupNotificationObservers() {
    let observer = NotificationCenter.default.addObserver(
        forName: name,
        object: nil,
        queue: nil // Don't specify a queue
    ) { [weak self] notification in
        // Dispatch to our own queue for processing
        self?.notificationQueue.async {
            self?.processNotification(notification)
        }
    }
}
```

### 3. **Proper Sendable Conformance**

**Problem:** Missing `Sendable` conformance led to hidden data races.

**Solution:**
- Made all shared types explicitly `Sendable`
- Used `@unchecked Sendable` for the main class with proper synchronization
- Ensured all protocols are `Sendable`

```swift
public protocol WorkerConnection: Sendable { ... }
public enum SearchExecutionUpdate: Sendable { ... }
public struct SearchRequest: Sendable { ... }
```

### 4. **Published Property Updates**

**Problem:** `@Published` properties require MainActor but were being updated from background threads.

**Solution:**
- Separate internal state (in actor) from published state
- Update published properties only through a MainActor-isolated method

```swift
@MainActor
private func updatePublishedState() async {
    let executions = await state.getActiveExecutions()
    self.activeExecutions = executions
}
```

### 5. **Lock-Based Synchronization**

**Problem:** Combine cancellables and observer arrays needed thread-safe access.

**Solution:**
- Use `NSLock` for synchronizing access to non-actor properties
- Properly lock/unlock around all accesses

```swift
private let observerLock = NSLock()
private let cancellableLock = NSLock()

private func setupWorkerConnection(_ connection: WorkerConnection) {
    cancellableLock.lock()
    defer { cancellableLock.unlock() }
    updateCancellable = connection.executionUpdates.sink { ... }
}
```

## Best Practices Applied

### 1. **Actor-Based State Management**

- All mutable state lives in actors
- Public interface is async to allow actor isolation
- No direct property access from outside the actor

### 2. **Structured Concurrency**

- Use `Task` for async work from sync contexts
- Proper `async`/`await` throughout
- No fire-and-forget dispatches

### 3. **Weak Self in Closures**

- Always use `[weak self]` in notification/Combine closures
- Prevents retain cycles and crashes

### 4. **Queue Management**

- Single concurrent queue for all notification processing
- Prevents queue explosion and provides predictable ordering
- Async processing from the queue to actor methods

### 5. **Deinit Safety**

- Properly clean up observers in deinit
- Use locks to safely access cancellables
- No MainActor assumptions in deinit

## Architecture Pattern

The fixed architecture follows this pattern:

```
External Events (Notifications/Worker)
    ↓
Concurrent Processing Queue
    ↓
Async Event Handlers
    ↓
Actor State Updates
    ↓
MainActor UI Updates (if needed)
```

## Testing Considerations

To verify the fixes work correctly:

1. **Run with Thread Sanitizer**: Enable TSan in your scheme to detect races
2. **Stress Test**: Create many concurrent updates
3. **Test Cancellation**: Ensure proper cleanup during rapid start/stop cycles

## Migration Guide

If migrating existing code to this pattern:

1. **Extract State**: Move all mutable state to an actor
2. **Convert Methods**: Make public methods async
3. **Fix Notifications**: Switch to block-based observers with queuing
4. **Add Sendable**: Mark all shared types as Sendable
5. **Separate UI Updates**: Use MainActor only for @Published properties

## Common Pitfalls to Avoid

1. **Don't Mix Isolation**: Don't use @MainActor on classes that handle background work
2. **Don't Assume Thread**: Never assume which thread notifications arrive on
3. **Don't Skip Sendable**: Always mark shared types as Sendable
4. **Don't Forget Weak**: Always use weak self in long-lived closures
5. **Don't Share Mutable State**: Use actors or locks for all shared mutable state

## Performance Considerations

- Actor isolation has minimal overhead
- Concurrent queue processing maintains performance
- Batch UI updates to avoid excessive MainActor hops
- Use structured concurrency for predictable performance

## Conclusion

The fixed code eliminates data races by:
- Properly isolating state in actors
- Using structured concurrency patterns
- Ensuring thread-safe notification handling
- Maintaining clear boundaries between UI and background work

This approach is more maintainable, safer, and follows Swift's concurrency best practices.
