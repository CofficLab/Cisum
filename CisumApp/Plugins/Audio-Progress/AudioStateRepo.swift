import Foundation
import MagicKit
import OSLog
import SwiftUI

/// 音频播放状态存储库
/// 负责存储和获取音频播放相关的状态，如当前播放URL、播放时间、播放模式等
class AudioStateRepo: SuperLog {
    static let emoji = "🗄️"

    // 存储键名
    private static let keyOfCurrentAudioURL = "AudioPluginCurrentAudioURL"
    private static let keyOfCurrentAudioTime = "AudioPluginCurrentAudioTime"
    private static let keyOfCurrentPlayMode = "AudioPluginCurrentPlayMode"

    // MARK: - 存储方法

    /// 存储播放模式
    /// - Parameter mode: 播放模式的原始值
    static func storePlayMode(_ mode: String) {
        UserDefaults.standard.set(mode, forKey: keyOfCurrentPlayMode)

        // 将模式作为字符串存储到 CloudKit
        NSUbiquitousKeyValueStore.default.set(mode, forKey: keyOfCurrentPlayMode)
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    /// 存储当前播放的音频URL
    /// - Parameters:
    ///   - url: 音频URL
    ///   - verbose: 是否输出详细日志
    static func storeCurrent(_ url: URL?, verbose: Bool = false) {
        if verbose {
            os_log("\(Self.t)🍋🍋🍋 Store current audio URL: \(url?.absoluteString ?? "")")
        }

        UserDefaults.standard.set(url, forKey: keyOfCurrentAudioURL)

        // 将URL作为字符串存储到 CloudKit
        NSUbiquitousKeyValueStore.default.set(url?.absoluteString ?? "", forKey: keyOfCurrentAudioURL)
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    /// 存储当前播放时间
    /// - Parameter time: 播放时间
    static func storeCurrentTime(_ time: TimeInterval) {
        UserDefaults.standard.set(time, forKey: keyOfCurrentAudioTime)

        // 将时间作为字符串存储到 CloudKit
        NSUbiquitousKeyValueStore.default.set(String(time), forKey: keyOfCurrentAudioTime)
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    // MARK: - 获取方法

    /// 获取播放模式
    /// - Returns: 播放模式，如果没有存储则返回nil
    static func getPlayMode() -> PlayMode? {
        // 首先尝试从 UserDefaults 获取模式
        if let mode = UserDefaults.standard.string(forKey: keyOfCurrentPlayMode) {
            return PlayMode(rawValue: mode)
        }

        // 如果在 UserDefaults 中未找到，尝试从 iCloud 获取
        if let modeString = NSUbiquitousKeyValueStore.default.string(forKey: keyOfCurrentPlayMode),
           let mode = PlayMode(rawValue: modeString) {
            return mode
        }

        return nil
    }

    /// 获取当前播放的音频URL
    /// - Returns: 音频URL，如果没有存储则返回nil
    static func getCurrent() -> URL? {
        // 首先尝试从 UserDefaults 获取URL
        if let url = UserDefaults.standard.url(forKey: keyOfCurrentAudioURL) {
            return url
        }

        // 如果在 UserDefaults 中未找到，尝试从 iCloud 获取
        if let urlString = NSUbiquitousKeyValueStore.default.string(forKey: keyOfCurrentAudioURL),
           let url = URL(string: urlString) {
            // 如果在 iCloud 中找到，更新 UserDefaults 以便将来本地访问
            UserDefaults.standard.set(url, forKey: keyOfCurrentAudioURL)
            return url
        }

        return nil
    }

    /// 获取当前播放时间
    /// - Returns: 播放时间，如果没有存储则返回nil
    static func getCurrentTime() -> TimeInterval? {
        // 首先尝试从 UserDefaults 获取时间
        let time = UserDefaults.standard.double(forKey: keyOfCurrentAudioTime)
        if time > 0 { // 因为0是键不存在时的默认值
            return time
        }

        // 如果在 UserDefaults 中未找到，尝试从 iCloud 获取
        if let timeString = NSUbiquitousKeyValueStore.default.string(forKey: keyOfCurrentAudioTime),
           let time = TimeInterval(timeString) {
            // 如果在 iCloud 中找到，更新 UserDefaults 以便将来本地访问
            UserDefaults.standard.set(time, forKey: keyOfCurrentAudioTime)
            return time
        }

        return nil
    }
}

// MARK: - Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}

#Preview("UserDefaults 调试") {
    UserDefaultsDebugView(defaultSearchText: "AudioPlugin")
        .frame(width: 500)
        .frame(height: 600)
}
