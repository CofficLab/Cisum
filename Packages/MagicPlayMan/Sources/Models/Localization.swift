import Foundation
import SwiftUI
import LumiUI
import MagicKit

/// 本地化字符串管理
public struct Localization {
    private let bundle: Bundle
    private let locale: Locale

    public init(locale: Locale = .current) {
        self.bundle = .module
        self.locale = locale
    }

    /// Xcode 构建会生成 `.lproj/Localizable.strings`；`swift test` 等场景可能只打包源 `.xcstrings`。
    private func localized(_ key: String) -> String {
        let catalogLocale = Self.catalogLocale(for: locale)
        let catalogValue = String(
            localized: String.LocalizationValue(key),
            bundle: bundle,
            locale: catalogLocale
        )
        if catalogValue != key {
            return catalogValue
        }
        return Self.lookupInStringCatalog(key: key, locale: catalogLocale, bundle: bundle) ?? key
    }

    /// 将系统 locale 映射到 String Catalog 中真实存在的语言 id。
    ///
    /// Catalog 使用上游 Lumi 的语言集合：`zh-Hans` / `zh-HK` / `zh-TW` / `zh-Hant`。
    /// 系统可能给出 `zh_CN`、`zh-Hant-HK`、`zh-Hant-TW` 等写法，这里归一化到
    /// 上述集合中的真实条目，避免映射到不存在的 id 而被迫依赖 fallback 侥幸命中。
    ///
    /// - `zh-HK` 与 `zh-Hant-HK` → `zh-HK`（香港）
    /// - `zh-TW` 与 `zh-Hant-TW` → `zh-TW`（台湾）
    /// - `zh-Hant` / `zh-MO` → `zh-Hant`（通用繁体）
    /// - 其余 `zh-*` → `zh-Hans`（简体）
    static func catalogLocale(for locale: Locale) -> Locale {
        let id = locale.identifier.replacingOccurrences(of: "_", with: "-")
        guard id.hasPrefix("zh") else { return locale }

        // 香港：显式 zh-HK / zh-Hant-HK，或任何以 -HK 结尾的繁体变体
        if id == "zh-HK" || id == "zh-Hant-HK" || id.hasSuffix("-HK") {
            return Locale(identifier: "zh-HK")
        }
        // 台湾：显式 zh-TW / zh-Hant-TW，或任何以 -TW 结尾的繁体变体
        if id == "zh-TW" || id == "zh-Hant-TW" || id.hasSuffix("-TW") {
            return Locale(identifier: "zh-TW")
        }
        // 澳门与通用繁体
        if id == "zh-Hant" || id == "zh-MO" {
            return Locale(identifier: "zh-Hant")
        }
        return Locale(identifier: "zh-Hans")
    }

    /// 同一书写系统内的回退顺序，与上游 Lumi 的 `variantFallbacks` 保持一致。
    ///
    /// 没有这层回退时，`zh-Hant` 这类通用繁体 id 会取不到值而直接掉到英文。
    static func variantFallbacks(for languageID: String) -> [String] {
        switch languageID {
        case "zh-Hant": ["zh-Hant", "zh-TW", "zh-HK"]
        case "zh-TW": ["zh-TW", "zh-Hant", "zh-HK"]
        case "zh-HK": ["zh-HK", "zh-Hant", "zh-TW"]
        default: [languageID]
        }
    }

    /// 仅在 bundle 内仍包含源 `Localizable.xcstrings` 时使用（如 SPM 测试）。
    static func lookupInStringCatalog(key: String, locale: Locale, bundle: Bundle) -> String? {
        guard let url = bundle.url(forResource: "Localizable", withExtension: "xcstrings"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = json["strings"] as? [String: Any],
              let entry = strings[key] as? [String: Any],
              let localizations = entry["localizations"] as? [String: Any] else {
            return nil
        }

        // 候选顺序：目标语言 → 同书写系统的其它变体 → 简体 → 英文。
        let target = catalogLocale(for: locale).identifier
        var preferredLocales: [String] = []
        for candidate in [target, locale.identifier] {
            for id in variantFallbacks(for: candidate) where !preferredLocales.contains(id) {
                preferredLocales.append(id)
            }
        }
        preferredLocales.append(contentsOf: ["zh-Hans", "en"])

        for localeId in preferredLocales {
            guard let loc = localizations[localeId] as? [String: Any],
                  let stringUnit = loc["stringUnit"] as? [String: Any],
                  let value = stringUnit["value"] as? String,
                  !value.isEmpty else { continue }
            return value
        }
        return nil
    }

    // MARK: - Common
    public var retry: String { localized("Retry") }
    public var loadingWithDots: String { localized("Loading...") }
    public var error: String { localized("Error") }

    // MARK: - Audio Content
    public var noArtworkAvailable: String { localized("No artwork available") }
    public var failedToLoadArtwork: String { localized("Failed to load artwork") }

    // MARK: - Format Info
    public var supportedFormats: String { localized("Supported Formats") }

    // MARK: - Error / Loading
    public var failedToLoadMedia: String { localized("Failed to Load Media") }

    // MARK: - Thumbnail
    public var noArtwork: String { localized("No Artwork") }

    // MARK: - Subscribers
    public var eventSubscribers: String { localized("Event Subscribers") }
    public var noSubscribersRegistered: String { localized("No subscribers are currently registered.") }
    public var noSubscribers: String { localized("No Subscribers") }
    public var since: String { localized("Since") }

    // MARK: - Play Mode
    public var lightMode: String { localized("Light Mode") }
    public var darkMode: String { localized("Dark Mode") }

    // MARK: - Buttons
    public var differentSizes: String { localized("Different Sizes") }

    // MARK: - Playback State
    public var nowPlaying: String { localized("Now Playing") }

    // MARK: - Loading States
    public var buffering: String { localized("Buffering...") }
    public var preparing: String { localized("Preparing...") }
    public var connecting: String { localized("Connecting...") }
    public var downloading: String { localized("Downloading") }

    // MARK: - Error Messages
    public var tryAgain: String { localized("Try Again") }
    public var noMediaSelected: String { localized("No media selected") }
    public var noMediaLoaded: String { localized("No media loaded") }
    public var selectMediaToPlay: String { localized("Select a media file to play") }
    public var invalidOrCorrupted: String { localized("The media file is invalid or corrupted") }
    public var networkError: String { localized("Network error") }
    public var playbackError: String { localized("Playback error") }
    public var unsupportedFormat: String { localized("Unsupported format") }
    public var iCloudDownloadFailedTitle: String { localized("iCloud Download Failed") }

    // MARK: - Playback State Text
    public var ready: String { localized("Ready") }
    public var willPlay: String { localized("Will Play") }
    public var playing: String { localized("Playing") }
    public var paused: String { localized("Paused") }
    public var stopped: String { localized("Stopped") }
    public var failed: String { localized("Failed") }

    // MARK: - Error Failure Reasons
    public var pleaseSelectMedia: String { localized("Please select a media file to play") }
    public var fileFormatNotSupportedOrCorrupted: String { localized("The file format is not supported or the file is corrupted") }
    public var networkConnectionProblem: String { localized("There was a problem with the network connection") }
    public var playbackProblem: String { localized("There was a problem during playback") }
    public var mediaTypeNotSupported: String { localized("The selected media type is not supported") }
    public var iCloudDownloadFailedReason: String { localized("The file could not be downloaded from iCloud") }

    // MARK: - Error Recovery Suggestions
    public var selectMediaFromLibrary: String { localized("Select a media file from your library") }
    public var tryDifferentMedia: String { localized("Try with a different media file") }
    public var checkInternetConnection: String { localized("Check your internet connection and try again") }
    public var tryReloadMedia: String { localized("Try reloading the media file") }
    public var chooseSupportedFormat: String { localized("Choose a supported audio or video format") }
    public var checkURLFormat: String { localized("Check if the URL format is correct") }
    public var invalidURL: String { localized("Invalid URL") }
    public var invalidURLReason: String { localized("The provided URL is invalid") }
    public var retryICloudDownload: String { localized("Check your internet connection and iCloud storage space, then try again") }

    // MARK: - Button Disabled Reasons
    public var firstTrack: String { localized("This is the first track") }
    public var lastTrack: String { localized("This is the last track") }
    public var previousTrack: String { localized("Previous Track") }
    public var nextTrack: String { localized("Next Track") }
    public var play: String { localized("Play") }
    public var pause: String { localized("Pause") }
    public var likeCurrentMedia: String { localized("Like Current Media") }
    public var unlikeCurrentMedia: String { localized("Unlike Current Media") }
    public var rewindTenSeconds: String { localized("Rewind 10 Seconds") }
    public var forwardTenSeconds: String { localized("Forward 10 Seconds") }
    public var showEventSubscribers: String { localized("Show Event Subscribers") }
    public var openMediaLibrary: String { localized("Open Media Library") }
    public var closeMediaLibrary: String { localized("Close Media Library") }

    // MARK: - Play Mode
    public var sequentialPlay: String { localized("Sequential Play") }
    public var singleTrackLoop: String { localized("Single Track Loop") }
    public var shufflePlay: String { localized("Shuffle Play") }
    public var repeatAll: String { localized("Repeat All") }

    // MARK: - Media Picker
    public var selectMedia: String { localized("Select Media") }
}

// MARK: - SwiftUI Environment Key

struct LocalizationKey: EnvironmentKey {
    static let defaultValue = Localization()
}

public extension EnvironmentValues {
    var localization: Localization {
        get { self[LocalizationKey.self] }
        set { self[LocalizationKey.self] = newValue }
    }
}

public extension View {
    /// 设置本地化配置
    /// - Parameter localization: 本地化配置对象
    /// - Returns: 应用本地化配置的视图
    func localization(_ localization: Localization) -> some View {
        environment(\.localization, localization)
    }
}

// MARK: - Preview Helper

extension Localization {
    /// 用于预览的本地化实例（中文）
    public static let preview = Localization()
}
