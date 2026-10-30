import Foundation
import ProviderAudioLibrary
import Testing
@testable import PluginAudioDBView

// MARK: - 导入容量准入

/// 导入前的容量准入：低于上限时全部放行。
@MainActor
@Test func importAdmissionAdmitsAllFilesBelowLimit() async {
    let capacity = StubImportCapacity(libraryCount: 10)
    let importer = makeImporter(capacity: capacity)

    let admitted = await importer.admit(urls: sampleURLs(count: 5))
    #expect(admitted.count == 5)
}

/// 超出上限时只放行额度内的部分。
@MainActor
@Test func importAdmissionPartiallyAdmitsWhenExceedingLimit() async {
    let capacity = StubImportCapacity(libraryCount: 98)
    let importer = makeImporter(capacity: capacity)

    let admitted = await importer.admit(urls: sampleURLs(count: 5))
    #expect(admitted.count == 2)
}

/// 已满时一个都进不去——这是绕过路径的关键守卫。
@MainActor
@Test func importAdmissionRejectsEverythingWhenFull() async {
    let capacity = StubImportCapacity(libraryCount: 100)
    let importer = makeImporter(capacity: capacity)

    let admitted = await importer.admit(urls: sampleURLs(count: 3))
    #expect(admitted.isEmpty)
}

/// 付费用户不受限制。
@MainActor
@Test func importAdmissionAdmitsEverythingForPaidUser() async {
    let capacity = StubImportCapacity(libraryCount: 500, isUnlimited: true)
    let importer = makeImporter(capacity: capacity)

    let admitted = await importer.admit(urls: sampleURLs(count: 50))
    #expect(admitted.count == 50)
}

/// 撞限时必须给出购买入口——这是付费链路的断点。
@MainActor
@Test func importAdmissionPresentsPurchaseWhenLimitReached() async {
    let capacity = StubImportCapacity(libraryCount: 100)
    let purchase = PurchaseSpy()
    let importer = makeImporter(capacity: capacity, purchase: purchase)

    _ = await importer.admit(urls: sampleURLs(count: 3))
    #expect(purchase.presentCount == 1)
}

/// 未撞限时不弹购买面板。
@MainActor
@Test func importAdmissionDoesNotPresentPurchaseBelowLimit() async {
    let capacity = StubImportCapacity(libraryCount: 10)
    let purchase = PurchaseSpy()
    let importer = makeImporter(capacity: capacity, purchase: purchase)

    _ = await importer.admit(urls: sampleURLs(count: 5))
    #expect(purchase.presentCount == 0)
}

// MARK: - 测试替身

/// 容量替身：可控的仓库计数。
@MainActor
final class StubImportCapacity: AudioLibraryCapacityCapability {
    var libraryCount: Int
    var isUnlimited: Bool

    init(libraryCount: Int, isUnlimited: Bool = false) {
        self.libraryCount = libraryCount
        self.isUnlimited = isUnlimited
    }

    func admit(requestedCount: Int, reservedCount: Int) async -> AudioCapacityAdmission {
        guard !isUnlimited else { return .admitted }
        guard requestedCount > 0 else { return .admitted }

        let remaining = max(0, AudioPluginInfo.maxAudioCount - libraryCount)
        let allowed = min(requestedCount, remaining)

        if allowed == requestedCount { return .admitted }
        if allowed == 0 { return .rejected }
        return .partiallyAdmitted(allowedCount: allowed)
    }

    var isCapacityUnlimited: Bool { isUnlimited }
    var freeTierFileLimit: Int { AudioPluginInfo.maxAudioCount }
}

/// 购买呈现替身：记录被请求了几次。
@MainActor
final class PurchaseSpy: AudioPurchasePresentingCapability {
    private(set) var presentCount = 0

    func presentPurchase() {
        presentCount += 1
    }
}

// MARK: - 辅助

@MainActor
private func sampleURLs(count: Int) -> [URL] {
    (1 ... count).map { URL(fileURLWithPath: "/tmp/sample-\($0).mp3") }
}

@MainActor
private func makeImporter(
    capacity: any AudioLibraryCapacityCapability,
    purchase: any AudioPurchasePresentingCapability = PurchaseSpy()
) -> AudioRepositoryImporter {
    AudioRepositoryImporter(
        library: StubImportLibrary(),
        audioDisk: { nil },
        supportedExtensions: AudioPluginInfo.supportedExtensions,
        toast: StubImportToast(),
        capacity: capacity,
        purchase: purchase
    )
}

/// 音频库替身：导入测试不触碰真实仓库。
@MainActor
private final class StubImportLibrary: AudioLibraryCapability {
    var audioDisk: URL? { nil }
    var supportedExtensions: [String] { AudioPluginInfo.supportedExtensions }
    var isAvailable: Bool { false }

    func totalCount() async -> Int { 0 }
    func allURLs(reason: String) async -> [URL] { [] }
    func urls(offset: Int, limit: Int, reason: String) async -> [URL] { [] }
    func delete(urls: [URL], verbose: Bool) async throws {}
    func sync(urls: [URL], verbose: Bool, isFirst: Bool) async {}

    @discardableResult
    func addObserver(
        _ callback: @escaping (AudioLibraryEvent) -> Void
    ) -> any AudioLibraryObserverHandle {
        StubAudioLibraryObserverHandle()
    }
}

/// 空句柄：测试替身不派发事件。
@MainActor
private final class StubAudioLibraryObserverHandle: AudioLibraryObserverHandle {
    func cancel() {}
}

/// 提示替身：记录提示，不打扰测试输出。
@MainActor
private final class StubImportToast: AudioLibraryToastCapability {
    private(set) var errors: [String] = []
    private(set) var warnings: [String] = []

    func info(_ message: String) {}
    func error(_ message: String) { errors.append(message) }
    func warning(_ message: String) { warnings.append(message) }
}
