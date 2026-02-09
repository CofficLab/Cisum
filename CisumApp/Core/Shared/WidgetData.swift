import Foundation
import SwiftUI
import WidgetKit
import OSLog

struct WidgetData: Codable {
    static let suiteName = "group.com.yueyi.cisum"
    private static let logger = Logger(subsystem: "com.yueyi.cisum", category: "WidgetData")
    
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
            logger.info("Saved widget data to \(suiteName): \(title) - \(artist) (Playing: \(isPlaying))")
            WidgetCenter.shared.reloadAllTimelines()
        } else {
            logger.error("Failed to encode widget data")
        }
    }
    
    static func load() -> WidgetData {
        guard let data = sharedDefaults?.data(forKey: Keys.data),
              let decoded = try? JSONDecoder().decode(WidgetData.self, from: data) else {
            logger.warning("Failed to load widget data from \(suiteName), returning empty")
            return .empty
        }
        logger.info("Loaded widget data: \(decoded.title) - \(decoded.artist)")
        return decoded
    }
}

extension Notification.Name {
    static let widgetPlayPause = Notification.Name("widgetPlayPause")
    static let widgetNext = Notification.Name("widgetNext")
    static let widgetPrevious = Notification.Name("widgetPrevious")
}
