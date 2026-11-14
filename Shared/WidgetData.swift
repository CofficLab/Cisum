import Foundation
import OSLog
import SwiftUI
import WidgetKit

struct WidgetData: Codable {
    static let suiteName = "group.com.yueyi.cisum"
    static let emoji = "🐶"
    static let verbose = false

    var title: String
    var artist: String
    var isPlaying: Bool
    var coverArtData: Data?

    static let empty = WidgetData(title: "Not Playing", artist: "Cisum", isPlaying: false, coverArtData: nil)

    struct Keys {
        static let data = "widgetData"
    }

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    static func save(title: String, artist: String, isPlaying: Bool, coverArt: Data?) {
        let data = WidgetData(title: title, artist: artist, isPlaying: isPlaying, coverArtData: coverArt)
        if let encoded = try? JSONEncoder().encode(data) {
            sharedDefaults?.set(encoded, forKey: Keys.data)
            if Self.verbose {
                os_log("[CisumWidget] 💾 Saved widget data to \(suiteName): \(title) - \(artist) (playing: \(isPlaying))")
            }
            reloadWidgetTimelines()
        } else {
            os_log(.error, "[CisumWidget] Failed to encode widget data")
        }
    }

    /// 通知系统刷新小组件时间线。
    ///
    /// WidgetKit 在 visionOS 上直到 26.0 才可用，而 Cisum 的 visionOS 部署
    /// 目标是 2.0：此时 `WidgetCenter` 这个类型本身都不可用。因此这里用
    /// 可用性检查把调用挡在 visionOS 2.x 之外——数据本身仍会写入 App Group，
    /// 等 visionOS 支持小组件后无需改动即可生效。
    private static func reloadWidgetTimelines() {
        #if os(visionOS)
        if #available(visionOS 26.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }
        #else
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    static func load() -> WidgetData {
        guard let data = sharedDefaults?.data(forKey: Keys.data),
              let decoded = try? JSONDecoder().decode(WidgetData.self, from: data) else {
            if Self.verbose {
                os_log("[CisumWidget] Failed to load widget data from \(suiteName); returning empty data")
            }
            return .empty
        }
        if Self.verbose {
            os_log("[CisumWidget] Loaded widget data: \(decoded.title) - \(decoded.artist)")
        }
        return decoded
    }
}

extension Notification.Name {
    static let widgetPlayPause = Notification.Name("widgetPlayPause")
    static let widgetNext = Notification.Name("widgetNext")
    static let widgetPrevious = Notification.Name("widgetPrevious")
}
