import Foundation
import MagicKit
import LumiUI
import OSLog
import SwiftUI

/// 当前书籍的持久化仓库。
///
/// ## 存储契约
///
/// - 本地：`UserDefaults`，键 `com.bookplugin.currentBookURL` / `...Time`
/// - iCloud：`NSUbiquitousKeyValueStore`，**只同步字符串形态**
///   （URL 的 `absoluteString`、时间的十进制字符串）
///
/// 读取语义是**本地优先、iCloud 兜底**；命中 iCloud 时回填本地，
/// 让后续读取不再依赖 iCloud 的可用性。
///
/// ## 为什么可以实例化
///
/// 过去这里是 `static` 方法 + `.standard` / `.default` 硬编码，
/// 导致单元测试只能绕开真实 I/O 路径去测纯函数分支——生产路径本身
/// 从未被 hermetic 覆盖，测试还会读写**开发者真实的偏好与真实 iCloud
/// 键值库**（后者是否可读写取决于设备是否登录 iCloud）。
///
/// 改为实例方法后，生产仍用 ``shared``（真实存储），测试可注入
/// 独立 `UserDefaults` suite 与 ``InMemoryCloudKeyValueStore``。
public class BookSettingRepo: SuperLog {
    public nonisolated static let emoji = "🔊"
    public nonisolated static let verbose = false

    /// 当前书籍URL的存储键
    public static let keyOfCurrentBookURL = "com.bookplugin.currentBookURL"
    /// 当前书籍播放时间的存储键
    public static let keyOfCurrentBookTime = "com.bookplugin.currentBookTime"

    /// 生产共享实例：真实偏好 + 真实 iCloud 键值库。
    public static let shared = BookSettingRepo()

    private let preferences: PreferenceStore

    /// - Parameter preferences: 偏好存储。生产传 ``PreferenceStore/shared``。
    public init(preferences: PreferenceStore = .shared) {
        self.preferences = preferences
    }

    /// 存储当前书籍的URL
    /// - Parameter url: 书籍的URL，如果为nil则清除存储
    public func storeCurrent(_ url: URL?) {
        if Self.verbose {
            os_log("\(Self.t)🍋🍋🍋 存储当前书籍URL: \(url?.shortPath() ?? "")")
        }

        preferences.defaults.set(url, forKey: Self.keyOfCurrentBookURL)

        // 将URL作为字符串存储到iCloud
        preferences.cloud.set(url?.absoluteString, forKey: Self.keyOfCurrentBookURL)
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

    /// 存储当前书籍的播放时间
    /// - Parameter time: 播放时间（秒）
    public func storeCurrentTime(_ time: TimeInterval) {
        let normalizedTime = Self.normalizedTimeForStorage(time)

        if Self.verbose {
            os_log("\(Self.t)🍋🍋🍋 存储当前书籍播放时间: \(normalizedTime)")
        }

        preferences.defaults.set(normalizedTime, forKey: Self.keyOfCurrentBookTime)

        // 将时间作为字符串存储到iCloud
        preferences.cloud.set(String(normalizedTime), forKey: Self.keyOfCurrentBookTime)
        preferences.cloud.synchronize()
    }

    /// 获取当前书籍的URL
    /// - Returns: 当前书籍的URL，如果没有存储则返回nil
    public func getCurrent() -> URL? {
        // 首先尝试从UserDefaults获取URL
        if let url = preferences.defaults.url(forKey: Self.keyOfCurrentBookURL) {
            if Self.verbose {
                os_log("\(Self.t)🍋🍋🍋 获取当前书籍URL: \(url.shortPath())")
            }

            return url
        }

        // 如果在UserDefaults中未找到，尝试从iCloud获取
        if let url = Self.storedURL(from: preferences.cloud.string(forKey: Self.keyOfCurrentBookURL)) {
            // 如果在iCloud中找到，更新UserDefaults以便后续本地访问
            preferences.defaults.set(url, forKey: Self.keyOfCurrentBookURL)
            if Self.verbose {
                os_log("\(Self.t)🍋🍋🍋 从iCloud获取当前书籍URL: \(url.absoluteString)")
            }

            return url
        }

        return nil
    }

    /// 获取当前书籍的播放时间
    /// - Returns: 当前书籍的播放时间（秒），如果没有存储则返回nil
    public func getCurrentTime() -> TimeInterval? {
        let time = Self.storedTime(
            localObject: preferences.defaults.object(forKey: Self.keyOfCurrentBookTime),
            localDouble: preferences.defaults.double(forKey: Self.keyOfCurrentBookTime),
            cloudString: preferences.cloud.string(forKey: Self.keyOfCurrentBookTime)
        )

        if let time {
            // 如果在iCloud中找到，更新UserDefaults以便后续本地访问
            preferences.defaults.set(time, forKey: Self.keyOfCurrentBookTime)
            return time
        }

        return nil
    }
}
