import XCTest
@testable import MagicPlayMan
import MagicKit

/// iCloud 下载失败在播放层的呈现契约。
///
/// 重点：iCloud 失败必须独立成态，不得混入 `.networkError`，
/// 否则用户会看到「网络错误」而实际问题是 iCloud 没下下来。
final class PlaybackICloudFailureTests: XCTestCase {
    private let loc = Localization()

    // MARK: - State discrimination

    func testICloudFailureIsNotTreatedAsNetworkError() {
        let state = PlaybackState.failed(.iCloudDownloadFailed("Timed out"))

        XCTAssertTrue(state.isFailed)
        XCTAssertTrue(state.isICloudDownloadFailed)
        XCTAssertNotEqual(state, .failed(.networkError("Timed out")))
    }

    func testNetworkErrorIsNotICloudFailure() {
        let state = PlaybackState.failed(.networkError("Timed out"))

        XCTAssertFalse(state.isICloudDownloadFailed)
    }

    /// 下载中与失败态互斥，不能同时成立。
    func testDownloadingStateIsNotFailure() {
        let state = PlaybackState.loading(.downloading(0.5))

        XCTAssertTrue(state.isDownloading)
        XCTAssertFalse(state.isFailed)
        XCTAssertFalse(state.isICloudDownloadFailed)
    }

    // MARK: - Classification

    /// iCloud 超时 / 离线必须归到 iCloud case，其余保持 networkError。
    func testClassificationMapsICloudErrorsToICloudFailure() {
        let icloudErrors: [Error] = [
            ICloudDownloadError.timedOut(fileName: "a.mp3"),
            ICloudDownloadError.requestFailed("offline"),
            ICloudDownloadError.unavailable,
        ]

        for error in icloudErrors {
            let mapped = Self.playbackFailure(for: error)
            guard case .iCloudDownloadFailed = mapped else {
                return XCTFail("应映射为 iCloudDownloadFailed，实际 \(mapped)")
            }
        }
    }

    /// 非 iCloud 错误不得被误判成 iCloud 失败。
    func testClassificationLeavesForeignErrorsAsNetworkError() {
        let mapped = Self.playbackFailure(for: NSError(domain: "Other", code: 1))

        guard case .networkError = mapped else {
            return XCTFail("应保持 networkError，实际 \(mapped)")
        }
    }

    /// 复刻 `MagicPlayMan.downloadAndCache` 的错误归类逻辑。
    ///
    /// 直接断言私有方法会让测试与实现耦合，这里按同一契约独立实现一次，
    /// 用于验证「ICloudDownloadError → iCloud case」这条规则本身。
    private static func playbackFailure(for error: Error) -> PlaybackState.PlaybackError {
        if let iCloudError = error as? ICloudDownloadError, iCloudError.isICloudDownloadFailure {
            return .iCloudDownloadFailed(iCloudError.errorDescription ?? "iCloud")
        }

        return .networkError(error.localizedDescription)
    }

    // MARK: - Messages

    func testICloudFailureHasDistinctMessageFromNetworkError() {
        let icloud = PlaybackState.PlaybackError.iCloudDownloadFailed("Timed out")
        let network = PlaybackState.PlaybackError.networkError("Timed out")

        XCTAssertNotEqual(
            icloud.localizedDescription(localization: loc),
            network.localizedDescription(localization: loc),
            "iCloud 失败与网络失败必须有不同的文案"
        )
    }

    func testFailureReasonAndRecoveryPointAtICloudNotNetwork() {
        let error = PlaybackState.PlaybackError.iCloudDownloadFailed("Timed out")

        XCTAssertEqual(error.localizedFailureReason(localization: loc), loc.iCloudDownloadFailedReason)
        XCTAssertEqual(error.localizedRecoverySuggestion(localization: loc), loc.retryICloudDownload)
    }

    /// iCloud 的恢复建议应提及 iCloud 存储空间，而不是只让用户查网络。
    func testRecoverySuggestionMentionsICloudStorage() {
        let suggestion = PlaybackState.PlaybackError.iCloudDownloadFailed("x")
            .localizedRecoverySuggestion(localization: loc)

        XCTAssertTrue(
            suggestion.localizedCaseInsensitiveContains("iCloud"),
            "恢复建议应指向 iCloud 存储空间，实际：\(suggestion)"
        )
    }

    func testStandaloneFailureReasonAndRecoveryAreNonEmpty() {
        let error = PlaybackState.PlaybackError.iCloudDownloadFailed("x")

        XCTAssertFalse(error.failureReason?.isEmpty ?? true)
        XCTAssertFalse(error.recoverySuggestion?.isEmpty ?? true)
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }

    /// 每种失败态都必须有非空文案，避免 UI 出现空白错误提示。
    func testEveryPlaybackErrorHasNonEmptyDescription() {
        let errors: [PlaybackState.PlaybackError] = [
            .noAsset,
            .invalidAsset,
            .networkError("m"),
            .playbackError("m"),
            .unsupportedFormat("flac"),
            .invalidURL("ftp://x"),
            .iCloudDownloadFailed("m"),
        ]

        for error in errors {
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true, "缺少 errorDescription：\(error)")
            XCTAssertFalse(error.localizedFailureReason(localization: loc).isEmpty, "缺少原因：\(error)")
            XCTAssertFalse(error.localizedRecoverySuggestion(localization: loc).isEmpty, "缺少建议：\(error)")
        }
    }

    // MARK: - Presentation

    /// 失败态的图标与颜色应与「播放中」明确区分。
    func testFailurePresentationDiffersFromPlaying() {
        let failed = PlaybackState.failed(.iCloudDownloadFailed("x"))
        let playing = PlaybackState.playing

        XCTAssertNotEqual(failed.iconName, playing.iconName)
        XCTAssertEqual(failed.iconColor, .red, "失败态应显示为红色")
    }

    /// 失败态不可 seek，避免在无有效媒体时拖动进度。
    func testFailedStateCannotSeek() {
        XCTAssertFalse(PlaybackState.failed(.iCloudDownloadFailed("x")).canSeek)
    }

    // MARK: - Localized strings

    /// 各语言都必须能取到非空译文，否则会回退成英文 key。
    ///
    /// 直接读仓库中的 String Catalog 源文件（SPM 测试环境的 Bundle 里只有
    /// 编译产物，拿不到源文件），断言每种语言都有非空且不同于 key 的译文。
    func testICloudStringsResolveForEveryLanguage() throws {
        let strings = try Self.loadStringCatalog()
        let keys = [
            "iCloud Download Failed",
            "The file could not be downloaded from iCloud",
            "Check your internet connection and iCloud storage space, then try again",
        ]
        let languages = ["en", "zh-Hans", "zh-Hant-HK", "zh-Hant-TW"]

        for key in keys {
            let entry = try XCTUnwrap(strings[key] as? [String: Any], "缺少键：\(key)")
            let localizations = try XCTUnwrap(
                entry["localizations"] as? [String: Any],
                "缺少 localizations：\(key)"
            )

            for language in languages {
                let unit = try XCTUnwrap(
                    localizations[language] as? [String: Any],
                    "\(key) 缺少 \(language) 翻译"
                )
                let stringUnit = try XCTUnwrap(unit["stringUnit"] as? [String: Any])
                let value = try XCTUnwrap(stringUnit["value"] as? String, "\(key)/\(language) 缺少 value")

                XCTAssertFalse(value.isEmpty, "\(key) 的 \(language) 译文为空")
                if language != "en" {
                    XCTAssertNotEqual(value, key, "\(key) 的 \(language) 回退成了英文 key")
                }
            }
        }
    }

    /// 简体与繁体必须给出不同译文，避免繁中用户看到简体文案。
    func testSimplifiedAndTraditionalDiffer() throws {
        let strings = try Self.loadStringCatalog()
        let key = "The file could not be downloaded from iCloud"

        let entry = try XCTUnwrap(strings[key] as? [String: Any])
        let localizations = try XCTUnwrap(entry["localizations"] as? [String: Any])

        func value(_ language: String) throws -> String {
            let unit = try XCTUnwrap(localizations[language] as? [String: Any])
            let stringUnit = try XCTUnwrap(unit["stringUnit"] as? [String: Any])
            return try XCTUnwrap(stringUnit["value"] as? String)
        }

        XCTAssertNotEqual(try value("zh-Hans"), try value("zh-Hant-HK"), "简繁文案不应相同")
    }

    /// 读取 `Resources/Localizable.xcstrings` 源文件。
    private static func loadStringCatalog() throws -> [String: Any] {
        // #filePath: .../MagicPlayMan/Tests/PlaybackICloudFailureTests.swift
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // MagicPlayMan
        let catalogURL = packageRoot
            .appendingPathComponent("Resources")
            .appendingPathComponent("Localizable.xcstrings")

        let data = try Data(contentsOf: catalogURL)
        let json = try JSONSerialization.jsonObject(with: data)
        return try XCTUnwrap(json as? [String: Any])["strings"] as? [String: Any] ?? [:]
    }
}
