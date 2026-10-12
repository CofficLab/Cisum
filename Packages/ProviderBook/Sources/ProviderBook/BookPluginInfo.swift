public enum BookPluginInfo {
    public static let keyOfCurrentBookURL = "com.bookplugin.currentBookURL"
    public static let keyOfCurrentBookTime = "com.bookplugin.currentBookTime"
    public static let emoji = "🎺"
    public static let title = String(localized: "Audiobook", bundle: .module)
    public static let description = String(localized: "Audiobook playback", bundle: .module)
    public static let iconName = "book"
    public static let dirName = "audios_book"
    public static let supportedExtensions = [
        "mp3",
        "m4a",
        "m4b",
        "aac",
        "wav",
        "aiff",
        "flac",
        "ogg",
        "opus",
        "alac",
    ]
}
