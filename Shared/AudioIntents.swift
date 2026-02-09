import AppIntents
import MagicKit
import Foundation
import WidgetKit
import OSLog
import CoreFoundation

/// 发送 Darwin 通知，通知主 App 检查命令
private func notifyMainApp() {
    let center = CFNotificationCenterGetDarwinNotifyCenter()
    let name = CFNotificationName("com.yueyi.cisum.widgetCommand" as CFString)
    CFNotificationCenterPostNotification(center, name, nil, nil, true)
}

public struct PlayPauseIntent: AppIntent, SuperLog {
    nonisolated public static let emoji = "🎵"
    nonisolated static let verbose = false

    public static var title: LocalizedStringResource { "Play/Pause" }
    public static var description: IntentDescription { IntentDescription("Toggles playback state.") }
    public static var openAppWhenRun: Bool { false }

    public init() {}

    public func perform() async throws -> some IntentResult {
        os_log("\(Self.t)播放/暂停意图已执行")

        // 通过 App Groups UserDefaults 触发主 App 操作
        // 系统会自动发送 Darwin 通知给所有使用该 App Group 的进程
        let sharedDefaults = UserDefaults(suiteName: "group.com.yueyi.cisum")
        sharedDefaults?.set(Date().timeIntervalSince1970, forKey: "widgetPlayPauseTrigger")
        sharedDefaults?.synchronize()
        
        // 显式发送 Darwin 通知
        notifyMainApp()

        return .result()
    }
}

public struct NextTrackIntent: AppIntent, SuperLog {
    nonisolated public static let emoji = "🎵"
    nonisolated static let verbose = false

    public static var title: LocalizedStringResource { "Next Track" }
    public static var description: IntentDescription { IntentDescription("Skips to the next track.") }
    public static var openAppWhenRun: Bool { false }

    public init() {}

    public func perform() async throws -> some IntentResult {
        os_log("\(Self.t)下一首意图已执行")

        // 通过 App Groups UserDefaults 触发主 App 操作
        let sharedDefaults = UserDefaults(suiteName: "group.com.yueyi.cisum")
        sharedDefaults?.set(Date().timeIntervalSince1970, forKey: "widgetNextTrigger")
        sharedDefaults?.synchronize()
        
        // 显式发送 Darwin 通知
        notifyMainApp()

        return .result()
    }
}

public struct PreviousTrackIntent: AppIntent, SuperLog {
    nonisolated public static let emoji = "🎵"
    nonisolated static let verbose = false

    public static var title: LocalizedStringResource { "Previous Track" }
    public static var description: IntentDescription { IntentDescription("Goes to the previous track.") }
    public static var openAppWhenRun: Bool { false }

    public init() {}

    public func perform() async throws -> some IntentResult {
        os_log("\(Self.t)上一首意图已执行")

        // 通过 App Groups UserDefaults 触发主 App 操作
        let sharedDefaults = UserDefaults(suiteName: "group.com.yueyi.cisum")
        sharedDefaults?.set(Date().timeIntervalSince1970, forKey: "widgetPreviousTrigger")
        sharedDefaults?.synchronize()
        
        // 显式发送 Darwin 通知
        notifyMainApp()

        return .result()
    }
}
