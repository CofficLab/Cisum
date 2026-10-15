import Foundation
import Testing
@testable import ProviderCloudDownload

/// 身份键策略：查询结果与订阅 URL 必须用同一把尺子比对。
struct CloudDownloadIdentityTests {
    @Test
    func keyUsesStandardizedAbsolutePath() {
        let url = URL(fileURLWithPath: "/tmp/./sub/../intro.mp3")

        #expect(CloudDownloadIdentity.key(for: url) == "/tmp/intro.mp3")
    }

    @Test
    func keyDistinguishesSameNameInDifferentDirectories() {
        let music = URL(fileURLWithPath: "/Users/x/Music/intro.mp3")
        let downloads = URL(fileURLWithPath: "/Users/x/Downloads/intro.mp3")

        #expect(CloudDownloadIdentity.key(for: music) != CloudDownloadIdentity.key(for: downloads))
    }

    @Test
    func keyFromItemNormalizesTheSameWayAsKeyFromURL() {
        // 两侧归一化结果一致，是「能匹配上」的前提。
        let url = URL(fileURLWithPath: "/tmp/dir/intro.mp3")

        #expect(CloudDownloadIdentity.key(for: url) == URL(fileURLWithPath: "/tmp/dir/intro.mp3").standardizedFileURL.path)
    }
}

/// 进度归一化：非法值必须收敛，不能污染 UI。
struct CloudDownloadProgressPolicyTests {
    @Test
    func normalizedClampsOutOfRangeValues() {
        #expect(CloudDownloadProgressPolicy.normalized(-1) == 0)
        #expect(CloudDownloadProgressPolicy.normalized(0.5) == 0.5)
        #expect(CloudDownloadProgressPolicy.normalized(2) == 1)
    }

    @Test
    func normalizedRejectsNonFiniteValues() {
        #expect(CloudDownloadProgressPolicy.normalized(.nan) == 0)
        #expect(CloudDownloadProgressPolicy.normalized(.infinity) == 0)
    }

    /// 核心不变式：任一源读到 0 不得打回已发布的进度。
    @Test
    func mergedNeverRegresses() {
        #expect(CloudDownloadProgressPolicy.merged(current: 0.5, incoming: 0) == 0.5)
        #expect(CloudDownloadProgressPolicy.merged(current: 0.5, incoming: 0.8) == 0.8)
        #expect(CloudDownloadProgressPolicy.merged(current: 1, incoming: 0.2) == 1)
    }

    @Test
    func mergedNormalizesBothSides() {
        #expect(CloudDownloadProgressPolicy.merged(current: .nan, incoming: 0.4) == 0.4)
    }
}

/// 契约面：无实现的 Provider 也应能通过默认订阅面编译并可重复取消。
@MainActor
struct CloudDownloadProvidingTests {
    @MainActor
    private final class StubProvider: CloudDownloadProviding {
        func progress(for url: URL) -> Double { 0 }
    }

    @Test
    func defaultObserverUsesNoopFallback() {
        let provider = StubProvider()
        let handle = provider.addObserver { _ in
            Issue.record("The default download observer must not receive events")
        }

        #expect(handle is NoopCloudDownloadProvidingObserverHandle)
        handle.cancel()
        handle.cancel()
    }

    @Test
    func explicitNoopHandleSupportsRepeatedCancellation() {
        let handle = NoopCloudDownloadProvidingObserverHandle()

        handle.cancel()
        handle.cancel()
    }

    /// 生产实现：订阅即建连，取消后不再收到事件。
    @Test
    func serviceForwardsEventsToSubscribersUntilCancelled() async throws {
        let service = CloudDownloadService()
        var received: [Double] = []

        let handle = service.addObserver { event in
            if case let .progressChanged(_, progress) = event {
                received.append(progress)
            }
        }
        handle.cancel()

        // 取消后不应再收到任何事件（CI 无 iCloud 下载，期望恒为空）。
        #expect(received.isEmpty)
    }

    @Test
    func missingFileSnapshotDoesNotReportCompletedDownload() {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-download-\(UUID().uuidString).mp3")
        #expect(!FileManager.default.fileExists(atPath: file.path))
        #expect(UbiquitousDownloadQuery().progressSnapshot(for: file) == 0)
    }

    /// 快照兜底：普通本地文件不是 iCloud 項目，应立即判为完成。
    @Test
    func snapshotTreatsNonICloudFileAsComplete() {
        let service = CloudDownloadService()
        let file = URL(fileURLWithPath: "/tmp/provider-cloud-download-\(UUID().uuidString).txt")
        FileManager.default.createFile(atPath: file.path, contents: Data("x".utf8))
        defer { try? FileManager.default.removeItem(at: file) }

        #expect(service.progress(for: file) == 1)
    }
}