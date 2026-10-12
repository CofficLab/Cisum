import Foundation
import SwiftUI
import CisumUIComponents
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

    /// 将 `zh_CN` 等系统 locale 映射到 String Catalog 中的 `zh-Hans` / `zh-HK`。
    static func catalogLocale(for locale: Locale) -> Locale {
        let id = locale.identifier.replacingOccurrences(of: "_", with: "-")
        guard id.hasPrefix("zh") else { return locale }

        if id.contains("Hant") || id == "zh-TW" || id == "zh-HK" || id.hasSuffix("-HK") {
            return Locale(identifier: id.contains("HK") ? "zh-HK" : "zh-Hant")
        }
        return Locale(identifier: "zh-Hans")
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

        let preferredLocales = [
            locale.identifier,
            locale.identifier.replacingOccurrences(of: "_", with: "-"),
            catalogLocale(for: locale).identifier,
            "zh-Hans",
            "en",
        ]

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

    // MARK: - Error Recovery Suggestions
    public var selectMediaFromLibrary: String { localized("Select a media file from your library") }
    public var tryDifferentMedia: String { localized("Try with a different media file") }
    public var checkInternetConnection: String { localized("Check your internet connection and try again") }
    public var tryReloadMedia: String { localized("Try reloading the media file") }
    public var chooseSupportedFormat: String { localized("Choose a supported audio or video format") }
    public var checkURLFormat: String { localized("Check if the URL format is correct") }
    public var invalidURL: String { localized("Invalid URL") }
    public var invalidURLReason: String { localized("The provided URL is invalid") }

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
