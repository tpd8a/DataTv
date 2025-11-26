import Foundation
import SwiftUI
import Combine

/// Global timeline controller that synchronizes all dashboard visualizations by timestamp
/// Uses time-based synchronization - all visualizations show data from the same moment in time
@MainActor
class GlobalTimelineController: ObservableObject {
    static let shared = GlobalTimelineController()

    // MARK: - Published Properties

    /// Current playback timestamp - all visualizations sync to this time
    @Published var currentTimestamp: Date? = nil

    /// Whether playback is currently active
    @Published var isPlaying: Bool = false

    /// Playback speed in seconds between timestamp steps
    @Published var playbackSpeed: TimeInterval = 2.0

    // MARK: - Private Properties

    /// All available timestamps across all data sources (sorted oldest to newest)
    private var availableTimestamps: [Date] = []

    /// Current index in availableTimestamps array
    private var currentIndex: Int = 0

    /// Timer for automatic playback
    private var playbackTimer: Timer?

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Set the available timestamps from all data sources
    func setTimestamps(_ timestamps: [Date]) {
        availableTimestamps = timestamps.sorted() // Oldest to newest
        print("🕐 GlobalTimeline: Set \(timestamps.count) timestamps")

        // Initialize to latest (most recent)
        if !availableTimestamps.isEmpty {
            currentIndex = availableTimestamps.count - 1
            currentTimestamp = availableTimestamps[currentIndex]
            print("🕐 GlobalTimeline: Initialized to latest: \(currentTimestamp?.description ?? "nil")")
        }
    }

    /// Start playback - step backward through time
    func play() {
        guard !availableTimestamps.isEmpty else {
            print("🕐 GlobalTimeline: Cannot play - no timestamps available")
            return
        }

        isPlaying = true
        print("🕐 GlobalTimeline: Starting playback from index \(currentIndex)")

        playbackTimer = Timer.scheduledTimer(withTimeInterval: playbackSpeed, repeats: true) { [weak self] _ in
            self?.stepBackward()

            // Stop when we reach the oldest timestamp
            if let self = self, self.currentIndex == 0 {
                print("🕐 GlobalTimeline: Reached oldest timestamp - stopping playback")
                self.pause()
            }
        }
    }

    /// Pause playback
    func pause() {
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
        print("🕐 GlobalTimeline: Playback paused at index \(currentIndex)")
    }

    /// Step forward in time (toward newer data)
    func stepForward() {
        guard !availableTimestamps.isEmpty else { return }

        if currentIndex < availableTimestamps.count - 1 {
            currentIndex += 1
            currentTimestamp = availableTimestamps[currentIndex]
            print("🕐 GlobalTimeline: Stepped forward to index \(currentIndex): \(currentTimestamp?.description ?? "nil")")
        } else {
            print("🕐 GlobalTimeline: Already at latest timestamp")
        }
    }

    /// Step backward in time (toward older data)
    func stepBackward() {
        guard !availableTimestamps.isEmpty else { return }

        if currentIndex > 0 {
            currentIndex -= 1
            currentTimestamp = availableTimestamps[currentIndex]
            print("🕐 GlobalTimeline: Stepped backward to index \(currentIndex): \(currentTimestamp?.description ?? "nil")")
        } else {
            print("🕐 GlobalTimeline: Already at oldest timestamp")
        }
    }

    /// Jump to the latest (most recent) timestamp
    func jumpToLatest() {
        guard !availableTimestamps.isEmpty else { return }

        currentIndex = availableTimestamps.count - 1
        currentTimestamp = availableTimestamps[currentIndex]
        print("🕐 GlobalTimeline: Jumped to latest: \(currentTimestamp?.description ?? "nil")")
    }

    /// Jump to the oldest timestamp
    func jumpToOldest() {
        guard !availableTimestamps.isEmpty else { return }

        currentIndex = 0
        currentTimestamp = availableTimestamps[currentIndex]
        print("🕐 GlobalTimeline: Jumped to oldest: \(currentTimestamp?.description ?? "nil")")
    }

    /// Get position info for UI display
    func getPositionInfo() -> String {
        guard !availableTimestamps.isEmpty else {
            return "No data"
        }

        return "\(currentIndex + 1) of \(availableTimestamps.count)"
    }
}
