import Foundation
import Testing
@testable import ProviderCloudDownload

private final class MetadataItemStub: NSMetadataItem {
    var pathValue: Any?
    override func value(forAttribute key: String) -> Any? {
        key == NSMetadataItemPathKey ? pathValue : "intro.mp3"
    }
}

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
        let path = "/tmp/目录/./sub/../intro song.mp3"
        let url = URL(fileURLWithPath: path)
        let item = MetadataItemStub()
        item.pathValue = path
        #expect(CloudDownloadIdentity.key(for: item) == CloudDownloadIdentity.key(for: url))
        #expect(CloudDownloadIdentity.key(for: item) == "/tmp/目录/intro song.mp3")
    }

    @Test
    func itemWithoutValidPathNeverFallsBackToFilename() {
        let item = MetadataItemStub()
        #expect(CloudDownloadIdentity.key(for: item) == nil)
        item.pathValue = 42
        #expect(CloudDownloadIdentity.key(for: item) == nil)
        item.pathValue = URL(fileURLWithPath: "/tmp/intro.mp3")
        #expect(CloudDownloadIdentity.key(for: item) == nil)
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

    @Test
    func progressPolicyPreservesBoundsAndMonotonicityAcrossBoundaryMatrix() {
        let samples: [(value: Double, expected: Double)] = [
            (-.infinity, 0), (.nan, 0), (.infinity, 0), (-10, 0),
            (0, 0), (0.25, 0.25), (0.75, 0.75), (1, 1), (10, 1),
        ]
        for current in samples {
            #expect(CloudDownloadProgressPolicy.normalized(current.value) == current.expected)
            for incoming in samples {
                let merged = CloudDownloadProgressPolicy.merged(current: current.value, incoming: incoming.value)
                #expect(merged == max(current.expected, incoming.expected))
                #expect(merged.isFinite && (0...1).contains(merged))
                #expect(CloudDownloadProgressPolicy.merged(current: merged, incoming: incoming.value) == merged)
            }
        }
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
    func serviceForwardsEventsToSubscribersUntilCancelled() {
        let service = CloudDownloadService()
        let url = URL(fileURLWithPath: "/tmp/目录/intro.mp3")
        var received: [Double] = []
        var otherReceived: [Double] = []
        let handle = service.addObserver { event in
            if case let .progressChanged(eventURL, progress) = event {
                #expect(eventURL == url)
                received.append(progress)
            }
        }
        let other = service.addObserver { event in
            if case let .progressChanged(eventURL, progress) = event {
                #expect(eventURL == url)
                otherReceived.append(progress)
            }
        }
        service.handle(.init(url: url, progress: 0.4))
        #expect(received == [0.4])
        handle.cancel()
        handle.cancel()
        service.handle(.init(url: url, progress: 2))
        service.handle(.init(url: url, progress: .nan))
        #expect(received == [0.4])
        #expect(otherReceived == [0.4, 1, 0])
        other.cancel()
        service.handle(.init(url: url, progress: 0.8))
        #expect(otherReceived == [0.4, 1, 0])
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