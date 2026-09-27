import MagicKit
import Foundation
import ProviderPlayback
import CisumUIComponents
import LumiUI
import MagicPlayMan
import OSLog
import SwiftUI

/// 音频播放状态存储库
/// 负责存储和获取音频播放相关的状态，如当前播放URL、播放时间、播放模式等
public class AudioStateRepo: SuperLog {
    public static let emoji = "🗄️"

    // 存储键名
    private static let keyOfCurrentAudioURL = "AudioPluginCurrentAudioURL"
    private static let keyOfCurrentAudioTime = "AudioPluginCurrentAudioTime"
    private static let keyOfCurrentPlayMode = "AudioPluginCurrentPlayMode"

    // MARK: - 存储方法

    /// 存储播放模式
    /// - Parameter mode: 播放模式的原始值
    public static func storePlayMode(_ mode: String) {
        UserDefaults.standard.set(mode, forKey: keyOfCurrentPlayMode)

        // 将模式作为字符串存储到 CloudKit
        NSUbiquitousKeyValueStore.default.set(mode, forKey: keyOfCurrentPlayMode)
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    /// 存储当前播放的音频URL
    /// - Parameters:
    ///   - url: 音频URL
    ///   - verbose: 是否输出详细日志
    public static func storeCurrent(_ url: URL?, verbose: Bool = false) {
        if verbose {
            os_log("\(Self.t)🍋🍋🍋 Store current audio URL: \(url?.absoluteString ?? "")")
        }

        UserDefaults.standard.set(url, forKey: keyOfCurrentAudioURL)

        // 将URL作为字符串存储到 CloudKit
        if let url {
            NSUbiquitousKeyValueStore.default.set(url.absoluteString, forKey: keyOfCurrentAudioURL)
        } else {
            NSUbiquitousKeyValueStore.default.removeObject(forKey: keyOfCurrentAudioURL)
        }
        NSUbiquitousKeyValueStore.default.synchronize()
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
    public static func storeCurrentTime(_ time: TimeInterval) {
        let normalizedTime = normalizedTimeForStorage(time)

        UserDefaults.standard.set(normalizedTime, forKey: keyOfCurrentAudioTime)

        // 将时间作为字符串存储到 CloudKit
        NSUbiquitousKeyValueStore.default.set(String(normalizedTime), forKey: keyOfCurrentAudioTime)
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    // MARK: - 获取方法

    /// 获取播放模式
    /// - Returns: 播放模式，如果没有存储则返回nil
    public static func getPlayMode() -> PlaybackMode? {
        resolvedPlayMode(
            localRawValue: UserDefaults.standard.string(forKey: keyOfCurrentPlayMode),
            cloudRawValue: NSUbiquitousKeyValueStore.default.string(forKey: keyOfCurrentPlayMode)
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
    public static func getCurrent() -> URL? {
        // 首先尝试从 UserDefaults 获取URL
        if let url = UserDefaults.standard.url(forKey: keyOfCurrentAudioURL) {
            return url
        }

        // 如果在 UserDefaults 中未找到，尝试从 iCloud 获取
        if let url = storedURL(from: NSUbiquitousKeyValueStore.default.string(forKey: keyOfCurrentAudioURL)) {
            // 如果在 iCloud 中找到，更新 UserDefaults 以便将来本地访问
            UserDefaults.standard.set(url, forKey: keyOfCurrentAudioURL)
            return url
        }

        return nil
    }

    /// 获取当前播放时间
    /// - Returns: 播放时间，如果没有存储则返回nil
    public static func getCurrentTime() -> TimeInterval? {
        let time = storedTime(
            localObject: UserDefaults.standard.object(forKey: keyOfCurrentAudioTime),
            localDouble: UserDefaults.standard.double(forKey: keyOfCurrentAudioTime),
            cloudString: NSUbiquitousKeyValueStore.default.string(forKey: keyOfCurrentAudioTime)
        )

        if let time {
            // 如果在 iCloud 中找到，更新 UserDefaults 以便将来本地访问
            UserDefaults.standard.set(time, forKey: keyOfCurrentAudioTime)
            return time
        }

        return nil
    }
}
