import Foundation
import ProviderAudioLibrary
import Testing
@testable import PluginAudioDBData

// MARK: - 容量准入判定

/// 容量闸门：把「仓库计数 + 占用数 + 权益」合成放行数量。
///
/// 这是唯一一处额度规则的实现，测试直接守住它。
@MainActor
@Test func capacityGateAdmitsEverythingWhenBelowLimit() async {
    let gate = makeCapacityGate(libraryCount: 10, isCapacityLimited: true)

    let admission = await gate.admit(requestedCount: 5, reservedCount: 0)
    #expect(admission == .admitted)
    #expect(admission.didReject == false)
    #expect(admission.allowedCount(requestedCount: 5) == 5)
}

/// 恰好用满额度：仍然全部放行（上限是「最多 N 个」，不是「少于 N 个」）。
@MainActor
@Test func capacityGateAdmitsUpToExactlyTheLimit() async {
    let gate = makeCapacityGate(libraryCount: 95, isCapacityLimited: true)

    let admission = await gate.admit(requestedCount: 5, reservedCount: 0)
    #expect(admission == .admitted)
    #expect(admission.didReject == false)
}

/// 超出额度：部分放行，被挡住的部分进不去。
@MainActor
@Test func capacityGatePartiallyAdmitsWhenExceedingLimit() async {
    let gate = makeCapacityGate(libraryCount: 98, isCapacityLimited: true)

    let admission = await gate.admit(requestedCount: 5, reservedCount: 0)
    #expect(admission == .partiallyAdmitted(allowedCount: 2))
    #expect(admission.didReject == true)
    #expect(admission.allowedCount(requestedCount: 5) == 2)
}

/// 已满：一个都进不去。
@MainActor
@Test func capacityGateRejectsWhenFull() async {
    let gate = makeCapacityGate(libraryCount: 100, isCapacityLimited: true)

    let admission = await gate.admit(requestedCount: 3, reservedCount: 0)
    #expect(admission == .rejected)
    #expect(admission.didReject == true)
    #expect(admission.allowedCount(requestedCount: 3) == 0)
}

/// 付费用户不受容量限制——这是付费要换来的东西。
@MainActor
@Test func capacityGateAdmitsEverythingForPaidUser() async {
    let gate = makeCapacityGate(libraryCount: 500, isCapacityLimited: false)

    #expect(gate.isCapacityUnlimited == true)

    let admission = await gate.admit(requestedCount: 100, reservedCount: 0)
    #expect(admission == .admitted)
    #expect(admission.didReject == false)
}

/// 进行中的写入已经占了位：不计入它们，连续两次拖放会双双放行导致超限。
@MainActor
@Test func capacityGateCountsReservedSlotsAgainstTheLimit() async {
    // 仓库 99 个 + 1 个进行中 = 100，已满。
    let gate = makeCapacityGate(libraryCount: 99, isCapacityLimited: true)

    let admission = await gate.admit(requestedCount: 10, reservedCount: 1)
    #expect(admission == .rejected)
    #expect(admission.didReject == true)
}

/// 请求 0 个文件：不构成任何拒绝。
@MainActor
@Test func capacityGateTreatsEmptyRequestAsAdmitted() async {
    let gate = makeCapacityGate(libraryCount: 100, isCapacityLimited: true)

    let admission = await gate.admit(requestedCount: 0, reservedCount: 0)
    #expect(admission == .admitted)
    #expect(admission.didReject == false)
}

// MARK: - 同步兜底

/// 同步兜底：超限的新文件不进索引，但已存量的文件不受影响。
@MainActor
@Test func syncCapacityGuardKeepsExistingFilesAndBlocksNewOnes() {
    let urls = (1 ... 10).map { URL(fileURLWithPath: "/tmp/\($0).mp3") }

    // 已有 98 个，上限 100 → 还能进 2 个。
    let admitted = AudioSyncCapacityGuard.admittedURLs(
        urls: urls,
        existingCount: 98,
        fileLimit: 100
    )
    #expect(admitted.count == 2)
    #expect(admitted == Array(urls.prefix(2)))
}

/// 不限容量（付费用户）：全部放行。
@MainActor
@Test func syncCapacityGuardAdmitsEverythingWhenUnlimited() {
    let urls = (1 ... 10).map { URL(fileURLWithPath: "/tmp/\($0).mp3") }

    let admitted = AudioSyncCapacityGuard.admittedURLs(
        urls: urls,
        existingCount: 100,
        fileLimit: nil
    )
    #expect(admitted.count == 10)
}

/// 额度充足：全部放行。
@MainActor
@Test func syncCapacityGuardAdmitsEverythingWhenBelowLimit() {
    let urls = (1 ... 10).map { URL(fileURLWithPath: "/tmp/\($0).mp3") }

    let admitted = AudioSyncCapacityGuard.admittedURLs(
        urls: urls,
        existingCount: 0,
        fileLimit: 100
    )
    #expect(admitted.count == 10)
}

/// 兜底**只挡新增、不动存量**：超限的文件被挡在索引外，但不会导致
/// 已有记录被误删——存量是用户已拥有的内容。
@MainActor
@Test func syncCapacityGuardNeverRemovesAlreadyIndexedFiles() {
    let urls = (1 ... 10).map { URL(fileURLWithPath: "/tmp/\($0).mp3") }

    // 已有 150 个（付费后扩容或历史遗留），上限 100：没有新额度，
    // 但兜底只返回「不进索引的新增数」，存量由 sync 的删除分支自行处理。
    let admitted = AudioSyncCapacityGuard.admittedURLs(
        urls: urls,
        existingCount: 150,
        fileLimit: 100
    )
    #expect(admitted.isEmpty)
}

// MARK: - 测试替身

/// 音频库替身：只提供容量判定需要的计数。
@MainActor
private final class StubAudioLibrary: AudioLibraryProviding {
    var libraryCount: Int

    init(libraryCount: Int) {
        self.libraryCount = libraryCount
    }

    var audioDisk: URL? { nil }
    var supportedExtensions: [String] { [] }
    var isAvailable: Bool { true }

    func totalCount() async -> Int { libraryCount }
    func allURLs(reason: String) async -> [URL] { [] }
    func urls(offset: Int, limit: Int, reason: String) async -> [URL] { [] }
    func contains(_ url: URL) async -> Bool { false }
    func delete(urls: [URL], verbose: Bool) async throws {}
    func sync(urls: [URL], verbose: Bool, isFirst: Bool) async {}
    func sort(url: URL?, reason: String) async {}
    func sortRandom(url: URL?, reason: String, verbose: Bool) async throws {}
}

/// 权益替身：只回答「是否受容量限制」。
@MainActor
private final class StubEntitlement: AudioDataEntitlementCapability {
    var isCapacityLimited: Bool
    var tierDisplayName: String

    init(isCapacityLimited: Bool, tierDisplayName: String = "Free version") {
        self.isCapacityLimited = isCapacityLimited
        self.tierDisplayName = tierDisplayName
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (AudioDataEntitlementEvent) -> Void
    ) -> any AudioDataEntitlementObserverHandle {
        NoopAudioDataEntitlementHandle()
    }
}

/// 空句柄：测试替身不派发事件。
@MainActor
private final class NoopAudioDataEntitlementHandle: AudioDataEntitlementObserverHandle {
    func cancel() {}
}

@MainActor
private func makeCapacityGate(
    libraryCount: Int,
    isCapacityLimited: Bool
) -> AudioCapacityProvider {
    AudioCapacityProvider(
        library: StubAudioLibrary(libraryCount: libraryCount),
        entitlement: StubEntitlement(isCapacityLimited: isCapacityLimited)
    )
}
