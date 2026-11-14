import Foundation

public enum BookProgressPluginInfo {
    public static let title = String(localized: "Book Progress", bundle: .module)
    public static let description = String(localized: "Save and restore book playback progress", bundle: .module)
    public static let iconName = "book.closed"
    public static let emoji = "📖"
    public static let order = 5
}
