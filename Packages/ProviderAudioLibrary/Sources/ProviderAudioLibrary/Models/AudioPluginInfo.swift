public enum AudioPluginInfo {
    public static let titleKey = "Music"
    public static let descriptionKey = "Audio playback"
    public static let maxAudioCount = 100
    public static let dbDirName = "audios"
    public static let debugDBDirName = "audios_debug"
    public static let supportedExtensions = [
        "mp3",
        "m4a",
        "aac",
        "aiff",
        "flac",
        "wav",
        "ogg",
        "opus",
        "alac",
    ]

    /// 当前构建生效的仓库子目录名（Release 为 `audios`，DEBUG 为 `audios_debug`）。
    /// 仓库路径的知情者（AudioPlugin / 音频仓库插件）统一引用此值，避免各包各自判断。
    public static var effectiveDBDirName: String {
        #if DEBUG
            debugDBDirName
        #else
            dbDirName
        #endif
    }
}
