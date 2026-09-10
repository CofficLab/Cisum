import Foundation
import ProviderBook
import CisumUIComponents
import OSLog
import SwiftUI

public class BookSettingRepo: SuperLog {
    public nonisolated static let emoji = "🔊"
    public nonisolated static let verbose = false

    /// 当前书籍URL的存储键
    public static let keyOfCurrentBookURL = "com.bookplugin.currentBookURL"
    /// 当前书籍播放时间的存储键
    public static let keyOfCurrentBookTime = "com.bookplugin.currentBookTime"

    /// 存储当前书籍的URL
    /// - Parameter url: 书籍的URL，如果为nil则清除存储
    public static func storeCurrent(_ url: URL?) {
        if Self.verbose {
            os_log("\(Self.t)🍋🍋🍋 存储当前书籍URL: \(url?.shortPath() ?? "")")
        }

        UserDefaults.standard.set(url, forKey: keyOfCurrentBookURL)

        // 将URL作为字符串存储到iCloud
        if let url {
            NSUbiquitousKeyValueStore.default.set(url.absoluteString, forKey: keyOfCurrentBookURL)
        } else {
            NSUbiquitousKeyValueStore.default.removeObject(forKey: keyOfCurrentBookURL)
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

    /// 存储当前书籍的播放时间
    /// - Parameter time: 播放时间（秒）
    public static func storeCurrentTime(_ time: TimeInterval) {
        let normalizedTime = normalizedTimeForStorage(time)

        if Self.verbose {
            os_log("\(Self.t)🍋🍋🍋 存储当前书籍播放时间: \(normalizedTime)")
        }

        UserDefaults.standard.set(normalizedTime, forKey: keyOfCurrentBookTime)

        // 将时间作为字符串存储到iCloud
        NSUbiquitousKeyValueStore.default.set(String(normalizedTime), forKey: keyOfCurrentBookTime)
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    /// 获取当前书籍的URL
    /// - Returns: 当前书籍的URL，如果没有存储则返回nil
    public static func getCurrent() -> URL? {
        // 首先尝试从UserDefaults获取URL
        if let url = UserDefaults.standard.url(forKey: keyOfCurrentBookURL) {
            if Self.verbose {
                os_log("\(Self.t)🍋🍋🍋 获取当前书籍URL: \(url.shortPath())")
            }

            return url
        }

        // 如果在UserDefaults中未找到，尝试从iCloud获取
        if let url = storedURL(from: NSUbiquitousKeyValueStore.default.string(forKey: keyOfCurrentBookURL)) {
            // 如果在iCloud中找到，更新UserDefaults以便后续本地访问
            UserDefaults.standard.set(url, forKey: keyOfCurrentBookURL)
            if Self.verbose {
                os_log("\(Self.t)🍋🍋🍋 从iCloud获取当前书籍URL: \(url.absoluteString)")
            }

            return url
        }

        return nil
    }

    /// 获取当前书籍的播放时间
    /// - Returns: 当前书籍的播放时间（秒），如果没有存储则返回nil
    public static func getCurrentTime() -> TimeInterval? {
        let time = storedTime(
            localObject: UserDefaults.standard.object(forKey: keyOfCurrentBookTime),
            localDouble: UserDefaults.standard.double(forKey: keyOfCurrentBookTime),
            cloudString: NSUbiquitousKeyValueStore.default.string(forKey: keyOfCurrentBookTime)
        )

        if let time {
            // 如果在iCloud中找到，更新UserDefaults以便后续本地访问
            UserDefaults.standard.set(time, forKey: keyOfCurrentBookTime)
            return time
        }

        return nil
    }
}
