import Foundation
import MagicKit
import OSLog
import SwiftUI

class BookSettingRepo: SuperLog {
    nonisolated static let emoji = "🔊"
    nonisolated static let verbose = false

    /// 当前书籍URL的存储键
    static let keyOfCurrentBookURL = "com.bookplugin.currentBookURL"
    /// 当前书籍播放时间的存储键
    static let keyOfCurrentBookTime = "com.bookplugin.currentBookTime"

    /// 存储当前书籍的URL
    /// - Parameter url: 书籍的URL，如果为nil则清除存储
    static func storeCurrent(_ url: URL?) {
        if Self.verbose {
            os_log("\(Self.t)🍋🍋🍋 存储当前书籍URL: \(url?.shortPath() ?? "")")
        }

        UserDefaults.standard.set(url, forKey: keyOfCurrentBookURL)

        // 将URL作为字符串存储到iCloud
        NSUbiquitousKeyValueStore.default.set(url?.absoluteString ?? "", forKey: keyOfCurrentBookURL)
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    /// 存储当前书籍的播放时间
    /// - Parameter time: 播放时间（秒）
    static func storeCurrentTime(_ time: TimeInterval) {
        if Self.verbose {
            os_log("\(Self.t)🍋🍋🍋 存储当前书籍播放时间: \(time)")
        }

        UserDefaults.standard.set(time, forKey: keyOfCurrentBookTime)

        // 将时间作为字符串存储到iCloud
        NSUbiquitousKeyValueStore.default.set(String(time), forKey: keyOfCurrentBookTime)
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    /// 获取当前书籍的URL
    /// - Returns: 当前书籍的URL，如果没有存储则返回nil
    static func getCurrent() -> URL? {
        // 首先尝试从UserDefaults获取URL
        if let url = UserDefaults.standard.url(forKey: keyOfCurrentBookURL) {
            if Self.verbose {
                os_log("\(Self.t)🍋🍋🍋 获取当前书籍URL: \(url.shortPath())")
            }

            return url
        }

        // 如果在UserDefaults中未找到，尝试从iCloud获取
        if let urlString = NSUbiquitousKeyValueStore.default.string(forKey: keyOfCurrentBookURL),
           let url = URL(string: urlString) {
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
    static func getCurrentTime() -> TimeInterval? {
        // 首先尝试从UserDefaults获取时间
        let time = UserDefaults.standard.double(forKey: keyOfCurrentBookTime)
        if time > 0 { // 0是键不存在时的默认值
            return time
        }

        // 如果在UserDefaults中未找到，尝试从iCloud获取
        if let timeString = NSUbiquitousKeyValueStore.default.string(forKey: keyOfCurrentBookTime),
           let time = TimeInterval(timeString) {
            // 如果在iCloud中找到，更新UserDefaults以便后续本地访问
            UserDefaults.standard.set(time, forKey: keyOfCurrentBookTime)
            return time
        }

        return nil
    }
}

#if os(macOS)
    #Preview("App - Large") {
        ContentView()
    .inRootView()
            .frame(width: 600, height: 1000)
    }

    #Preview("App - Small") {
        ContentView()
    .inRootView()
            .frame(width: 500, height: 800)
    }
#endif

#if os(iOS)
    #Preview("iPhone") {
        ContentView()
    .inRootView()
    }
#endif
