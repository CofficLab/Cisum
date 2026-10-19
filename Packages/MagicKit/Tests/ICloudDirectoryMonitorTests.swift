import Foundation
import Testing

@testable import MagicKit

@Test func iCloudDirectoryMonitorLifecycleSuppressesCancelledDelayedStart() {
    let lifecycle = ICloudDirectoryMonitorLifecycle()
    let cancelledRun = lifecycle.beginRun()

    #expect(lifecycle.shouldStart(runID: cancelledRun))
    #expect(lifecycle.cancel(runID: cancelledRun))
    #expect(!lifecycle.shouldStart(runID: cancelledRun))
}

@Test func iCloudDirectoryMonitorLifecycleKeepsReplacementRunAfterStaleCancel() {
    let lifecycle = ICloudDirectoryMonitorLifecycle()
    let staleRun = lifecycle.beginRun()
    let replacementRun = lifecycle.beginRun()

    #expect(!lifecycle.cancel(runID: staleRun))
    #expect(!lifecycle.shouldStart(runID: staleRun))
    #expect(lifecycle.shouldStart(runID: replacementRun))
}

@Test func iCloudDirectoryMonitorDirectScanEnumeratesNestedPlaceholderLikeFiles() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("cisum-icloud-monitor-\(UUID().uuidString)", isDirectory: true)
    let nested = root.appendingPathComponent("book", isDirectory: true)
    let audio = nested.appendingPathComponent("chapter.mp3")
    defer { try? FileManager.default.removeItem(at: root) }

    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    try Data("placeholder metadata".utf8).write(to: audio)

    let urls = try ICloudDirectoryMonitor.scanDirectoryContents(at: root)
    let identities = Set(urls.map { $0.resolvingSymlinksInPath().standardizedFileURL.path })

    #expect(identities.contains(nested.resolvingSymlinksInPath().standardizedFileURL.path))
    #expect(identities.contains(audio.resolvingSymlinksInPath().standardizedFileURL.path))
}

@Test func iCloudDirectoryMonitorDirectScanAcceptsAReadableEmptyDirectory() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("cisum-icloud-monitor-empty-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

    #expect(try ICloudDirectoryMonitor.scanDirectoryContents(at: root).isEmpty)
}

@Test func iCloudDirectoryMonitorDoesNotAcceptAnEmptySnapshotForNonemptyDirectory() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("cisum-icloud-monitor-incomplete-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data("visible entry".utf8).write(to: root.appendingPathComponent("track.mp3"))

    #expect(throws: (any Error).self) {
        try ICloudDirectoryMonitor.validateDirectoryScanResult([], at: root)
    }
}

// MARK: - IdentityLedger

/// 「成员变化 vs 物化进度变化」的判别依据。
///
/// 这是进度环闪烁的治本处：`NSMetadataQuery` 每次推送下载百分比都会把该文件
/// 放进 `changedItems`，若原样透传给库同步，下载期间就会以百分比频率反复全量重扫。
/// 判据是「这个路径我们此前没见过吗」。
@Suite("iCloud 目录监控：成员变化判别")
struct ICloudDirectoryMonitorIdentityLedgerTests {
    typealias Ledger = ICloudDirectoryMonitor.IdentityLedger

    @Test
    func knownPathsAreNeverReportedAsMembershipChanges() {
        let ledger = Ledger()
        ledger.reset(to: ["/music/a.wav", "/music/b.wav"])

        // 这正是下载期间反复出现的那一类：路径早已在基线里，只是百分比在变。
        #expect(ledger.insertNew(["/music/a.wav"]) == [])
        #expect(ledger.insertNew(["/music/a.wav"]) == [])
        #expect(ledger.count == 2)
    }

    /// 核心回归：下载中文件反复推百分比，不得被判为新增（否则触发全量重扫）。
    @Test
    func repeatedDownloadProgressUpdatesProduceNoMembershipChanges() {
        let ledger = Ledger()
        let downloading = "/music/large.wav"
        ledger.reset(to: [downloading])

        // 模拟 0%→12%→47%→100% 的连续推送。
        var updates: [[String]] = []
        for _ in 0..<4 {
            updates.append(ledger.insertNew([downloading]))
        }

        #expect(updates.allSatisfy { $0.isEmpty })
        #expect(ledger.count == 1)
    }

    @Test
    func genuinelyNewFileIsReportedOnceThenNotAgain() {
        let ledger = Ledger()
        ledger.reset(to: ["/music/a.wav"])

        #expect(ledger.insertNew(["/music/new.wav"]) == ["/music/new.wav"])
        // 同一路径的后续更新只是物化进度，不再算成员变化。
        #expect(ledger.insertNew(["/music/new.wav"]) == [])
        #expect(ledger.count == 2)
    }

    /// 混合批次：新文件与已知文件同时到达，只有新文件该被上报。
    @Test
    func mixedBatchSeparatesNewFromKnownMembers() {
        let ledger = Ledger()
        ledger.reset(to: ["/music/a.wav", "/music/b.wav"])

        let fresh = ledger.insertNew([
            "/music/a.wav",   // 已知：下载进度更新
            "/music/c.wav",   // 新增：成员变化
            "/music/b.wav"    // 已知：下载进度更新
        ])

        #expect(fresh == ["/music/c.wav"])
    }

    /// 同一批内重复出现同一路径，只能算一次新成员。
    @Test
    func duplicatePathsWithinOneBatchCountOnce() {
        let ledger = Ledger()
        ledger.reset(to: [])

        #expect(ledger.insertNew(["/music/x.wav", "/music/x.wav"]) == ["/music/x.wav"])
        #expect(ledger.count == 1)
    }

    /// 重命名会改变路径，因此在判据上等价于「旧路径消失 + 新路径出现」——
    /// 新路径应被判为成员变化，否则重命名后的文件不会触发入库。
    @Test
    func renameCountsAsMembershipChangeBecausePathChanges() {
        let ledger = Ledger()
        ledger.reset(to: ["/music/old.wav"])

        #expect(ledger.insertNew(["/music/old.wav"]) == [])
        #expect(ledger.insertNew(["/music/new.wav"]) == ["/music/new.wav"])
    }

    /// 空批次不得改变基线。
    @Test
    func emptyBatchLeavesLedgerUntouched() {
        let ledger = Ledger()
        ledger.reset(to: ["/music/a.wav"])

        #expect(ledger.insertNew([]) == [])
        #expect(ledger.count == 1)
    }

    /// 删除不会让路径重新变成「新成员」——基线只增不减，除非显式重置。
    ///
    /// 否则「删除后重新加入同名文件」可能不被识别。显式 `reset(to:)` 是唯一
    /// 让基线跟随目录快照收敛的入口，因此这个语义必须被锁定。
    @Test
    func baselineOnlyShrinksThroughExplicitReset() {
        let ledger = Ledger()
        ledger.reset(to: ["/music/a.wav", "/music/b.wav"])
        ledger.insertNew([])

        #expect(ledger.count == 2)

        ledger.reset(to: ["/music/b.wav"])
        #expect(ledger.count == 1)
        // 重新出现的 a.wav 是真的新增，必须能被发现。
        #expect(ledger.insertNew(["/music/a.wav"]) == ["/music/a.wav"])
    }

    /// 基线与插入并发：ledger 被后台队列与初始扫描同时触碰。
    @Test
    func concurrentInsertAndResetStayConsistent() async {
        let ledger = Ledger()
        ledger.reset(to: ["/music/a.wav"])

        await withTaskGroup(of: Void.self) { group in
            for index in 0..<50 {
                group.addTask {
                    ledger.insertNew(["/music/a.wav", "/music/new-\(index).wav"])
                }
            }
            group.addTask {
                ledger.reset(to: ["/music/a.wav"])
            }
        }

        // 无论交错顺序如何，已知路径都不会被重复计为新成员。
        #expect(ledger.count >= 1)
    }
}
