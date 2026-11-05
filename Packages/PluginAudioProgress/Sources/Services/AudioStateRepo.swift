import MagicKit
import Foundation
import ProviderPlayback
import LumiUI
import MagicPlayMan
import OSLog
import SwiftUI

/// 音频播放状态存储库
/// 负责存储和获取音频播放相关的状态，如当前播放URL、播放时间、播放模式等
///
/// ## 存储契约
///
/// - 本地：`UserDefaults`
/// - iCloud：`NSUbiquitousKeyValueStore`（只同步字符串形态）
///
/// 读取语义为**本地优先、iCloud 兜底**。
///
/// ## 为什么可以实例化
///
/// 过去这里是 `static` 方法 + `.standard` / `.default` 硬编码，单元测试
/// 只能绕开真实 I/O 路径去测纯函数分支——生产路径从未被 hermetic 覆盖，
/// 测试还会读写开发者真实的偏好与真实 iCloud 键值库（后者是否可读写
/// 取决于设备是否登录 iCloud）。改为实例方法后，生产仍用 ``shared``，
/// 测试可注入独立 suite 与内存版 iCloud 存储。
public final class AudioStateRepo: SuperLog, @unchecked Sendable {
    public static let emoji = "🗄️"

    // 存储键名
    private static let keyOfCurrentAudioURL = "AudioPluginCurrentAudioURL"
    private static let keyOfCurrentAudioTime = "AudioPluginCurrentAudioTime"
    private static let keyOfCurrentPlayMode = "AudioPluginCurrentPlayMode"

    /// 生产共享实例：真实偏好 + 真实 iCloud 键值库。
    public static let shared = AudioStateRepo()

    private let preferences: PreferenceStore

    /// - Parameter preferences: 偏好存储。生产传 ``PreferenceStore/shared``。
    public init(preferences: PreferenceStore = .shared) {
        self.preferences = preferences
    }

    // MARK: - 存储方法

    /// 存储播放模式
    /// - Parameter mode: 播放模式的原始值
    public func storePlayMode(_ mode: String) {
        preferences.defaults.set(mode, forKey: Self.keyOfCurrentPlayMode)

        // 将模式作为字符串存储到 CloudKit
        preferences.cloud.set(mode, forKey: Self.keyOfCurrentPlayMode)
        preferences.cloud.synchronize()
    }

    /// 存储当前播放的音频URL
    /// - Parameters:
    ///   - url: 音频URL
    ///   - verbose: 是否输出详细日志
    public func storeCurrent(_ url: URL?, verbose: Bool = false) {
        if verbose {
            os_log("\(Self.t)🍋🍋🍋 Store current audio URL: \(url?.absoluteString ?? "")")
        }

        preferences.defaults.set(url, forKey: Self.keyOfCurrentAudioURL)

        // 将URL作为字符串存储到 CloudKit
        preferences.cloud.set(url?.absoluteString, forKey: Self.keyOfCurrentAudioURL)
        preferences.cloud.synchronize()
    }

    static func storedURL(from string: String?) -> URL? {
        guard let string else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }

        guard trimmed.hasPrefix("/") else { return nil }
        return URL(fileURLWithPath: trimmed)
    }

    static func storedTime(
        localObject: Any?,
        localDouble: TimeInterval,
        cloudString: String?
    ) -> TimeInterval? {
        if localObject != nil, let time = validStoredTime(localDouble) {
            return time
        }

        guard let cloudString, let time = TimeInterval(cloudString) else { return nil }
        return validStoredTime(time)
    }

    private static func validStoredTime(_ time: TimeInterval) -> TimeInterval? {
        guard time.isFinite, time >= 0 else { return nil }
        return time
    }

    static func normalizedTimeForStorage(_ time: TimeInterval) -> TimeInterval {
        guard time.isFinite, time > 0 else { return 0 }
        return time
    }

    /// 存储当前播放时间
    /// - Parameter time: 播放时间
    public func storeCurrentTime(_ time: TimeInterval) {
        let normalizedTime = Self.normalizedTimeForStorage(time)

        preferences.defaults.set(normalizedTime, forKey: Self.keyOfCurrentAudioTime)

        // 将时间作为字符串存储到 CloudKit
        preferences.cloud.set(String(normalizedTime), forKey: Self.keyOfCurrentAudioTime)
        preferences.cloud.synchronize()
    }

    // MARK: - 获取方法

    /// 获取播放模式
    /// - Returns: 播放模式，如果没有存储则返回nil
    public func getPlayMode() -> PlaybackMode? {
        Self.resolvedPlayMode(
            localRawValue: preferences.defaults.string(forKey: Self.keyOfCurrentPlayMode),
            cloudRawValue: preferences.cloud.string(forKey: Self.keyOfCurrentPlayMode)
        )
    }

    static func resolvedPlayMode(localRawValue: String?, cloudRawValue: String?) -> PlaybackMode? {
        if let localRawValue, let mode = PlaybackMode(rawValue: localRawValue) {
            return mode
        }

        if let cloudRawValue, let mode = PlaybackMode(rawValue: cloudRawValue) {
            return mode
        }

        return nil
    }

    /// 获取当前播放的音频URL
    /// - Returns: 音频URL，如果没有存储则返回nil
    public func getCurrent() -> URL? {
        // 首先尝试从 UserDefaults 获取URL
        if let url = preferences.defaults.url(forKey: Self.keyOfCurrentAudioURL) {
            return url
        }

        // 如果在 UserDefaults 中未找到，尝试从 iCloud 获取
        if let url = Self.storedURL(from: preferences.cloud.string(forKey: Self.keyOfCurrentAudioURL)) {
            // 如果在 iCloud 中找到，更新 UserDefaults 以便将来本地访问
            preferences.defaults.set(url, forKey: Self.keyOfCurrentAudioURL)
            return url
        }

        return nil
    }

    /// 获取当前播放时间
    /// - Returns: 播放时间，如果没有存储则返回nil
    public func getCurrentTime() -> TimeInterval? {
        let time = Self.storedTime(
            localObject: preferences.defaults.object(forKey: Self.keyOfCurrentAudioTime),
            localDouble: preferences.defaults.double(forKey: Self.keyOfCurrentAudioTime),
            cloudString: preferences.cloud.string(forKey: Self.keyOfCurrentAudioTime)
        )

        if let time {
            // 如果在 iCloud 中找到，更新 UserDefaults 以便将来本地访问
            preferences.defaults.set(time, forKey: Self.keyOfCurrentAudioTime)
            return time
        }

        return nil
    }
}
