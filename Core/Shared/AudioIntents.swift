import AppIntents
import Foundation
import WidgetKit
import OSLog

private let logger = Logger(subsystem: "com.yueyi.cisum", category: "AudioIntents")

struct PlayPauseIntent: AppIntent {
    static var title: LocalizedStringResource { "Play/Pause" }
    static var description: IntentDescription { IntentDescription("Toggles playback state.") }
    static var openAppWhenRun: Bool { false }
    
    init() {}

    func perform() async throws -> some IntentResult {
        logger.info("PlayPauseIntent performed")
        NotificationCenter.default.post(name: .widgetPlayPause, object: nil)
        return .result()
    }
}

struct NextTrackIntent: AppIntent {
    static var title: LocalizedStringResource { "Next Track" }
    static var description: IntentDescription { IntentDescription("Skips to the next track.") }
    static var openAppWhenRun: Bool { false }
    
    init() {}

    func perform() async throws -> some IntentResult {
        logger.info("NextTrackIntent performed")
        NotificationCenter.default.post(name: .widgetNext, object: nil)
        return .result()
    }
}

struct PreviousTrackIntent: AppIntent {
    static var title: LocalizedStringResource { "Previous Track" }
    static var description: IntentDescription { IntentDescription("Skips to the previous track.") }
    static var openAppWhenRun: Bool { false }
    
    init() {}

    func perform() async throws -> some IntentResult {
        logger.info("PreviousTrackIntent performed")
        NotificationCenter.default.post(name: .widgetPrevious, object: nil)
        return .result()
    }
}
