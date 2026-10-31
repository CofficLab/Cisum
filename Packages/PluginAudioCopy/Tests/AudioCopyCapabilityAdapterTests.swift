import Foundation
import ProviderAudioLibrary
import ProviderStore
import Testing
@testable import PluginAudioCopy

// MARK: - 测试替身

/// 音频库 Provider 替身（内核契约）。
@MainActor
final class StubAudioLibraryProvider: AudioLibraryProviding {
    var disk: URL?
    var count: Int

    init(disk: URL? = URL(fileURLWithPath: "/tmp/cisum-audios"), count: Int = 0) {
        self.disk = disk
        self.count = count
    }

    var audioDisk: URL? { disk }
    var supportedExtensions: [String] { ["mp3", "m4a"] }
    var isAvailable: Bool { true }
    var isRepositoryEmpty: Bool { count == 0 }

    func totalCount() async -> Int { count }
    func allURLs(reason: String) async -> [URL] { [] }
    func urls(offset: Int, limit: Int, reason: String) async -> [URL] { [] }
    func contains(_ url: URL) async -> Bool { false }
    func delete(urls: [URL], verbose: Bool) async throws {}
    func sync(urls: [URL], verbose: Bool, isFirst: Bool) async {}
    func sort(url: URL?, reason: String) async {}
    func sortRandom(url: URL?, reason: String, verbose: Bool) async throws {}
}

/// 容量 Provider 替身（内核契约）。
@MainActor
final class StubAudioCapacityProvider: AudioCapacityProviding {
    var libraryCount: Int
    var isUnlimited: Bool
    var tierName: String

    init(libraryCount: Int = 0, isUnlimited: Bool = false, tierName: String = "Free version") {
        self.libraryCount = libraryCount
        self.isUnlimited = isUnlimited
        self.tierName = tierName
    }

    var isCapacityUnlimited: Bool { isUnlimited }
    var tierDisplayName: String { tierName }

    func admit(requestedCount: Int, reservedCount: Int) async -> AudioCapacityAdmission {
        guard !isUnlimited else { return .admitted }
        guard requestedCount > 0 else { return .admitted }

        let occupied = libraryCount + max(0, reservedCount)
        let remaining = max(0, AudioPluginInfo.maxAudioCount - occupied)
        let allowed = min(requestedCount, remaining)

        if allowed == requestedCount { return .admitted }
        if allowed == 0 { return .rejected }
        return .partiallyAdmitted(allowedCount: allowed)
    }
}

/// 购买面板 Provider 替身（内核契约）。
@MainActor
final class StubStorePurchaseProvider: StorePurchasePresenting {
    private(set) var presentCount = 0

    func presentPurchase() {
        presentCount += 1
    }
}

// MARK: - 音频库能力适配器

/// 复制功能的音频库能力适配器持有**惰性解析闭包**：
/// 数据层插件的 boot 顺序不确定，复制视图贡献可能早于 Provider 注册。
@Suite("复制功能的音频库能力适配器")
@MainActor
struct AudioCopyLibraryCapabilityAdapterTests {
    @Test("Provider 就绪时透出磁盘目录与计数")
    func forwardsDiskAndCount() async {
        let library = StubAudioLibraryProvider(disk: URL(fileURLWithPath: "/tmp/audios"), count: 42)
        let adapter = AudioCopyLibraryCapabilityAdapter(resolve: { library })

        #expect(adapter.audioDisk == URL(fileURLWithPath: "/tmp/audios"))
        #expect(await adapter.totalCount() == 42)
    }

    @Test("Provider 缺失时磁盘目录为 nil")
    func missingProviderHasNoDisk() {
        let adapter = AudioCopyLibraryCapabilityAdapter(resolve: { nil })
        #expect(adapter.audioDisk == nil)
    }

    @Test("Provider 缺失时计数为 0")
    func missingProviderReportsZeroCount() async {
        let adapter = AudioCopyLibraryCapabilityAdapter(resolve: { nil })
        #expect(await adapter.totalCount() == 0)
    }

    @Test("Provider 晚注册后能力自动生效")
    func lateProviderBecomesUsable() async {
        var library: StubAudioLibraryProvider?
        let adapter = AudioCopyLibraryCapabilityAdapter(resolve: { library })

        // 注册前：退化为「无磁盘 / 0 条」。
        #expect(adapter.audioDisk == nil)
        #expect(await adapter.totalCount() == 0)

        let late = StubAudioLibraryProvider(disk: URL(fileURLWithPath: "/tmp/late"), count: 7)
        library = late

        // 每次调用都重新解析，能力自动恢复。
        #expect(adapter.audioDisk == URL(fileURLWithPath: "/tmp/late"))
        #expect(await adapter.totalCount() == 7)
    }
}

// MARK: - 容量能力适配器

/// 容量能力适配器的降级语义与数据层闸门一致：
/// **Provider 缺失时放行**（容量能力缺失是装配问题，不该让用户的文件凭空进不去）。
@Suite("复制功能的容量能力适配器")
@MainActor
struct AudioCopyCapacityCapabilityAdapterTests {
    @Test("Provider 缺失时放行全部")
    func missingProviderAdmitsEverything() async {
        let adapter = AudioCopyCapacityCapabilityAdapter(resolve: { nil })

        let admission = await adapter.admit(requestedCount: 100, reservedCount: 0)
        #expect(admission == .admitted)
        #expect(admission.didReject == false)
    }

    @Test("Provider 缺失时视为不限容量")
    func missingProviderIsUnlimited() {
        let adapter = AudioCopyCapacityCapabilityAdapter(resolve: { nil })
        #expect(adapter.isCapacityUnlimited)
    }

    @Test("Provider 缺失时显示免费档")
    func missingProviderShowsFreeTier() {
        let adapter = AudioCopyCapacityCapabilityAdapter(resolve: { nil })
        #expect(adapter.tierDisplayName == SubscriptionTier.none.displayName)
    }

    @Test("Provider 就绪时透出判定结果")
    func forwardsAdmission() async {
        let capacity = StubAudioCapacityProvider(libraryCount: AudioPluginInfo.maxAudioCount)
        let adapter = AudioCopyCapacityCapabilityAdapter(resolve: { capacity })

        let admission = await adapter.admit(requestedCount: 1, reservedCount: 0)
        #expect(admission == .rejected)
        #expect(admission.didReject)
    }

    @Test("Provider 就绪时透出档位与限额状态")
    func forwardsTierInformation() {
        let capacity = StubAudioCapacityProvider(isUnlimited: true, tierName: "Pro")
        let adapter = AudioCopyCapacityCapabilityAdapter(resolve: { capacity })

        #expect(adapter.isCapacityUnlimited)
        #expect(adapter.tierDisplayName == "Pro")
    }

    @Test("Provider 晚注册后判定自动生效")
    func lateProviderBecomesUsable() async {
        var capacity: StubAudioCapacityProvider?
        let adapter = AudioCopyCapacityCapabilityAdapter(resolve: { capacity })

        // 注册前：放行。
        #expect(await adapter.admit(requestedCount: 5, reservedCount: 0) == .admitted)

        // 数据层随后注册：判定立即生效。
        capacity = StubAudioCapacityProvider(libraryCount: AudioPluginInfo.maxAudioCount)
        #expect(await adapter.admit(requestedCount: 5, reservedCount: 0) == .rejected)
    }
}

// MARK: - 购买面板能力适配器

@Suite("复制功能的购买面板能力适配器")
@MainActor
struct AudioCopyPurchaseCapabilityAdapterTests {
    @Test("Provider 就绪时呈现购买面板")
    func forwardsPurchasePresentation() {
        let purchase = StubStorePurchaseProvider()
        let adapter = AudioCopyPurchaseCapabilityAdapter(resolve: { purchase })

        adapter.presentPurchase()
        #expect(purchase.presentCount == 1)
    }

    @Test("Provider 缺失时不崩溃")
    func missingProviderIsSafe() {
        let adapter = AudioCopyPurchaseCapabilityAdapter(resolve: { nil })
        // 不应崩溃。
        adapter.presentPurchase()
    }

    @Test("Provider 晚注册后呈现能力自动生效")
    func lateProviderBecomesUsable() {
        var purchase: StubStorePurchaseProvider?
        let adapter = AudioCopyPurchaseCapabilityAdapter(resolve: { purchase })

        // 注册前：空操作。
        adapter.presentPurchase()

        let late = StubStorePurchaseProvider()
        purchase = late

        adapter.presentPurchase()
        #expect(late.presentCount == 1)
    }
}
