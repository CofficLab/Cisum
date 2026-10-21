import Foundation
import SwiftUI
import Testing
@testable import ProviderPlayback

@MainActor
private final class StubPlaybackProvider: PlaybackProviding {
    var state: PlaybackStatus = .paused
    var currentURL: URL? = URL(fileURLWithPath: "/library/current.mp3")
    var currentTime: TimeInterval = 12
    var duration: TimeInterval = 48
    var progress: Double = 0.25
    var playMode: PlaybackMode = .shuffle
    var likedAssets: Set<URL> = [URL(fileURLWithPath: "/library/liked.mp3")]
    private(set) var playedURLs: [URL] = []

    var isPlaying: Bool { state.isPlaying }
    var hasAsset: Bool { currentURL != nil }

    func play(_ url: URL) async { playedURLs.append(url) }
    func pause() {}
    func toggle() {}
    func seek(toProgress progress: Double) {}
    func seek(toTime time: TimeInterval) {}
    func next() {}
    func previous() {}
    func setPlayMode(_ mode: PlaybackMode) {}
    func toggleCurrentLike() {}
    func togglePlayMode() {}
}

@MainActor
struct ProviderPlaybackTests {
    @Test
    func observerReceivesEventsAndStopsAfterCancellation() {
        let store = PlaybackObserverStore<Int>()
        var received: [Int] = []
        let handle = store.add { received.append($0) }

        store.send(1)
        #expect(received == [1])

        handle.cancel()
        store.send(2)
        #expect(received == [1])
    }

    @Test
    func observerCanCancelItselfWithoutSkippingOtherObservers() {
        let store = PlaybackObserverStore<Int>()
        var selfReceived: [Int] = []
        var otherReceived: [Int] = []
        var selfHandle: PlaybackObserverStoreHandle<Int>?
        selfHandle = store.add {
            selfReceived.append($0)
            selfHandle?.cancel()
        }
        let otherHandle = store.add { otherReceived.append($0) }

        store.send(1)
        store.send(2)
        selfHandle?.cancel()
        otherHandle.cancel()
        otherHandle.cancel()

        #expect(selfReceived == [1])
        #expect(otherReceived.count == 2)
    }

    @Test
    func snapshotDerivesAssetAndPlayingState() {
        let snapshot = PlaybackSnapshot(
            state: .playing,
            currentURL: URL(fileURLWithPath: "/tmp/track.mp3"),
            currentTime: 1,
            duration: 2,
            progress: 0.5,
            playMode: .sequence,
            likedAssets: []
        )

        #expect(snapshot.isPlaying)
        #expect(snapshot.hasAsset)
    }

    @Test
    func playbackStatusFlagsDistinguishLoadingAndDownloading() {
        #expect(!PlaybackStatus.idle.isPlaying)
        #expect(!PlaybackStatus.idle.isLoading)
        #expect(!PlaybackStatus.idle.isDownloading)

        #expect(PlaybackStatus.loading(.connecting).isLoading)
        #expect(!PlaybackStatus.loading(.connecting).isDownloading)
        #expect(PlaybackStatus.loading(.downloading(0.4)).isDownloading)
        #expect(!PlaybackStatus.loading(.downloading(0.4)).isPlaying)

        #expect(PlaybackStatus.playing.isPlaying)
        #expect(!PlaybackStatus.paused.isPlaying)
        #expect(!PlaybackStatus.stopped.isLoading)
        #expect(!PlaybackStatus.failed(.noAsset).isDownloading)
    }

    @Test
    func noOpObserverFallbackCanBeCancelledRepeatedly() {
        let provider = StubPlaybackProvider()
        let handle = provider.addObserver { _ in
            Issue.record("The default observer must not receive events")
        }

        #expect(handle is NoopPlaybackProvidingObserverHandle)
        handle.cancel()
        handle.cancel()
    }

    @Test
    func navigationFailurePreservesDirectionAndReason() {
        let failure = PlaybackNavigationFailure(direction: .next, reason: "No next track")

        #expect(failure.direction == .next)
        #expect(failure.reason == "No next track")
        #expect(PlaybackNavigationFailure(direction: .previous, reason: "Unavailable") != failure)
        #expect(PlaybackMode.allCases.map(\.rawValue) == ["sequence", "loop", "shuffle", "repeatAll"])
    }

    @Test(arguments: [
        (PlaybackStatus.idle, false, false, false),
        (.willPlay, false, false, false), (.playing, true, false, false),
        (.paused, false, false, false), (.stopped, false, false, false),
        (.failed(.iCloudDownloadFailed("offline")), false, false, false),
        (.loading(.connecting), false, true, false),
        (.loading(.preparing), false, true, false),
        (.loading(.buffering), false, true, false),
        (.loading(.downloading(0)), false, true, true),
        (.loading(.downloading(1)), false, true, true),
    ])
    func everyStatusHasConsistentFlags(state: PlaybackStatus, playing: Bool, loading: Bool, downloading: Bool) {
        #expect(state.isPlaying == playing)
        #expect(state.isLoading == loading)
        #expect(state.isDownloading == downloading)
    }

    @Test
    func snapshotsAreIndependentValuesAndRefreshFromProvider() {
        let provider = StubPlaybackProvider()
        let before = provider.snapshot
        provider.state = .idle
        provider.currentURL = nil
        provider.currentTime = 0
        provider.duration = 0
        provider.progress = 0
        provider.playMode = .loop
        provider.likedAssets = []
        let after = provider.snapshot
        #expect(before.currentTime == 12)
        #expect(before.hasAsset)
        #expect(before.likedAssets.count == 1)
        #expect(after == PlaybackSnapshot(state: .idle, currentURL: nil, currentTime: 0,
                                         duration: 0, progress: 0, playMode: .loop, likedAssets: []))
        #expect(!after.hasAsset)
        #expect(!after.isPlaying)
        #expect(before != after)
    }

    @Test
    func observersAddedDuringDeliveryStartWithNextEvent() {
        let store = PlaybackObserverStore<Int>()
        var received: [Int] = []
        var added: PlaybackObserverStoreHandle<Int>?
        let first = store.add { _ in
            if added == nil { added = store.add { received.append($0) } }
        }
        store.send(1)
        #expect(received.isEmpty)
        store.send(2)
        #expect(received == [2])
        first.cancel()
        added?.cancel()
        store.send(3)
        #expect(received == [2])
    }

    @Test
    func observerHandleDoesNotRetainStore() {
        var store: PlaybackObserverStore<Int>? = PlaybackObserverStore()
        weak var weakStore: PlaybackObserverStore<Int>?
        weakStore = store
        let handle: any PlaybackProvidingObserverHandle = store!.add { _ in }
        store = nil
        #expect(weakStore == nil)
        handle.cancel()
        handle.cancel()
    }

    @Test
    func semanticEventPayloadsSurviveStoreDelivery() {
        let store = PlaybackObserverStore<PlaybackProvidingEvent>()
        let url = URL(fileURLWithPath: "/library/a b.mp3")
        let snapshot = StubPlaybackProvider().snapshot
        let failure = PlaybackNavigationFailure(direction: .previous, reason: "没有上一首")
        var cases: [String] = []
        let handle = store.add { event in
            switch event {
            case .snapshotChanged(let value):
                #expect(value == snapshot); cases.append("snapshot")
            case .stateChanged(let value):
                #expect(value == .failed(.networkError("offline"))); cases.append("state")
            case .assetChanged(let value):
                #expect(value == nil); cases.append("asset")
            case .timeChanged(let time, let progress):
                #expect(time == 12); #expect(progress == 0.25); cases.append("time")
            case .durationChanged(let value):
                #expect(value == 48); cases.append("duration")
            case .playModeChanged(let value):
                #expect(value == .repeatAll); cases.append("mode")
            case .likedAssetsChanged(let value):
                #expect(value == [url]); cases.append("likes")
            case .likeStatusChanged(let asset, let liked):
                #expect(asset == url); #expect(!liked); cases.append("like")
            case .previousRequested(let value):
                #expect(value == url); cases.append("previous")
            case .nextRequested(let value):
                #expect(value == url); cases.append("next")
            case .navigationFailed(let value):
                #expect(value == failure); cases.append("failure")
            }
        }
        let events: [PlaybackProvidingEvent] = [
            .snapshotChanged(snapshot), .stateChanged(.failed(.networkError("offline"))),
            .assetChanged(nil), .timeChanged(currentTime: 12, progress: 0.25),
            .durationChanged(48), .playModeChanged(.repeatAll), .likedAssetsChanged([url]),
            .likeStatusChanged(asset: url, isLiked: false), .previousRequested(url),
            .nextRequested(url), .navigationFailed(failure),
        ]
        events.forEach(store.send)
        #expect(cases == ["snapshot", "state", "asset", "time", "duration", "mode", "likes", "like", "previous", "next", "failure"])
        handle.cancel()
        events.forEach(store.send)
        #expect(cases.count == events.count)
    }

    @Test
    func providerDefaultsBuildSnapshotAndForwardTimedPlay() async {
        let provider = StubPlaybackProvider()
        let snapshot = provider.snapshot
        let timedURL = URL(fileURLWithPath: "/library/timed.mp3")

        await provider.play(timedURL, startTime: 9)
        await provider.reset()

        #expect(snapshot.state == .paused)
        #expect(snapshot.currentURL == provider.currentURL)
        #expect(snapshot.currentTime == 12)
        #expect(snapshot.duration == 48)
        #expect(snapshot.progress == 0.25)
        #expect(snapshot.playMode == .shuffle)
        #expect(snapshot.likedAssets == provider.likedAssets)
        #expect(!snapshot.isPlaying)
        #expect(snapshot.hasAsset)
        #expect(provider.playedURLs == [timedURL])
        #expect(provider.state == .paused)
        #expect(provider.currentURL == URL(fileURLWithPath: "/library/current.mp3"))
    }

    /// 下载标签的默认实现：从下载态状态文案里剥离尾部百分比。
    ///
    /// Hero 圆环中心已单独显示百分比，底部小字必须只有「正在下载」，
    /// 否则同一屏出现两个百分比（历史上曾拼成「0% 正在下载 0%」）。
    @Test
    func downloadingLabelStripsTrailingPercentage() {
        let provider = StubMediaProvider()

        #expect(provider.localizedStateText(for: .loading(.downloading(0.14))) == "正在下载 14%")
        #expect(provider.localizedDownloadingLabel() == "正在下载")
        #expect(!provider.localizedDownloadingLabel().contains("%"))

        // 状态文案本身不带百分比时，原样返回，不误伤尾部的普通词。
        provider.downloadingText = "正在下载"
        #expect(provider.localizedDownloadingLabel() == "正在下载")
    }
}

/// 下载态文案的替身：模拟引擎的「文案 + 百分比」格式。
@MainActor
private final class StubMediaProvider: PlaybackMediaProviding {
    var downloadingText = "正在下载 14%"

    func makeMediaView() -> AnyView { AnyView(EmptyView()) }

    func localizedStateText(for state: PlaybackStatus) -> String {
        switch state {
        case .loading(.downloading):
            return downloadingText
        default:
            return "state:\(String(describing: state))"
        }
    }
}
