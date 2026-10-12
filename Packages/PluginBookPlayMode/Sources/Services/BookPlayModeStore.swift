import MagicKit
import Foundation
import ProviderPlayback
import CisumUIComponents
import LumiUI
import MagicPlayMan
import OSLog

public actor BookPlayModeStore: SuperLog {

    public static let emoji = "💾"
    public static let verbose = false

    public static let shared = BookPlayModeStore()

    private static let playModeKey = "bookPlayMode"

    private init() {}

    public func getPlayMode() -> PlaybackMode {
        let mode = Self.resolvedPlayMode(
            localRawValue: UserDefaults.standard.string(forKey: Self.playModeKey),
            cloudRawValue: NSUbiquitousKeyValueStore.default.string(forKey: Self.playModeKey)
        )
        if Self.verbose { os_log("\(self.t)📖 读取播放模式: \(mode.shortName)") }
        return mode
    }

    static func resolvedPlayMode(localRawValue: String?, cloudRawValue: String?) -> PlaybackMode {
        if let localRawValue, let playMode = PlaybackMode(rawValue: localRawValue) {
            return playMode
        }

        if let cloudRawValue, let playMode = PlaybackMode(rawValue: cloudRawValue) {
            return playMode
        }

        return .sequence
    }

    public func storePlayMode(_ mode: PlaybackMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: Self.playModeKey)
        NSUbiquitousKeyValueStore.default.set(mode.rawValue, forKey: Self.playModeKey)
        NSUbiquitousKeyValueStore.default.synchronize()

        if Self.verbose {
            os_log("\(self.t)💾 Saved audiobook play mode: \(mode.shortName)")
        }
    }
}
