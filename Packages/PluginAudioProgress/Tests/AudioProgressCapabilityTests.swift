import Foundation
import ProviderAudioLibrary
import ProviderPlayback
import Testing
@testable import PluginAudioProgress

// MARK: - 音频库能力：Provider 未就绪时的降级

/// 数据层插件的 boot 顺序不确定，进度恢复可能早于 `AudioLibraryProviding` 注册。
/// Provider 缺席时 `isAvailable` 必须为 false，让调用方区分
/// 「Provider 未就绪」与「库为空」——前者应放弃恢复，后者可回落到第一首。
@Test @MainActor func libraryCapabilityReportsUnavailableBeforeProviderRegistration() {
    let capability = ProgressAudioLibraryCapabilityAdapter { nil }
    #expect(capability.isAvailable == false)
}

@Test @MainActor func libraryCapabilityDegradesGracefullyWhenProviderMissing() async {
    let capability = ProgressAudioLibraryCapabilityAdapter { nil }

    // 缺席时查询应返回「空」而非崩溃
    let url = URL(fileURLWithPath: "/tmp/nonexistent.mp3")
    #expect(await capability.contains(url) == false)
    #expect(await capability.allURLs(reason: "test").isEmpty)
}

/// 惰性解析的核心价值：Provider 在能力创建之后才注册也应立即生效，
/// 无需重建 ViewModel 或重新绑定。
@Test @MainActor func libraryCapabilityResolvesProviderLazilyAfterCreation() async {
    let box = LibraryBox(provider: nil)
    let capability = ProgressAudioLibraryCapabilityAdapter { box.provider }

    // 创建时 Provider 尚未就绪
    #expect(capability.isAvailable == false)

    // 之后 Provider 注册，能力应自动感知
    box.provider = LibraryStub(urls: [URL(fileURLWithPath: "/tmp/a.mp3")])
    #expect(capability.isAvailable == true)
    #expect(await capability.allURLs(reason: "test").count == 1)
}

// MARK: - 播放能力：Provider 未就绪时的降级

/// 播放 Provider 缺席时应返回「空闲」默认态，而不是崩溃 ——
/// 进度条在播放能力就绪前就要渲染。
@Test @MainActor func playbackCapabilityFallsBackToIdleWhenProviderMissing() {
    let capability = PlaybackProgressCapabilityAdapter(playback: nil)

    #expect(capability.currentURL == nil)
    #expect(capability.state == .idle)
    #expect(capability.currentTime == 0)
    #expect(capability.likedAssets.isEmpty)
}

/// 缺席时调用写操作不应崩溃（会被上层忽略）。
@Test @MainActor func playbackCapabilityIgnoresMutationsWhenProviderMissing() async {
    let capability = PlaybackProgressCapabilityAdapter(playback: nil)

    capability.seek(toTime: 30)
    await capability.play(URL(fileURLWithPath: "/tmp/a.mp3"), startTime: nil)
    capability.toggleCurrentLike()

    // 状态仍为默认值
    #expect(capability.currentTime == 0)
    #expect(capability.likedAssets.isEmpty)
}

/// Provider 缺席时订阅也必须安全返回句柄，取消不崩溃。
@Test @MainActor func playbackObserverIsSafeWhenProviderMissing() {
    let capability = PlaybackProgressCapabilityAdapter(playback: nil)

    var notified = false
    let handle = capability.addObserver { _ in notified = true }

    #expect(!notified)
    handle.cancel()
    handle.cancel() // 幂等
}

// MARK: - 测试替身

/// 可变引用容器：模拟 Provider 在能力创建后才注册。
@MainActor
private final class LibraryBox {
    var provider: (any AudioLibraryProviding)?
    init(provider: (any AudioLibraryProviding)?) {
        self.provider = provider
    }
}

@MainActor
private final class LibraryStub: AudioLibraryProviding {
    let urls: [URL]

    init(urls: [URL]) {
        self.urls = urls
    }

    var audioDisk: URL? { nil }
    var supportedExtensions: [String] { ["mp3"] }
    var isAvailable: Bool { true }

    func totalCount() async -> Int { urls.count }

    func allURLs(reason: String) async -> [URL] { urls }

    func urls(offset: Int, limit: Int, reason: String) async -> [URL] {
        guard offset < urls.count else { return [] }
        let end = min(offset + limit, urls.count)
        return Array(urls[offset..<end])
    }

    func contains(_ url: URL) async -> Bool {
        urls.contains(url)
    }

    func delete(urls: [URL], verbose: Bool) async throws {}

    func sync(urls: [URL], verbose: Bool, isFirst: Bool) async {}

    func sort(url: URL?, reason: String) async {}

    func sortRandom(url: URL?, reason: String, verbose: Bool) async throws {}
}
