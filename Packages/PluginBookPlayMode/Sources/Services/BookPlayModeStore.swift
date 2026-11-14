import MagicKit
import Foundation
import ProviderPlayback
import LumiUI
import MagicPlayMan
import OSLog

/// 有声书播放模式的持久化存储。
///
/// ## 存储契约
///
/// - 本地：`UserDefaults`，键 `bookPlayMode`
/// - iCloud：`NSUbiquitousKeyValueStore`（只同步字符串形态）
///
/// 读取语义为**本地优先、iCloud 兜底**；两者都缺失时回退到 `.sequence`。
///
/// ## 为什么可以注入偏好存储
///
/// 过去这里硬编码 `UserDefaults.standard` 与 `NSUbiquitousKeyValueStore.default`，
/// 单元测试无法替换，只能靠 `resolvedPlayMode(localRawValue:cloudRawValue:)`
/// 这个纯函数旁路覆盖分支——真实的读写路径从未被 hermetic 地测到，
/// 测试还会读写开发者真实的偏好与真实 iCloud 键值库。
public actor BookPlayModeStore: SuperLog {

    public static let emoji = "💾"
    public static let verbose = false

    /// 生产共享实例：真实偏好 + 真实 iCloud 键值库。
    public static let shared = BookPlayModeStore()

    private static let playModeKey = "bookPlayMode"

    private let preferences: PreferenceStore

    /// - Parameter preferences: 偏好存储。生产传 ``PreferenceStore/shared``。
    public init(preferences: PreferenceStore = .shared) {
        self.preferences = preferences
    }

    public func getPlayMode() -> PlaybackMode {
        let mode = Self.resolvedPlayMode(
            localRawValue: preferences.defaults.string(forKey: Self.playModeKey),
            cloudRawValue: preferences.cloud.string(forKey: Self.playModeKey)
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
        preferences.defaults.set(mode.rawValue, forKey: Self.playModeKey)
        preferences.cloud.set(mode.rawValue, forKey: Self.playModeKey)
        preferences.cloud.synchronize()

        if Self.verbose {
            os_log("\(self.t)💾 Saved audiobook play mode: \(mode.shortName)")
        }
    }
}
