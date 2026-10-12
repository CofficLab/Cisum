import SwiftUI

/// Playback progress control shared by the playback kit and playback plugins.
public struct MagicProgressBar: View {
    @Binding private var currentTime: TimeInterval
    private let duration: TimeInterval
    private let onSeek: (TimeInterval) -> Void

    public init(
        currentTime: Binding<TimeInterval>,
        duration: TimeInterval,
        onSeek: @escaping (TimeInterval) -> Void
    ) {
        self._currentTime = currentTime
        self.duration = duration
        self.onSeek = onSeek
    }

    public var body: some View {
        Slider(
            value: MagicProgressBarPolicy.normalizedTimeBinding(
                currentTime: $currentTime,
                duration: duration,
                onSeek: onSeek
            ),
            in: 0...MagicProgressBarPolicy.sliderUpperBound(forDuration: duration)
        )
    }
}

enum MagicProgressBarPolicy {
    static func normalizedTimeBinding(
        currentTime: Binding<TimeInterval>,
        duration: TimeInterval,
        onSeek: @escaping (TimeInterval) -> Void
    ) -> Binding<TimeInterval> {
        Binding(
            get: { normalizedTime(currentTime.wrappedValue, duration: duration) },
            set: { value in
                let normalizedValue = normalizedTime(value, duration: duration)
                currentTime.wrappedValue = normalizedValue
                onSeek(normalizedValue)
            }
        )
    }

    static func normalizedDuration(_ duration: TimeInterval) -> TimeInterval {
        guard duration.isFinite, duration > 0 else { return 0 }
        return duration
    }

    static func normalizedTime(_ time: TimeInterval, duration: TimeInterval) -> TimeInterval {
        guard time.isFinite else { return 0 }

        let lowerBoundedTime = max(time, 0)
        let duration = normalizedDuration(duration)
        guard duration > 0 else { return 0 }
        return min(lowerBoundedTime, duration)
    }

    static func normalizedProgress(currentTime: TimeInterval, duration: TimeInterval) -> Double {
        let duration = normalizedDuration(duration)
        guard duration > 0 else { return 0 }
        return normalizedTime(currentTime, duration: duration) / duration
    }

    static func seekTime(locationX: CGFloat, trackWidth: CGFloat, duration: TimeInterval) -> TimeInterval {
        let duration = normalizedDuration(duration)
        guard duration > 0, locationX.isFinite, trackWidth.isFinite, trackWidth > 0 else { return 0 }

        let ratio = min(max(Double(locationX / trackWidth), 0), 1)
        return ratio * duration
    }

    static func sliderUpperBound(forDuration duration: TimeInterval) -> TimeInterval {
        max(normalizedDuration(duration), 1)
    }

    static func formattedTime(_ time: TimeInterval) -> String {
        let normalizedTime = time.isFinite ? max(time, 0) : 0
        let maximumDisplaySeconds = Int.max / 2
        let totalSeconds = Int(min(normalizedTime, TimeInterval(maximumDisplaySeconds)))
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}
