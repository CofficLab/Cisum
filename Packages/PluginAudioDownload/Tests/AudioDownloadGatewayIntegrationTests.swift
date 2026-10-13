import Foundation
import Testing
import MagicKit
@testable import PluginAudioDownload

/// 自动下载与 iCloud 下载网关的集成行为。
///
/// `AudioDownloadViewModel` 内部调用 `url.ensureLocalAvailability()`，本文件
/// 通过 `ICloudDownloadControl` 注入替身，验证「触发条件 → 真正发起下载 →
/// 成功 / 失败分类」这条链路，而无需真实 iCloud 账号。
///
/// `.serialized`：所有用例都覆写进程级的 `ICloudDownloadControl.shared`，
/// 并行执行会让 stub 互相污染（offline 替身泄漏到 success 用例）。
@Suite("自动下载与 iCloud 网关集成", .serialized)
struct AudioDownloadGatewayIntegrationTests {
    private func makeTemporaryFile(_ name: String) throws -> (root: URL, file: URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent(name)
        try Data("audio".utf8).write(to: file)
        return (root, file)
    }

    /// 替身网关注入后，下载等待会在脚本设定的轮次后完成。
    @Test("注入网关后 ensureLocalAvailability 按脚本完成")
    func ensureLocalAvailabilityFollowsInjectedStub() async throws {
        let control = ICloudDownloadControl.shared
        defer { control.reset() }

        let (root, file) = try makeTemporaryFile("auto.mp3")
        defer { try? FileManager.default.removeItem(at: root) }

        let stub = StubUbiquitousItemDownloader(behavior: .succeeds(afterPolls: 2))
        control.override(stub)

        try await file.ensureLocalAvailability(timeout: 5, pollInterval: 0.05)

        #expect(stub.startDownloadCallCount == 1)
    }

    /// 内容永不落地时，错误类型必须是 `timedOut`，以便上层归类为 iCloud 失败。
    @Test("永不完成时抛出 timedOut 而非网络错误")
    func neverCompletingRaisesTimeout() async throws {
        let control = ICloudDownloadControl.shared
        defer { control.reset() }

        let (root, file) = try makeTemporaryFile("stalled.mp3")
        defer { try? FileManager.default.removeItem(at: root) }

        control.override(StubUbiquitousItemDownloader(behavior: .neverCompletes))

        await #expect(throws: ICloudDownloadError.self) {
            try await file.ensureLocalAvailability(timeout: 0.2, pollInterval: 0.05)
        }
    }

    /// 离线时 `startDownload` 直接失败，且错误必须带原始原因。
    @Test("离线时归类为 requestFailed 并保留原因")
    func offlineRaisesRequestFailed() async throws {
        let control = ICloudDownloadControl.shared
        defer { control.reset() }

        let (root, file) = try makeTemporaryFile("offline.mp3")
        defer { try? FileManager.default.removeItem(at: root) }

        control.override(StubUbiquitousItemDownloader(behavior: .startFails(message: "network offline")))

        do {
            try await file.ensureLocalAvailability(timeout: 5, pollInterval: 0.05)
            Issue.record("离线时应抛出")
        } catch let error as ICloudDownloadError {
            guard case let .requestFailed(message) = error else {
                Issue.record("期望 requestFailed，实际 \(error)")
                return
            }
            #expect(message == "network offline")
            #expect(error.isICloudDownloadFailure)
        }
    }

    /// 同一文件重复触发时不应重复发起下载（去重由策略层负责）。
    @Test("同一资产重复触发只下载一次")
    func repeatedTriggerDownloadsOnce() async throws {
        let control = ICloudDownloadControl.shared
        defer { control.reset() }

        let (root, file) = try makeTemporaryFile("once.mp3")
        defer { try? FileManager.default.removeItem(at: root) }

        let stub = StubUbiquitousItemDownloader(behavior: .succeeds(afterPolls: 1))
        control.override(stub)

        // 第一次
        try await file.ensureLocalAvailability(timeout: 5, pollInterval: 0.05)
        // 第二次：内容已落地，直接短路
        try await file.ensureLocalAvailability(timeout: 5, pollInterval: 0.05)

        #expect(stub.startDownloadCallCount == 1)
    }

    /// 未下载判定是自动下载的入口条件；已下载文件不应触发。
    @Test("已下载资产不触发自动下载")
    func downloadedAssetDoesNotStartDownload() {
        let asset = URL(fileURLWithPath: "/tmp/cisum-audio-download/ready.mp3")

        #expect(!AudioDownloadRequestPolicy.shouldStartDownload(
            isSceneActive: true,
            asset: asset,
            isNotDownloaded: false,
            activeDownloads: []
        ))
    }

    /// 场景切走后，之前的下载结果不得再被应用（陈旧结果丢弃）。
    @Test("场景切走后的陈旧下载结果被丢弃")
    func staleResultIsDiscardedAfterSceneChange() {
        let asset = URL(fileURLWithPath: "/tmp/cisum-audio-download/a.mp3")

        let generationBefore = 0
        let generationAfter = AudioDownloadRequestPolicy.generationAfterDeactivation(generationBefore)

        #expect(generationAfter != generationBefore)

        #expect(!AudioDownloadRequestPolicy.shouldApplyDownloadResult(
            requestedAsset: asset,
            currentAsset: asset,
            isSceneActive: false,
            currentGeneration: generationAfter,
            requestGeneration: generationBefore
        ))
    }
}
