import AppIntents
import Foundation
import WidgetKit
import OSLog
import CoreFoundation
import Darwin

/// 发送 Darwin 通知，通知主 App 检查命令
private func notifyMainApp() {
    let center = CFNotificationCenterGetDarwinNotifyCenter()
    let name = CFNotificationName("com.yueyi.cisum.widgetCommand" as CFString)
    CFNotificationCenterPostNotification(center, name, nil, nil, true)
}

private func withWidgetCommandLock<T>(_ operation: () throws -> T) rethrows -> T {
    let suiteName = "group.com.yueyi.cisum"
    guard let lockURL = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: suiteName)?
        .appendingPathComponent("widget-command.lock") else {
        return try operation()
    }

    FileManager.default.createFile(atPath: lockURL.path, contents: nil)
    guard let handle = try? FileHandle(forWritingTo: lockURL) else {
        return try operation()
    }

    flock(handle.fileDescriptor, LOCK_EX)
    defer {
        flock(handle.fileDescriptor, LOCK_UN)
        try? handle.close()
    }

    return try operation()
}

private func incrementWidgetCommand(_ key: String) {
    withWidgetCommandLock {
        let sharedDefaults = UserDefaults(suiteName: "group.com.yueyi.cisum")
        let currentCount = sharedDefaults?.integer(forKey: key) ?? 0
        sharedDefaults?.set(currentCount + 1, forKey: key)
        sharedDefaults?.synchronize()
    }
}

public struct PlayPauseIntent: AppIntent {
    nonisolated public static let emoji = "🎵"
    nonisolated static let verbose = false

    public static var title: LocalizedStringResource { "Play/Pause" }
    public static var description: IntentDescription { IntentDescription("Toggles playback state.") }
    public static var openAppWhenRun: Bool { false }

    public init() {}

    public func perform() async throws -> some IntentResult {
        os_log("[CisumWidget] Play/Pause intent performed")

        // 通过 App Groups UserDefaults 触发主 App 操作。
        incrementWidgetCommand("widgetPlayPauseTrigger")
        
        // 显式发送 Darwin 通知
        notifyMainApp()

        return .result()
    }
}

public struct NextTrackIntent: AppIntent {
    nonisolated public static let emoji = "🎵"
    nonisolated static let verbose = false

    public static var title: LocalizedStringResource { "Next Track" }
    public static var description: IntentDescription { IntentDescription("Skips to the next track.") }
    public static var openAppWhenRun: Bool { false }

    public init() {}

    public func perform() async throws -> some IntentResult {
        os_log("[CisumWidget] Next Track intent performed")

        // 通过 App Groups UserDefaults 触发主 App 操作。
        incrementWidgetCommand("widgetNextTrigger")
        
        // 显式发送 Darwin 通知
        notifyMainApp()

        return .result()
    }
}

public struct PreviousTrackIntent: AppIntent {
    nonisolated public static let emoji = "🎵"
    nonisolated static let verbose = false

    public static var title: LocalizedStringResource { "Previous Track" }
    public static var description: IntentDescription { IntentDescription("Goes to the previous track.") }
    public static var openAppWhenRun: Bool { false }

    public init() {}

    public func perform() async throws -> some IntentResult {
        os_log("[CisumWidget] Previous Track intent performed")

        // 通过 App Groups UserDefaults 触发主 App 操作。
        incrementWidgetCommand("widgetPreviousTrigger")
        
        // 显式发送 Darwin 通知
        notifyMainApp()

        return .result()
    }
}
