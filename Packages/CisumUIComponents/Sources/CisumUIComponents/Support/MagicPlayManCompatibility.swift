import Foundation
import Combine
import MagicKit
import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
    import AppKit
    public typealias MagicPlatformImage = NSImage
#elseif os(iOS)
    import UIKit
    public typealias MagicPlatformImage = UIImage
#endif

public extension View {
    func magicSize(_ size: CGFloat) -> some View {
        frame(width: size, height: size)
    }

    func magicSize(_ size: CGSize) -> some View {
        frame(width: size.width, height: size.height)
    }

    func magicBackground(_ color: Color) -> some View {
        background(color)
    }

    func magicCentered() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    func infinite() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func inButtonWithAction(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            self
        }
        .buttonStyle(.borderless)
    }

}

public extension String {
    static let iconBackwardEndFill = "backward.end.fill"
    static let iconForwardEndFill = "forward.end.fill"
    static let iconGobackward10 = "gobackward.10"
    static let iconGoforward10 = "goforward.10"
    static let iconMusicNoteList = "music.note.list"
    static let iconPauseFill = "pause.fill"
    static let iconPersonGroup = "person.3"
    static let iconPersonGroupSlash = "person.3.sequence"
    static let iconPlay = "play"
    static let iconPlayFill = "play.fill"
    static let iconRepeat1 = "repeat.1"
    static let iconShuffle = "shuffle"
    static let iconRepeatAll = "repeat"
}

public extension LinearGradient {
    static var aurora: LinearGradient {
        LinearGradient(
            colors: [.green.opacity(0.35), .cyan.opacity(0.25), .purple.opacity(0.35)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var winter: LinearGradient {
        LinearGradient(
            colors: [.blue.opacity(0.16), .mint.opacity(0.12), .white.opacity(0.08)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

public struct MagicThumbnailResult {
    public let image: MagicPlatformImage?

    public init(image: MagicPlatformImage? = nil) {
        self.image = image
    }

    public func toSwiftUIImage() -> Image? {
        guard let image else { return nil }
        #if os(macOS)
            return Image(nsImage: image)
        #elseif os(iOS)
            return Image(uiImage: image)
        #else
            return nil
        #endif
    }
}

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

        guard duration > 0 else {
            return 0
        }

        return min(lowerBoundedTime, duration)
    }

    static func normalizedProgress(currentTime: TimeInterval, duration: TimeInterval) -> Double {
        let duration = normalizedDuration(duration)
        guard duration > 0 else { return 0 }
        return normalizedTime(currentTime, duration: duration) / duration
    }

    static func seekTime(locationX: CGFloat, trackWidth: CGFloat, duration: TimeInterval) -> TimeInterval {
        let duration = normalizedDuration(duration)
        guard duration > 0, locationX.isFinite, trackWidth.isFinite, trackWidth > 0 else {
            return 0
        }

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
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
