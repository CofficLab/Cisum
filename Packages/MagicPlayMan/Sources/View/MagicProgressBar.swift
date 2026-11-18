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
        VStack(spacing: MagicProgressBarPolicy.timeLabelsSpacing) {
            Slider(
                value: MagicProgressBarPolicy.normalizedTimeBinding(
                    currentTime: $currentTime,
                    duration: duration,
                    onSeek: onSeek
                ),
                in: 0...MagicProgressBarPolicy.sliderUpperBound(forDuration: duration)
            )

            // 已播 / 剩余时长：裸滑杆让人无从得知曲目有多长、还剩多久
            // （有声书尤其需要）。样式与下载进度条的百分比标注一致。
            // 时长未知（无当前曲目）时不显示，避免出现无意义的 0:00 / 0:00。
            if MagicProgressBarPolicy.normalizedDuration(duration) > 0 {
                HStack {
                    Text(MagicProgressBarPolicy.formattedTime(currentTime))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(MagicProgressBarPolicy.formattedTime(remainingTime))
                        .foregroundStyle(.secondary)
                }
                .font(.caption2.monospacedDigit())
                .accessibilityElement(children: .combine)
            }
        }
    }

    /// 距播放结束的剩余时长；时长未知时退化为 0。
    private var remainingTime: TimeInterval {
        max(0, duration - currentTime)
    }
}

enum MagicProgressBarPolicy {
    /// 时间标签行与滑杆的间距。
    static let timeLabelsSpacing: CGFloat = 4

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

    /// 「分:秒」；超过一小时用「时:分:秒」——有声书动辄数小时，
    /// 分钟数破百（「75:33」）远不如「1:15:33」可读。
    static func formattedTime(_ time: TimeInterval) -> String {
        let normalizedTime = time.isFinite ? max(time, 0) : 0
        let maximumDisplaySeconds = Int.max / 2
        let totalSeconds = Int(min(normalizedTime, TimeInterval(maximumDisplaySeconds)))
        let hours = totalSeconds / 3600
        guard hours > 0 else {
            return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
        }
        return String(format: "%d:%02d:%02d", hours, totalSeconds % 3600 / 60, totalSeconds % 60)
    }
}
