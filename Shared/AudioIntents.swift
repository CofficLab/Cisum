import AppIntents
import MagicKit
import Foundation
import WidgetKit
import OSLog

struct PlayPauseIntent: AppIntent, SuperLog {
    nonisolated static let emoji = "🎵"
    nonisolated static let verbose = false
    
    static var title: LocalizedStringResource { "Play/Pause" }
    static var description: IntentDescription { IntentDescription("Toggles playback state.") }
    static var openAppWhenRun: Bool { false }
    
    init() {}

    func perform() async throws -> some IntentResult {
        os_log("\(Self.t)PlayPauseIntent performed")
        NotificationCenter.default.post(name: .widgetPlayPause, object: nil)
        return .result()
    }
}

struct NextTrackIntent: AppIntent, SuperLog {
    nonisolated static let emoji = "🎵"
    nonisolated static let verbose = false
    
    static var title: LocalizedStringResource { "Next Track" }
    static var description: IntentDescription { IntentDescription("Skips to the next track.") }
    static var openAppWhenRun: Bool { false }
    
    init() {}

    func perform() async throws -> some IntentResult {
        os_log("\(Self.t)NextTrackIntent performed")
        NotificationCenter.default.post(name: .widgetNext, object: nil)
        return .result()
    }
}

struct PreviousTrackIntent: AppIntent, SuperLog {
    nonisolated static let emoji = "🎵"
    nonisolated static let verbose = false
    
    static var title: LocalizedStringResource { "Previous Track" }
    static var description: IntentDescription { IntentDescription("Skips to the previous track.") }
    static var openAppWhenRun: Bool { false }
    
    init() {}

    func perform() async throws -> some IntentResult {
        os_log("\(Self.t)PreviousTrackIntent performed")
        NotificationCenter.default.post(name: .widgetPrevious, object: nil)
        return .result()
    }
}
