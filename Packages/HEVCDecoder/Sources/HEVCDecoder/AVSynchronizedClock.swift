#if os(iOS)
import Foundation
import QuartzCore
import os

/// Master clock for HEVCPlayer.
///
/// Uses CACurrentMediaTime() as the time base (which is monotonic and stable across
/// the app lifetime). When audio is playing, the clock is anchored to the audio
/// render time; video frames are scheduled at PTS offsets from this anchor.
@MainActor
public final class AVSynchronizedClock {

    private let log = Logger(subsystem: "com.coffic.cisum", category: "sync.clock")

    /// Anchor: hostTime (seconds) of playback start.
    private var anchorHostTime: Double?
    /// Corresponding media PTS (seconds) at anchor.
    private var anchorMediaTime: Double?

    /// Whether the clock has been started.
    public var isRunning: Bool { anchorHostTime != nil }

    /// Start the clock at a media PTS.
    public func start(atMediaTime mediaTime: Double = 0) {
        anchorHostTime = CACurrentMediaTime()
        anchorMediaTime = mediaTime
        if Self.verbose {
            log.info("clock started at host=\(self.anchorHostTime ?? 0) media=\(mediaTime, format: .fixed(precision: 3))")
        }
    }

    /// Reset the clock.
    public func reset() {
        anchorHostTime = nil
        anchorMediaTime = nil
    }

    /// Update the clock to a new media PTS (e.g. after a seek).
    public func setMediaTime(_ seconds: Double) {
        anchorHostTime = CACurrentMediaTime()
        anchorMediaTime = seconds
    }

    /// Current media playback time in seconds, derived from CACurrentMediaTime() anchor.
    public var currentMediaTime: Double {
        guard let anchor = anchorHostTime, let media = anchorMediaTime else { return 0 }
        let now = CACurrentMediaTime()
        return media + (now - anchor)
    }

    /// Convert a media PTS to an expected hostTime when it should be displayed.
    /// Used by HEVCPlayer to schedule video frame presentation in lockstep with audio.
    public func hostTime(forMediaTime mediaTime: Double) -> Double {
        guard let anchor = anchorHostTime, let media = anchorMediaTime else { return 0 }
        return anchor + (mediaTime - media)
    }

    /// Pause offset: shift the anchor forward so currentMediaTime stops advancing.
    /// Used when audio playback pauses — video frames freeze too.
    public func pauseAnchor(toMediaTime mediaTime: Double) {
        anchorHostTime = CACurrentMediaTime()
        anchorMediaTime = mediaTime
    }

    private static var verbose: Bool { false }
}
#endif
