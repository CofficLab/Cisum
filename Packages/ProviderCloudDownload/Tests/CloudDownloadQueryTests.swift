import Foundation
import Testing
@testable import ProviderCloudDownload

/// `NSMetadataItem` 桩：按属性名返回测试给定的值。
///
/// 真机上 `NSMetadataItem` 的属性不可写，而查询结果集由系统决定，
/// 因此这里用子类覆写 `value(forAttribute:)` 把属性变成可控输入。
private final class StubMetadataItem: NSMetadataItem {
    var stubbedAttributes: [String: Any] = [:]

    override func value(forAttribute key: String) -> Any? {
        stubbedAttributes[key]
    }
}

/// `NSMetadataQuery` 桩：结果集完全由测试控制，且不触碰真实查询机制。
///
/// 真实的 iCloud 查询结果集无法注入，而本文件要验证的恰恰是
/// 「结果集 → 事件」这一段映射逻辑，故用桩替换结果集提供者。
private final class StubMetadataQuery: NSMetadataQuery {
    var stubbedResults: [NSMetadataItem] = []

    override var resultCount: Int { stubbedResults.count }

    override func result(at index: Int) -> Any { stubbedResults[index] }

    // 真实查询的更新开关只在运行中的查询上有意义，这里置空以免触碰系统状态。
    override func disableUpdates() {}
    override func enableUpdates() {}
}

/// `UbiquitousDownloadQuery` 的结果集 → 事件映射行为。
///
/// 覆盖两条主线：
/// 1. **完成信号**：条目因下载完毕离开结果集时补发 100%，且只发一次；
/// 2. **单调合并**：后到的更小百分比不得把已发布进度打回去。
struct CloudDownloadQueryHandlerTests {
    private func makeItem(path: String?, percent: Double?) -> StubMetadataItem {
        let item = StubMetadataItem()
        var attributes: [String: Any] = [:]
        if let path {
            attributes[NSMetadataItemPathKey] = path
        }
        if let percent {
            attributes[NSMetadataUbiquitousItemPercentDownloadedKey] = percent
        }
        item.stubbedAttributes = attributes
        return item
    }

    private func updateNotification(
        object: NSMetadataQuery,
        removed: [NSMetadataItem]? = nil
    ) -> Notification {
        var userInfo: [String: Any] = [:]
        if let removed {
            userInfo[NSMetadataQueryUpdateRemovedItemsKey] = removed
        }
        return Notification(
            name: .NSMetadataQueryDidUpdate,
            object: object,
            userInfo: userInfo
        )
    }

    /// 条目下载完毕离开结果集时，必须补发一次 100% 的完成信号。
    @Test
    func removedItemEmitsCompletionSignal() {
        let query = UbiquitousDownloadQuery()
        let stub = StubMetadataQuery()
        let item = makeItem(path: "/tmp/cloud/intro.mp3", percent: nil)

        var events: [UbiquitousDownloadQuery.Entry] = []
        query.handle(updateNotification(object: stub, removed: [item])) { events.append($0) }

        #expect(events.count == 1)
        let entry = events.first
        #expect(entry?.url.path == "/tmp/cloud/intro.mp3")
        #expect(entry?.progress == 1)
    }

    /// 完成信号只发一次：同一路径再次离开结果集不得重复播报。
    @Test
    func removedItemIsReportedOnlyOnce() {
        let query = UbiquitousDownloadQuery()
        let stub = StubMetadataQuery()
        let item = makeItem(path: "/tmp/cloud/intro.mp3", percent: nil)
        let notification = updateNotification(object: stub, removed: [item])

        var events: [UbiquitousDownloadQuery.Entry] = []
        query.handle(notification) { events.append($0) }
        query.handle(notification) { events.append($0) }

        #expect(events.count == 1)
    }

    /// 取不到完整路径的条目一律跳过——宁可漏推也不按文件名猜测（避免串扰）。
    @Test
    func removedItemWithoutPathIsSkipped() {
        let query = UbiquitousDownloadQuery()
        let stub = StubMetadataQuery()
        let pathless = makeItem(path: nil, percent: nil)
        let wrongType = makeItem(path: nil, percent: nil)
        wrongType.stubbedAttributes[NSMetadataItemPathKey] = 42

        var events: [UbiquitousDownloadQuery.Entry] = []
        query.handle(updateNotification(object: stub, removed: [pathless, wrongType])) {
            events.append($0)
        }

        #expect(events.isEmpty)
    }

    /// 进行中的条目按系统百分比换算成 0...1 的进度播报。
    @Test
    func inProgressItemEmitsNormalizedPercent() {
        let query = UbiquitousDownloadQuery()
        let stub = StubMetadataQuery()
        stub.stubbedResults = [makeItem(path: "/tmp/cloud/intro.mp3", percent: 42.5)]

        var events: [UbiquitousDownloadQuery.Entry] = []
        query.handle(updateNotification(object: stub)) { events.append($0) }

        #expect(events.count == 1)
        #expect(events.first?.url.path == "/tmp/cloud/intro.mp3")
        #expect(events.first?.progress == 0.425)
    }

    /// 核心不变式：后到的更小百分比不得把已发布的进度打回去。
    @Test
    func progressNeverRegressesWhenLowerPercentArrives() {
        let query = UbiquitousDownloadQuery()
        let stub = StubMetadataQuery()
        let path = "/tmp/cloud/intro.mp3"

        stub.stubbedResults = [makeItem(path: path, percent: 50)]
        var events: [UbiquitousDownloadQuery.Entry] = []
        query.handle(updateNotification(object: stub)) { events.append($0) }

        stub.stubbedResults = [makeItem(path: path, percent: 10)]
        query.handle(updateNotification(object: stub)) { events.append($0) }

        #expect(events.count == 1)
        #expect(events.first?.progress == 0.5)
    }

    /// 更高百分比仍然正常推进。
    @Test
    func higherPercentAdvancesProgress() {
        let query = UbiquitousDownloadQuery()
        let stub = StubMetadataQuery()
        let path = "/tmp/cloud/intro.mp3"

        var events: [UbiquitousDownloadQuery.Entry] = []
        stub.stubbedResults = [makeItem(path: path, percent: 20)]
        query.handle(updateNotification(object: stub)) { events.append($0) }
        stub.stubbedResults = [makeItem(path: path, percent: 80)]
        query.handle(updateNotification(object: stub)) { events.append($0) }

        #expect(events.count == 2)
        #expect(events[0].progress == 0.2)
        #expect(events[1].progress == 0.8)
    }

    /// 读不到百分比的条目不产生进度事件（百分比是必填信息）。
    @Test
    func itemWithoutPercentIsSkipped() {
        let query = UbiquitousDownloadQuery()
        let stub = StubMetadataQuery()
        stub.stubbedResults = [makeItem(path: "/tmp/cloud/intro.mp3", percent: nil)]

        var events: [UbiquitousDownloadQuery.Entry] = []
        query.handle(updateNotification(object: stub)) { events.append($0) }

        #expect(events.isEmpty)
    }

    /// 通知对象不是查询时直接忽略，不得崩溃。
    @Test
    func notificationWithForeignObjectIsIgnored() {
        let query = UbiquitousDownloadQuery()
        let notification = Notification(name: .NSMetadataQueryDidUpdate, object: NSObject())

        var events: [UbiquitousDownloadQuery.Entry] = []
        query.handle(notification) { events.append($0) }

        #expect(events.isEmpty)
    }
}

/// 快照与事件流的关系：事件是真值，快照只在初始化时兜底。
struct CloudDownloadSnapshotTests {
    private func makeItem(path: String?, percent: Double?) -> StubMetadataItem {
        let item = StubMetadataItem()
        var attributes: [String: Any] = [:]
        if let path {
            attributes[NSMetadataItemPathKey] = path
        }
        if let percent {
            attributes[NSMetadataUbiquitousItemPercentDownloadedKey] = percent
        }
        item.stubbedAttributes = attributes
        return item
    }

    /// 已推送过的进度优先于资源键快照——快照不得把真实进度打回 0。
    @Test
    func trackedProgressWinsOverResourceSnapshot() {
        let query = UbiquitousDownloadQuery()
        let stub = StubMetadataQuery()
        let file = URL(fileURLWithPath: "/tmp/cloud-snapshot-\(UUID().uuidString).mp3")
        FileManager.default.createFile(atPath: file.path, contents: Data("x".utf8))
        defer { try? FileManager.default.removeItem(at: file) }

        stub.stubbedResults = [makeItem(path: file.path, percent: 50)]
        query.handle(Notification(name: .NSMetadataQueryDidUpdate, object: stub, userInfo: nil)) { _ in }

        #expect(query.progressSnapshot(for: file) == 0.5)
    }

    /// 停止**运行中**的查询会清空已发布进度，此后快照回落到资源键读数：
    /// 本地已存在的非 iCloud 文件视为已完成。
    ///
    /// 注意：`stop()` 以 `guard isRunning` 早退，所以必须先 `start()` 才能观察到
    /// 「状态被清空」这一效果——这是实现的既有语义，此处按实现写断言。
    @Test
    func stopClearsTrackedProgressSoSnapshotFallsBackToResourceValues() {
        let query = UbiquitousDownloadQuery()
        query.start(onChange: { _ in })

        let stub = StubMetadataQuery()
        let file = URL(fileURLWithPath: "/tmp/cloud-snapshot-\(UUID().uuidString).mp3")
        FileManager.default.createFile(atPath: file.path, contents: Data("x".utf8))
        defer { try? FileManager.default.removeItem(at: file) }

        stub.stubbedResults = [makeItem(path: file.path, percent: 50)]
        query.handle(Notification(name: .NSMetadataQueryDidUpdate, object: stub, userInfo: nil)) { _ in }
        #expect(query.progressSnapshot(for: file) == 0.5)

        query.stop()

        #expect(query.progressSnapshot(for: file) == 1)
    }

    /// 未启动时 `stop()` 是空操作：已发布进度保持不变。
    @Test
    func stopBeforeStartKeepsTrackedProgress() {
        let query = UbiquitousDownloadQuery()
        let stub = StubMetadataQuery()
        let file = URL(fileURLWithPath: "/tmp/cloud-snapshot-\(UUID().uuidString).mp3")
        FileManager.default.createFile(atPath: file.path, contents: Data("x".utf8))
        defer { try? FileManager.default.removeItem(at: file) }

        stub.stubbedResults = [makeItem(path: file.path, percent: 50)]
        query.handle(Notification(name: .NSMetadataQueryDidUpdate, object: stub, userInfo: nil)) { _ in }
        #expect(query.progressSnapshot(for: file) == 0.5)

        query.stop()
        query.stop()

        #expect(query.progressSnapshot(for: file) == 0.5)
    }

    /// 查询可以「启动 → 停止 → 再启动」循环，且停止后再启动仍能重新建立跟踪。
    @Test
    func queryCanBeRestartedAfterStop() {
        let query = UbiquitousDownloadQuery()
        let stub = StubMetadataQuery()
        let file = URL(fileURLWithPath: "/tmp/cloud-snapshot-\(UUID().uuidString).mp3")
        FileManager.default.createFile(atPath: file.path, contents: Data("x".utf8))
        defer { try? FileManager.default.removeItem(at: file) }

        query.start(onChange: { _ in })
        query.stop()

        query.start(onChange: { _ in })
        defer { query.stop() }

        stub.stubbedResults = [makeItem(path: file.path, percent: 30)]
        var events: [UbiquitousDownloadQuery.Entry] = []
        query.handle(Notification(name: .NSMetadataQueryDidUpdate, object: stub, userInfo: nil)) {
            events.append($0)
        }

        #expect(events.count == 1)
        #expect(query.progressSnapshot(for: file) == 0.3)
    }
}
