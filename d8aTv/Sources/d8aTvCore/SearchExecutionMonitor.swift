import Foundation
import Combine
import CoreData

// MARK: - Notification Messages (macOS 26.0+ / tvOS 26.0+)

@available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct SearchProgressUpdate: NotificationCenter.AsyncMessage {
    public typealias Subject = SearchExecutionMonitor
    
    public let executionId: String
    public let status: String
    public let progress: Double
    public let message: String
    
    public init(executionId: String, status: String, progress: Double, message: String) {
        self.executionId = executionId
        self.status = status
        self.progress = progress
        self.message = message
    }
}

@available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct SearchCompleted: NotificationCenter.AsyncMessage {
    public typealias Subject = SearchExecutionMonitor
    
    public let executionId: String
    public let resultCount: Int
    public let scanCount: Int
    public let executionDuration: TimeInterval
    
    public init(executionId: String, resultCount: Int, scanCount: Int = 0, executionDuration: TimeInterval = 0) {
        self.executionId = executionId
        self.resultCount = resultCount
        self.scanCount = scanCount
        self.executionDuration = executionDuration
    }
}

@available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct SearchJobCreated: NotificationCenter.AsyncMessage {
    public typealias Subject = SearchExecutionMonitor
    
    public let executionId: String
    public let jobId: String
    
    public init(executionId: String, jobId: String) {
        self.executionId = executionId
        self.jobId = jobId
    }
}

@available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct SearchCancelled: NotificationCenter.AsyncMessage {
    public typealias Subject = SearchExecutionMonitor
    
    public let executionId: String
    
    public init(executionId: String) {
        self.executionId = executionId
    }
}

// MARK: - Worker Connection Protocol

public protocol WorkerConnection: Sendable {
    func sendRequest(_ request: SearchRequest) async throws -> String
    var executionUpdates: AnyPublisher<SearchExecutionUpdate, Never> { get }
}

public enum SearchExecutionUpdate: Sendable {
    case progress(executionId: String, percent: Int, message: String)
    case completed(executionId: String, resultCount: Int, duration: TimeInterval)
    case failed(executionId: String, error: String)
    case jobCreated(executionId: String, jobId: String)
    case cancelled(executionId: String)
}

public struct SearchRequest: Sendable {
    public let searchId: String
    public let dashboardId: String?
    public let timeRange: (String, String)
    public let parameterOverrides: SearchParameterOverrides
    
    public init(
        searchId: String,
        dashboardId: String?,
        timeRange: (String, String),
        parameterOverrides: SearchParameterOverrides
    ) {
        self.searchId = searchId
        self.dashboardId = dashboardId
        self.timeRange = timeRange
        self.parameterOverrides = parameterOverrides
    }
}


// MARK: - Thread-Safe State Container

private actor ExecutionState {
    private var activeExecutions: [SearchExecutionSummary] = []
    private var isMonitoring: Bool = false
    
    func setMonitoring(_ value: Bool) {
        isMonitoring = value
    }
    
    func updateActiveExecutions(_ executions: [SearchExecutionSummary]) {
        activeExecutions = executions
    }
    
    func addOrUpdateExecution(_ execution: SearchExecutionSummary) {
        if let index = activeExecutions.firstIndex(where: { $0.id == execution.id }) {
            activeExecutions[index] = execution
        } else if !execution.isComplete {
            activeExecutions.append(execution)
        }
    }
    
    func removeExecution(id: String) {
        activeExecutions.removeAll { $0.id == id }
    }
    
    func removeCompletedExecutions() {
        activeExecutions.removeAll { $0.isComplete }
    }
    
    func getActiveExecutions() -> [SearchExecutionSummary] {
        return activeExecutions
    }
    
    func getIsMonitoring() -> Bool {
        return isMonitoring
    }
}

// MARK: - Main Monitor Class

/// Thread-safe search execution monitor
/// Uses @unchecked Sendable because ObservableObject uses internal synchronization
@available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, *)
public final class SearchExecutionMonitor: ObservableObject, @unchecked Sendable {
    
    // MARK: - Published Properties
    @Published public private(set) var activeExecutions: [SearchExecutionSummary] = []
    @Published public private(set) var isMonitoring: Bool = false
    
    // MARK: - Private Properties
    private let workerConnection: WorkerConnection?
    private let state = ExecutionState()
    
    // Thread-safe notification handling
    private let notificationQueue = DispatchQueue(label: "com.searchmonitor.notifications", attributes: .concurrent)
    private let observerLock = NSLock()
    private var notificationObservers: [Any] = []
    
    // Combine subscriptions
    private let cancellableLock = NSLock()
    private var updateCancellable: AnyCancellable?
    
    // MARK: - Initialization
    
    public nonisolated init(workerConnection: WorkerConnection? = nil) {
        self.workerConnection = workerConnection
    }
    
    // MARK: - Public Interface
    
    public func startMonitoring() async {
        let alreadyMonitoring = await state.getIsMonitoring()
        guard !alreadyMonitoring else { return }
        
        await state.setMonitoring(true)
        await updatePublishedProperties()
        
        print("🔍 Starting search execution monitoring...")
        
        await refreshActiveExecutions()
        setupNotificationObservers()
        
        if let connection = workerConnection {
            setupWorkerConnection(connection)
        }
        
        print("✅ Search execution monitoring started")
    }
    
    public func stopMonitoring() async {
        let wasMonitoring = await state.getIsMonitoring()
        guard wasMonitoring else { return }
        
        await state.setMonitoring(false)
        await updatePublishedProperties()
        
        cleanupObservers()
        
        print("⏹ Search execution monitoring stopped")
    }
    
    public func refreshActiveExecutions() async {
        let summaries = await MainActor.run {
            let executions = CoreDataManager.shared.getActiveSearchExecutions()
            return executions.compactMap { execution in
                CoreDataManager.shared.getExecutionSummary(executionId: execution.id)
            }
        }
        
        await state.updateActiveExecutions(summaries)
        await updatePublishedProperties()
        
        if !summaries.isEmpty {
            print("📊 Found \(summaries.count) active search executions")
            summaries.forEach(printExecutionStatus)
        }
    }
    
    public func getExecutionHistory(
        searchId: String? = nil,
        dashboardId: String? = nil,
        limit: Int = 10
    ) async -> [SearchExecutionSummary] {
        return await MainActor.run {
            let allExecutions = CoreDataManager.shared.getAllSearchExecutions()
            
            let filteredExecutions = allExecutions.filter { execution in
                let matchesSearch = searchId == nil || execution.searchId == searchId
                let matchesDashboard = dashboardId == nil || execution.dashboardId == dashboardId
                return matchesSearch && matchesDashboard
            }
            
            return filteredExecutions
                .prefix(limit)
                .compactMap { CoreDataManager.shared.getExecutionSummary(executionId: $0.id) }
        }
    }
    
    public func getSearchResults(executionId: String) async -> SplunkSearchResults? {
        return await CoreDataManager.shared.getSearchResults(executionId: executionId)
    }
    
    public func exportResults(executionId: String, to filePath: String) async throws {
        guard let results = await getSearchResults(executionId: executionId) else {
            throw SearchExecutionError.searchNotFound(executionId)
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(results)
        
        let url = URL(fileURLWithPath: filePath)
        try jsonData.write(to: url)
        
        print("📄 Results exported to: \(filePath)")
        print("   \(results.results.count) records written")
    }
    
    public func cancelExecution(executionId: String) async {
        await CoreDataManager.shared.cancelSearchExecution(executionId: executionId)
        print("🛑 Cancellation requested for execution: \(executionId)")
    }
    
    public func cleanupOldExecutions(days: Int = 7) async throws {
        try await CoreDataManager.shared.cleanupOldSearchExecutions(days: days)
        await refreshActiveExecutions()
    }
    
    // MARK: - Private Implementation
    
    
    
    
    private func setupNotificationObservers() {
        observerLock.lock()
        defer { observerLock.unlock() }
        
        // Use the new type-safe AsyncMessage API
        let progressToken = NotificationCenter.default.addObserver(
            of: self,
            for: SearchProgressUpdate.self
        ) { [weak self] message in
            await self?.handleProgressUpdate(message)
        }
        
        let completionToken = NotificationCenter.default.addObserver(
            of: self,
            for: SearchCompleted.self
        ) { [weak self] message in
            await self?.handleCompletionUpdate(message)
        }
        
        let jobCreatedToken = NotificationCenter.default.addObserver(
            of: self,
            for: SearchJobCreated.self
        ) { [weak self] message in
            await self?.handleJobCreatedUpdate(message)
        }
        
        let cancelledToken = NotificationCenter.default.addObserver(
            of: self,
            for: SearchCancelled.self
        ) { [weak self] message in
            await self?.handleCancelledUpdate(message)
        }
        
        // Store tokens for cleanup
        notificationObservers.append(progressToken)
        notificationObservers.append(completionToken)
        notificationObservers.append(jobCreatedToken)
        notificationObservers.append(cancelledToken)
    }
    
    // Legacy notification handling for older OS versions
    
    /**    private func setupLegacyNotificationObservers() {
        let notifications: [Notification.Name] = [
            .searchExecutionProgressUpdated,
            .searchExecutionCompleted,
            .searchJobCreated,
            .searchExecutionCancelled
        ]
        
        for name in notifications {
            let observer = NotificationCenter.default.addObserver(
                forName: name,
                object: nil,
                queue: nil
            ) { [weak self] notification in
                Task.detached {
                    await self?.processLegacyNotification(notification)
                }
            }
            notificationObservers.append(observer)
        }
    }
    */

    // Handle legacy notifications (non-Sendable compatible)
    private func processLegacyNotification(_ notification: Notification) async {
        // Extract data synchronously before async processing
        let name = notification.name
        let userInfo = notification.userInfo
        
        switch name {
        case .searchExecutionProgressUpdated:
            guard let userInfo = userInfo,
                  let executionId = userInfo["executionId"] as? String,
                  let status = userInfo["status"] as? String,
                  let progress = userInfo["progress"] as? Double,
                  let message = userInfo["message"] as? String else { return }
            
            await updateLocalExecution(executionId: executionId)
            let progressPercent = Int(progress * 100)
            let statusEmoji = getStatusEmoji(status)
            print("\(statusEmoji) [\(executionId.prefix(8))] \(progressPercent)% - \(message)")
            
        case .searchExecutionCompleted:
            guard let userInfo = userInfo,
                  let executionId = userInfo["executionId"] as? String,
                  let resultCount = userInfo["resultCount"] as? Int else { return }
            
            let scanCount = userInfo["scanCount"] as? Int ?? 0
            let duration = userInfo["executionDuration"] as? TimeInterval ?? 0
            
            await state.removeExecution(id: executionId)
            await updatePublishedProperties()
            
            let shortId = String(executionId.prefix(8))
            let durationStr = String(format: "%.1f", duration)
            print("✅ [\(shortId)] Completed - \(resultCount) results in \(durationStr)s (scanned: \(scanCount))")
            
        case .searchJobCreated:
            guard let userInfo = userInfo,
                  let executionId = userInfo["executionId"] as? String,
                  let jobId = userInfo["jobId"] as? String else { return }
            
            print("🔗 [\(executionId.prefix(8))] Splunk job created: \(jobId)")
            await updateLocalExecution(executionId: executionId)
            
        case .searchExecutionCancelled:
            guard let userInfo = userInfo,
                  let executionId = userInfo["executionId"] as? String else { return }
            
            print("🛑 [\(executionId.prefix(8))] Cancelled by user")
            await state.removeExecution(id: executionId)
            await updatePublishedProperties()
            
        default:
            break
        }
    }
    
    private func setupWorkerConnection(_ connection: WorkerConnection) {
        cancellableLock.lock()
        defer { cancellableLock.unlock() }
        
        updateCancellable = connection.executionUpdates
            .receive(on: notificationQueue)
            .sink { [weak self] update in
                // The update is already Sendable, so we can pass it directly
                Task.detached { @Sendable [weak self] in
                    await self?.handleWorkerUpdate(update)
                }
            }
    }
    

        
    func cleanupObservers() {
        observerLock.lock()
        let observers = notificationObservers
        notificationObservers.removeAll()
        observerLock.unlock()
        
        // Clean up the AsyncMessage tokens
        observers.forEach { observer in
            if let token = observer as? NotificationCenter.ObservationToken {
                NotificationCenter.default.removeObserver(token)
            }
        }
        
        cancellableLock.lock()
        updateCancellable?.cancel()
        updateCancellable = nil
        cancellableLock.unlock()
    }
    
    
    
    
    
    // MARK: - AsyncMessage Handlers
    
    private func handleProgressUpdate(_ message: SearchProgressUpdate) async {
        await updateLocalExecution(executionId: message.executionId)
        
        let progressPercent = Int(message.progress * 100)
        let statusEmoji = getStatusEmoji(message.status)
        print("\(statusEmoji) [\(message.executionId.prefix(8))] \(progressPercent)% - \(message.message)")
    }
    
    private func handleCompletionUpdate(_ message: SearchCompleted) async {
        await state.removeExecution(id: message.executionId)
        await updatePublishedProperties()
        
        let shortId = String(message.executionId.prefix(8))
        let durationStr = String(format: "%.1f", message.executionDuration)
        print("✅ [\(shortId)] Completed - \(message.resultCount) results in \(durationStr)s (scanned: \(message.scanCount))")
    }
    
    private func handleJobCreatedUpdate(_ message: SearchJobCreated) async {
        print("🔗 [\(message.executionId.prefix(8))] Splunk job created: \(message.jobId)")
        await updateLocalExecution(executionId: message.executionId)
    }
    
    private func handleCancelledUpdate(_ message: SearchCancelled) async {
        print("🛑 [\(message.executionId.prefix(8))] Cancelled by user")
        await state.removeExecution(id: message.executionId)
        await updatePublishedProperties()
    }
    
    // MARK: - Worker Update Handler
    
    private func handleWorkerUpdate(_ update: SearchExecutionUpdate) async {
        switch update {
        case .progress(let executionId, let percent, let message):
            await updateLocalExecution(executionId: executionId)
            print("🔄 [\(executionId.prefix(8))] \(percent)% - \(message)")
            
        case .completed(let executionId, let resultCount, let duration):
            await state.removeExecution(id: executionId)
            await updatePublishedProperties()
            let durationStr = String(format: "%.1f", duration)
            print("✅ [\(executionId.prefix(8))] Completed - \(resultCount) results in \(durationStr)s")
            
        case .failed(let executionId, let error):
            await state.removeExecution(id: executionId)
            await updatePublishedProperties()
            print("❌ [\(executionId.prefix(8))] Failed - \(error)")
            
        case .jobCreated(let executionId, let jobId):
            print("🔗 [\(executionId.prefix(8))] Splunk job created: \(jobId)")
            await updateLocalExecution(executionId: executionId)
            
        case .cancelled(let executionId):
            await state.removeExecution(id: executionId)
            await updatePublishedProperties()
            print("🛑 [\(executionId.prefix(8))] Cancelled")
        }
    }
    
    private func updateLocalExecution(executionId: String) async {
        let updatedSummary = await MainActor.run {
            CoreDataManager.shared.getExecutionSummary(executionId: executionId)
        }
        
        guard let summary = updatedSummary else { return }
        
        await state.addOrUpdateExecution(summary)
        await state.removeCompletedExecutions()
        await updatePublishedProperties()
    }
    
    private func updatePublishedProperties() async {
        let executions = await state.getActiveExecutions()
        let monitoring = await state.getIsMonitoring()
        
        await MainActor.run {
            self.activeExecutions = executions
            self.isMonitoring = monitoring
        }
    }
    
    private func getStatusEmoji(_ status: String) -> String {
        switch status {
        case "pending": return "⏳"
        case "running": return "🔄"
        case "completed": return "✅"
        case "failed": return "❌"
        case "cancelled": return "🛑"
        default: return "❓"
        }
    }
    
    private func printExecutionStatus(_ execution: SearchExecutionSummary) {
        let emoji = getStatusEmoji(execution.status.rawValue)
        let progressPercent = Int(execution.progress * 100)
        let shortId = String(execution.id.prefix(8))
        
        var statusLine = "\(emoji) [\(shortId)] \(progressPercent)%"
        
        if let message = execution.message {
            statusLine += " - \(message)"
        }
        
        if let jobId = execution.jobId {
            statusLine += " (SID: \(jobId))"
        }
        
        print(statusLine)
    }
    
    deinit {
        cleanupObservers()
    }
}

// MARK: - CLI Wrapper

/// CLI wrapper that's properly Sendable
@available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, *)
public final class CLISearchMonitor: Sendable {
    // Store the monitor as a let constant for Sendable compliance
    private let monitor: SearchExecutionMonitor
    
    public nonisolated init(workerConnection: WorkerConnection? = nil) {
        self.monitor = SearchExecutionMonitor(workerConnection: workerConnection)
    }
    
    public func monitorWithPolling(pollInterval: TimeInterval = 1.0) async {
        await monitor.startMonitoring()
        
        defer {
            Task {
                await monitor.stopMonitoring()
            }
        }
        
        while monitor.isMonitoring {
            try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
            
            let hasActive = !monitor.activeExecutions.isEmpty
            if !hasActive {
                print("No active executions.")
                break
            }
        }
    }
    
    public func printStatus() {
        let executions = monitor.activeExecutions
        if executions.isEmpty {
            print("No active search executions")
        } else {
            print("📊 Found \(executions.count) active search executions")
            for execution in executions {
                print("  - \(execution.id.prefix(8)): \(execution.status.rawValue)")
            }
        }
    }
    
    public func exportResults(executionId: String, to filePath: String) async throws {
        try await monitor.exportResults(executionId: executionId, to: filePath)
    }
}


// MARK: - Worker Connection Implementation Options

// Option 1: Using AsyncStream (Recommended - fully Sendable)
public final class UnixSocketConnection: WorkerConnection, @unchecked Sendable {
    private let socketPath: String
    private let updateStream: AsyncStream<SearchExecutionUpdate>
    private let continuation: AsyncStream<SearchExecutionUpdate>.Continuation
    private let subject = PassthroughSubject<SearchExecutionUpdate, Never>()
    private var streamTask: Task<Void, Never>?
    
    public init(socketPath: String) {
        self.socketPath = socketPath
        
        var cont: AsyncStream<SearchExecutionUpdate>.Continuation!
        self.updateStream = AsyncStream { continuation in
            cont = continuation
        }
        self.continuation = cont
        
        // Bridge AsyncStream to Combine Publisher
        self.streamTask = Task {
            for await update in updateStream {
                subject.send(update)
            }
        }
    }
    
    public func sendRequest(_ request: SearchRequest) async throws -> String {
        print("📡 Sending request to worker at \(socketPath)")
        // Here you would actually send the request via Unix socket
        return UUID().uuidString
    }
    
    public var executionUpdates: AnyPublisher<SearchExecutionUpdate, Never> {
        subject.eraseToAnyPublisher()
    }
    
    /// Simulate receiving an update (for testing)
    public func simulateUpdate(_ update: SearchExecutionUpdate) {
        continuation.yield(update)
    }
    
    deinit {
        continuation.finish()
        streamTask?.cancel()
    }
}

// Option 2: Using a Coordinator Actor
public actor WorkerConnectionActor {
    private var updates: [SearchExecutionUpdate] = []
    private var continuations: [CheckedContinuation<SearchExecutionUpdate, Never>] = []
    
    func addUpdate(_ update: SearchExecutionUpdate) {
        if !continuations.isEmpty {
            let continuation = continuations.removeFirst()
            continuation.resume(returning: update)
        } else {
            updates.append(update)
        }
    }
    
    func nextUpdate() async -> SearchExecutionUpdate {
        if !updates.isEmpty {
            return updates.removeFirst()
        }
        
        return await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }
}

public final class ActorBasedConnection: WorkerConnection, @unchecked Sendable {
    private let socketPath: String
    private let coordinator = WorkerConnectionActor()
    private let subject = PassthroughSubject<SearchExecutionUpdate, Never>()
    private var bridgeTask: Task<Void, Never>?
    
    public init(socketPath: String) {
        self.socketPath = socketPath
        
        // Bridge actor updates to Combine
        self.bridgeTask = Task {
            while !Task.isCancelled {
                let update = await coordinator.nextUpdate()
                subject.send(update)
            }
        }
    }
    
    public func sendRequest(_ request: SearchRequest) async throws -> String {
        print("📡 Sending request to worker at \(socketPath)")
        return UUID().uuidString
    }
    
    public var executionUpdates: AnyPublisher<SearchExecutionUpdate, Never> {
        subject.eraseToAnyPublisher()
    }
    
    public func simulateUpdate(_ update: SearchExecutionUpdate) async {
        await coordinator.addUpdate(update)
    }
    
    deinit {
        bridgeTask?.cancel()
    }
}

// Option 3: Simple Lock-Based Implementation
public final class LockBasedConnection: WorkerConnection, @unchecked Sendable {
    private let socketPath: String
    private let subject = PassthroughSubject<SearchExecutionUpdate, Never>()
    private let lock = NSLock()
    
    public init(socketPath: String) {
        self.socketPath = socketPath
    }
    
    public func sendRequest(_ request: SearchRequest) async throws -> String {
        print("📡 Sending request to worker at \(socketPath)")
        return UUID().uuidString
    }
    
    public var executionUpdates: AnyPublisher<SearchExecutionUpdate, Never> {
        lock.lock()
        defer { lock.unlock() }
        return subject.eraseToAnyPublisher()
    }
    
    public func simulateUpdate(_ update: SearchExecutionUpdate) {
        lock.lock()
        defer { lock.unlock() }
        subject.send(update)
    }
}

// MARK: - Convenience Methods for Posting Messages

@available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, *)
public extension SearchExecutionMonitor {
    /// Post a progress update using the new AsyncMessage API
    func postProgressUpdate(executionId: String, status: String, progress: Double, message: String) {
        let progressMessage = SearchProgressUpdate(
            executionId: executionId,
            status: status,
            progress: progress,
            message: message
        )
        NotificationCenter.default.post(progressMessage, subject: self)
    }
    
    /// Post a completion update using the new AsyncMessage API
    func postCompletionUpdate(executionId: String, resultCount: Int, scanCount: Int = 0, executionDuration: TimeInterval = 0) {
        let completionMessage = SearchCompleted(
            executionId: executionId,
            resultCount: resultCount,
            scanCount: scanCount,
            executionDuration: executionDuration
        )
        NotificationCenter.default.post(completionMessage, subject: self)
    }
    
    /// Post a job created update using the new AsyncMessage API
    func postJobCreatedUpdate(executionId: String, jobId: String) {
        let jobMessage = SearchJobCreated(executionId: executionId, jobId: jobId)
        NotificationCenter.default.post(jobMessage, subject: self)
    }
    
    /// Post a cancellation update using the new AsyncMessage API
    func postCancellationUpdate(executionId: String) {
        let cancelMessage = SearchCancelled(executionId: executionId)
        NotificationCenter.default.post(cancelMessage, subject: self)
    }
}




/**
 
 /MARK: - Usage Examples

 func demonstrateConnections() async {
     // Option 1: AsyncStream-based (Recommended)
     let connection1 = UnixSocketConnection(socketPath: "/tmp/worker.sock")
     connection1.simulateUpdate(.progress(executionId: "123", percent: 50, message: "Processing"))
     
     // Option 2: Actor-based
     let connection2 = ActorBasedConnection(socketPath: "/tmp/worker.sock")
     await connection2.simulateUpdate(.completed(executionId: "123", resultCount: 100, duration: 5.0))
     
     // Option 3: Lock-based (Simplest)
     let connection3 = LockBasedConnection(socketPath: "/tmp/worker.sock")
     connection3.simulateUpdate(.jobCreated(executionId: "123", jobId: "job456"))
     
     // All three can be used with SearchExecutionMonitor
     let monitor = SearchExecutionMonitor(workerConnection: connection1)
     await monitor.startMonitoring()
     
     // MARK: - Using New AsyncMessage API (macOS 26.0+)
     if #available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, *) {
         // Post messages using the type-safe API
         monitor.postProgressUpdate(
             executionId: "exec123",
             status: "running",
             progress: 0.75,
             message: "Processing data..."
         )
         
         monitor.postCompletionUpdate(
             executionId: "exec123",
             resultCount: 150,
             scanCount: 1000,
             executionDuration: 5.2
         )
         
         monitor.postJobCreatedUpdate(executionId: "exec123", jobId: "job789")
         monitor.postCancellationUpdate(executionId: "exec123")
         
     } else {
         // Fall back to legacy notifications for older OS versions
         NotificationCenter.default.post(
             name: .searchExecutionProgressUpdated,
             object: monitor,
             userInfo: [
                 "executionId": "exec123",
                 "status": "running",
                 "progress": 0.75,
                 "message": "Processing data..."
             ]
         )
         
         NotificationCenter.default.post(
             name: .searchExecutionCompleted,
             object: monitor,
             userInfo: [
                 "executionId": "exec123",
                 "resultCount": 150,
                 "scanCount": 1000,
                 "executionDuration": 5.2
             ]
         )
     }
}

**/

