import MagicKit
import Foundation
import ProviderPlayback
import LumiUI
import MagicPlayMan
import OSLog

/// 音乐播放模式的持久化存储。
///
/// ## 存储契约
///
/// - 本地：`UserDefaults`，键 `audioPlayMode`
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
public actor AudioPlayModeStore: SuperLog {

    public static let emoji = "💾"
    public static let verbose = false

    /// 生产共享实例：真实偏好 + 真实 iCloud 键值库。
    public static let shared = AudioPlayModeStore()

    private static let playModeKey = "audioPlayMode"

    private let preferences: PreferenceStore

    /// - Parameter preferences: 偏好存储。生产传 ``PreferenceStore/shared``。
    public init(preferences: PreferenceStore = .shared) {
        self.preferences = preferences
    }

    public func getPlayMode() -> PlaybackMode {
        Self.resolvedPlayMode(
            localRawValue: preferences.defaults.string(forKey: Self.playModeKey),
            cloudRawValue: preferences.cloud.string(forKey: Self.playModeKey)
        )
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
        storePlayModeRawValue(mode.rawValue, shortName: mode.shortName)
    }

    public func storePlayModeRawValue(_ modeString: String, shortName: String) {
        preferences.defaults.set(modeString, forKey: Self.playModeKey)

        preferences.cloud.set(modeString, forKey: Self.playModeKey)
        preferences.cloud.synchronize()

        if Self.verbose {
            os_log("\(self.t)💾 Saved play mode: \(shortName)")
        }
    }

    public func resetToDefault() {
        let defaultMode = PlaybackMode.sequence
        storePlayMode(defaultMode)

        if Self.verbose {
            os_log("\(self.t)🔄 Reset play mode to default: \(defaultMode.shortName)")
        }
    }

    public func getAvailableModes() -> [PlaybackMode] {
        [.sequence, .repeatAll, .loop, .shuffle]
    }

    public func isModeAvailable(_ mode: PlaybackMode) -> Bool {
        getAvailableModes().contains(mode)
    }
}
