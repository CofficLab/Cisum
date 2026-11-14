import Foundation

public enum AudioProgressHost {
    public typealias SaveWidgetData = @Sendable (String, String, Bool, Data?) -> Void

    private nonisolated(unsafe) static var saveWidgetDataHandler: SaveWidgetData = { _, _, _, _ in }

    public static func configure(saveWidgetData: @escaping SaveWidgetData) {
        saveWidgetDataHandler = saveWidgetData
    }

    public static func saveWidgetData(title: String, artist: String, isPlaying: Bool, coverArt: Data?) {
        saveWidgetDataHandler(title, artist, isPlaying, coverArt)
    }
}
