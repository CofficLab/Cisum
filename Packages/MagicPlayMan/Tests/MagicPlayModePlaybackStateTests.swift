@testable import MagicPlayMan
import ProviderPlayback
import XCTest

// MARK: - PlaybackMode Tests

final class PlaybackModeTests: XCTestCase {
    func testDisplayName() {
        XCTAssertEqual(PlaybackMode.sequence.displayName, "Sequential Play")
        XCTAssertEqual(PlaybackMode.loop.displayName, "Single Track Loop")
        XCTAssertEqual(PlaybackMode.shuffle.displayName, "Shuffle Play")
        XCTAssertEqual(PlaybackMode.repeatAll.displayName, "Repeat All")
    }

    func testShortName() {
        XCTAssertEqual(PlaybackMode.sequence.shortName, "Sequential")
        XCTAssertEqual(PlaybackMode.loop.shortName, "Loop One")
        XCTAssertEqual(PlaybackMode.shuffle.shortName, "Shuffle")
        XCTAssertEqual(PlaybackMode.repeatAll.shortName, "Repeat All")
    }

    func testIconName() {
        XCTAssertEqual(PlaybackMode.sequence.iconName, "music.note.list")
        XCTAssertEqual(PlaybackMode.loop.iconName, "repeat.1")
        XCTAssertEqual(PlaybackMode.shuffle.iconName, "shuffle")
        XCTAssertEqual(PlaybackMode.repeatAll.iconName, "repeat")
    }

    func testIconAlias() {
        XCTAssertEqual(PlaybackMode.sequence.icon, PlaybackMode.sequence.iconName)
        XCTAssertEqual(PlaybackMode.loop.icon, PlaybackMode.loop.iconName)
    }

    func testNextCyclesCorrectly() {
        XCTAssertEqual(PlaybackMode.sequence.next, .loop)
        XCTAssertEqual(PlaybackMode.loop.next, .shuffle)
        XCTAssertEqual(PlaybackMode.shuffle.next, .repeatAll)
        XCTAssertEqual(PlaybackMode.repeatAll.next, .sequence)
    }

    func testAllCases() {
        XCTAssertEqual(PlaybackMode.allCases.count, 4)
        for mode in PlaybackMode.allCases {
            XCTAssertTrue(PlaybackMode.allCases.contains(mode))
        }
    }

    func testRawValue() {
        XCTAssertEqual(PlaybackMode.sequence.rawValue, "sequence")
        XCTAssertEqual(PlaybackMode.loop.rawValue, "loop")
        XCTAssertEqual(PlaybackMode.shuffle.rawValue, "shuffle")
        XCTAssertEqual(PlaybackMode.repeatAll.rawValue, "repeatAll")
    }

    func testToastMessage() {
        let (msg, icon) = PlaybackMode.shuffle.toastMessage
        XCTAssertEqual(msg, "Shuffle Play")
        XCTAssertEqual(icon, "shuffle")
    }
}

// MARK: - PlaybackState Tests

final class PlaybackStateTests: XCTestCase {
    func testIsPlaying() {
        XCTAssertTrue(PlaybackState.playing.isPlaying)
        XCTAssertFalse(PlaybackState.paused.isPlaying)
        XCTAssertFalse(PlaybackState.stopped.isPlaying)
        XCTAssertFalse(PlaybackState.idle.isPlaying)
        XCTAssertFalse(PlaybackState.loading(.connecting).isPlaying)
        XCTAssertFalse(PlaybackState.willPlay.isPlaying)
        XCTAssertFalse(PlaybackState.failed(.noAsset).isPlaying)
    }

    func testIsLoading() {
        XCTAssertTrue(PlaybackState.loading(.connecting).isLoading)
        XCTAssertTrue(PlaybackState.loading(.preparing).isLoading)
        XCTAssertTrue(PlaybackState.loading(.buffering).isLoading)
        XCTAssertTrue(PlaybackState.loading(.downloading(0.5)).isLoading)
        XCTAssertFalse(PlaybackState.idle.isLoading)
        XCTAssertFalse(PlaybackState.playing.isLoading)
    }

    func testIsDownloading() {
        XCTAssertTrue(PlaybackState.loading(.downloading(0.0)).isDownloading)
        XCTAssertTrue(PlaybackState.loading(.downloading(1.0)).isDownloading)
        XCTAssertFalse(PlaybackState.loading(.connecting).isDownloading)
        XCTAssertFalse(PlaybackState.loading(.preparing).isDownloading)
        XCTAssertFalse(PlaybackState.loading(.buffering).isDownloading)
        XCTAssertFalse(PlaybackState.playing.isDownloading)
    }

    func testIsUnsupportedFormat() {
        XCTAssertTrue(PlaybackState.failed(.unsupportedFormat("txt")).isUnsupportedFormat)
        XCTAssertFalse(PlaybackState.failed(.noAsset).isUnsupportedFormat)
        XCTAssertFalse(PlaybackState.failed(.invalidAsset).isUnsupportedFormat)
        XCTAssertFalse(PlaybackState.failed(.networkError("timeout")).isUnsupportedFormat)
        XCTAssertFalse(PlaybackState.playing.isUnsupportedFormat)
    }

    func testCanSeek() {
        XCTAssertTrue(PlaybackState.willPlay.canSeek)
        XCTAssertTrue(PlaybackState.playing.canSeek)
        XCTAssertTrue(PlaybackState.paused.canSeek)
        XCTAssertTrue(PlaybackState.stopped.canSeek)
        XCTAssertFalse(PlaybackState.idle.canSeek)
        XCTAssertFalse(PlaybackState.loading(.connecting).canSeek)
        XCTAssertFalse(PlaybackState.loading(.buffering).canSeek)
        XCTAssertFalse(PlaybackState.failed(.noAsset).canSeek)
    }

    func testIconName() {
        XCTAssertEqual(PlaybackState.idle.iconName, "circle.dashed")
        XCTAssertEqual(PlaybackState.loading(.connecting).iconName, "arrow.clockwise")
        XCTAssertEqual(PlaybackState.willPlay.iconName, "play.circle")
        XCTAssertEqual(PlaybackState.playing.iconName, "play.circle.fill")
        XCTAssertEqual(PlaybackState.paused.iconName, "pause.circle.fill")
        XCTAssertEqual(PlaybackState.stopped.iconName, "stop.circle.fill")
        XCTAssertEqual(PlaybackState.failed(.noAsset).iconName, "exclamationmark.circle.fill")
    }

    func testStateText() {
        XCTAssertEqual(PlaybackState.idle.stateText, "Ready")
        XCTAssertEqual(PlaybackState.loading(.connecting).stateText, "Connecting...")
        XCTAssertEqual(PlaybackState.loading(.preparing).stateText, "Preparing...")
        XCTAssertEqual(PlaybackState.loading(.buffering).stateText, "Buffering...")
        XCTAssertEqual(PlaybackState.loading(.downloading(0.5)).stateText, "Downloading... 50%")
        XCTAssertEqual(PlaybackState.willPlay.stateText, "Will Play")
        XCTAssertEqual(PlaybackState.playing.stateText, "Playing")
        XCTAssertEqual(PlaybackState.paused.stateText, "Paused")
        XCTAssertEqual(PlaybackState.stopped.stateText, "Stopped")
        XCTAssertEqual(PlaybackState.failed(.noAsset).stateText, "Failed")
    }

    func testDownloadPercentTextClamping() {
        XCTAssertEqual(PlaybackState.downloadPercentText(for: -0.5), "0%")
        XCTAssertEqual(PlaybackState.downloadPercentText(for: 0.0), "0%")
        XCTAssertEqual(PlaybackState.downloadPercentText(for: 0.33), "33%")
        XCTAssertEqual(PlaybackState.downloadPercentText(for: 0.99), "99%")
        XCTAssertEqual(PlaybackState.downloadPercentText(for: 1.0), "100%")
        XCTAssertEqual(PlaybackState.downloadPercentText(for: 1.5), "100%")
        XCTAssertEqual(PlaybackState.downloadPercentText(for: .nan), "0%")
        XCTAssertEqual(PlaybackState.downloadPercentText(for: .infinity), "0%")
    }

    func testLocalizedStateText() {
        let loc = Localization(locale: Locale(identifier: "zh_CN"))
        XCTAssertEqual(PlaybackState.idle.localizedStateText(localization: loc), loc.ready)
        XCTAssertEqual(PlaybackState.loading(.connecting).localizedStateText(localization: loc), loc.connecting)
        XCTAssertEqual(PlaybackState.loading(.preparing).localizedStateText(localization: loc), loc.preparing)
        XCTAssertEqual(PlaybackState.loading(.buffering).localizedStateText(localization: loc), loc.buffering)
        XCTAssertTrue(PlaybackState.loading(.downloading(0.5)).localizedStateText(localization: loc).contains(loc.downloading))
        XCTAssertEqual(PlaybackState.willPlay.localizedStateText(localization: loc), loc.willPlay)
        XCTAssertEqual(PlaybackState.playing.localizedStateText(localization: loc), loc.playing)
        XCTAssertEqual(PlaybackState.paused.localizedStateText(localization: loc), loc.paused)
        XCTAssertEqual(PlaybackState.stopped.localizedStateText(localization: loc), loc.stopped)
        XCTAssertEqual(PlaybackState.failed(.noAsset).localizedStateText(localization: loc), loc.failed)
    }

    func testLocalizedErrorDescription() {
        let loc = Localization(locale: Locale(identifier: "zh_CN"))
        XCTAssertNil(PlaybackState.playing.localizedErrorDescription(localization: loc))
        XCTAssertNil(PlaybackState.idle.localizedErrorDescription(localization: loc))
        XCTAssertNotNil(PlaybackState.failed(.noAsset).localizedErrorDescription(localization: loc))
        XCTAssertNotNil(PlaybackState.failed(.invalidAsset).localizedErrorDescription(localization: loc))
    }

    // MARK: - PlaybackError

    func testErrorDescriptionsAreAvailableForEveryCase() {
        let errors: [PlaybackState.PlaybackError] = [
            .noAsset,
            .invalidAsset,
            .networkError("timeout"),
            .playbackError("crash"),
            .unsupportedFormat("flac"),
            .invalidURL("bad"),
        ]
        for error in errors {
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
        }
    }

    func testErrorLocalizedDescription() {
        let loc = Localization(locale: Locale(identifier: "zh_CN"))
        XCTAssertEqual(PlaybackState.PlaybackError.noAsset.localizedDescription(localization: loc), loc.noMediaSelected)
        XCTAssertEqual(PlaybackState.PlaybackError.invalidAsset.localizedDescription(localization: loc), loc.invalidOrCorrupted)
        XCTAssertEqual(PlaybackState.PlaybackError.networkError("timeout").localizedDescription(localization: loc), "\(loc.networkError): timeout")
        XCTAssertEqual(PlaybackState.PlaybackError.unsupportedFormat("txt").localizedDescription(localization: loc), "\(loc.unsupportedFormat): txt")
        XCTAssertEqual(PlaybackState.PlaybackError.invalidURL("bad://url").localizedDescription(localization: loc), "\(loc.invalidURL): bad://url")
    }

    func testErrorLocalizedFailureReason() {
        let loc = Localization(locale: Locale(identifier: "zh_CN"))
        XCTAssertEqual(PlaybackState.PlaybackError.noAsset.localizedFailureReason(localization: loc), loc.pleaseSelectMedia)
        XCTAssertEqual(PlaybackState.PlaybackError.invalidAsset.localizedFailureReason(localization: loc), loc.fileFormatNotSupportedOrCorrupted)
        XCTAssertEqual(PlaybackState.PlaybackError.networkError("x").localizedFailureReason(localization: loc), loc.networkConnectionProblem)
        XCTAssertEqual(PlaybackState.PlaybackError.playbackError("x").localizedFailureReason(localization: loc), loc.playbackProblem)
        XCTAssertEqual(PlaybackState.PlaybackError.unsupportedFormat("x").localizedFailureReason(localization: loc), loc.mediaTypeNotSupported)
        XCTAssertEqual(PlaybackState.PlaybackError.invalidURL("x").localizedFailureReason(localization: loc), loc.invalidURLReason)
    }

    func testErrorLocalizedRecoverySuggestion() {
        let loc = Localization(locale: Locale(identifier: "zh_CN"))
        XCTAssertEqual(PlaybackState.PlaybackError.noAsset.localizedRecoverySuggestion(localization: loc), loc.selectMediaFromLibrary)
        XCTAssertEqual(PlaybackState.PlaybackError.invalidAsset.localizedRecoverySuggestion(localization: loc), loc.tryDifferentMedia)
        XCTAssertEqual(PlaybackState.PlaybackError.networkError("x").localizedRecoverySuggestion(localization: loc), loc.checkInternetConnection)
        XCTAssertEqual(PlaybackState.PlaybackError.playbackError("x").localizedRecoverySuggestion(localization: loc), loc.tryReloadMedia)
        XCTAssertEqual(PlaybackState.PlaybackError.unsupportedFormat("x").localizedRecoverySuggestion(localization: loc), loc.chooseSupportedFormat)
        XCTAssertEqual(PlaybackState.PlaybackError.invalidURL("x").localizedRecoverySuggestion(localization: loc), loc.checkURLFormat)
    }

    func testErrorStandardFailureReason() {
        XCTAssertNotNil(PlaybackState.PlaybackError.noAsset.failureReason)
        XCTAssertNotNil(PlaybackState.PlaybackError.invalidAsset.failureReason)
        XCTAssertNotNil(PlaybackState.PlaybackError.networkError("x").failureReason)
        XCTAssertNotNil(PlaybackState.PlaybackError.playbackError("x").failureReason)
        XCTAssertNotNil(PlaybackState.PlaybackError.unsupportedFormat("x").failureReason)
        XCTAssertNotNil(PlaybackState.PlaybackError.invalidURL("x").failureReason)
    }

    func testErrorStandardRecoverySuggestion() {
        XCTAssertNotNil(PlaybackState.PlaybackError.noAsset.recoverySuggestion)
        XCTAssertNotNil(PlaybackState.PlaybackError.invalidAsset.recoverySuggestion)
        XCTAssertNotNil(PlaybackState.PlaybackError.networkError("x").recoverySuggestion)
        XCTAssertNotNil(PlaybackState.PlaybackError.playbackError("x").recoverySuggestion)
        XCTAssertNotNil(PlaybackState.PlaybackError.unsupportedFormat("x").recoverySuggestion)
        XCTAssertNotNil(PlaybackState.PlaybackError.invalidURL("x").recoverySuggestion)
    }

    func testErrorEquality() {
        XCTAssertEqual(PlaybackState.PlaybackError.noAsset, .noAsset)
        XCTAssertEqual(PlaybackState.PlaybackError.invalidAsset, .invalidAsset)
        XCTAssertEqual(PlaybackState.PlaybackError.networkError("timeout"), .networkError("timeout"))
        XCTAssertNotEqual(PlaybackState.PlaybackError.networkError("timeout"), .networkError("refused"))
        XCTAssertEqual(PlaybackState.PlaybackError.unsupportedFormat("txt"), .unsupportedFormat("txt"))
        XCTAssertNotEqual(PlaybackState.PlaybackError.noAsset, .invalidAsset)
    }

    // MARK: - PlaybackState Equality

    func testStateEquality() {
        XCTAssertEqual(PlaybackState.idle, .idle)
        XCTAssertEqual(PlaybackState.playing, .playing)
        XCTAssertEqual(PlaybackState.paused, .paused)
        XCTAssertEqual(PlaybackState.stopped, .stopped)
        XCTAssertEqual(PlaybackState.willPlay, .willPlay)
        XCTAssertEqual(PlaybackState.loading(.connecting), .loading(.connecting))
        XCTAssertEqual(PlaybackState.loading(.downloading(0.5)), .loading(.downloading(0.5)))
        XCTAssertEqual(PlaybackState.failed(.noAsset), .failed(.noAsset))
        XCTAssertNotEqual(PlaybackState.idle, .playing)
        XCTAssertNotEqual(PlaybackState.loading(.connecting), .loading(.buffering))
    }
}
