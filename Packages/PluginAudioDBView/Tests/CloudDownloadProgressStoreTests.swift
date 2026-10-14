import Foundation
import Testing
@testable import PluginAudioDBView

/// 下载进度状态容器：单调合并、快照回落、身份键一致性与清理。
@MainActor
struct CloudDownloadProgressStoreTests {
    private func tempURL(_ name: String) -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("cisum-test-\(name)")
    }

    @Test
    func applyStoresProgressAndReportsChange() {
        let store = CloudDownloadProgressStore()
        let url = tempURL("a.mp3")

        #expect(store.apply(url, progress: 0.5) == true)
        #expect(store.progress(for: url) { 1 } == 0.5)
    }

    /// 核心不变式：后到的 0（快照源对 dataless 文件常读 0）不得打回进度。
    @Test
    func applyNeverRegresses() {
        let store = CloudDownloadProgressStore()
        let url = tempURL("b.mp3")

        store.apply(url, progress: 0.6)
        #expect(store.apply(url, progress: 0) == false)
        #expect(store.progress(for: url) { 1 } == 0.6)
    }

    @Test
    func applyClampsOutOfRangeAndNonFiniteValues() {
        let store = CloudDownloadProgressStore()
        let high = tempURL("c.mp3")
        store.apply(high, progress: 5)
        #expect(store.progress(for: high) { 0 } == 1)

        // 负值夹取为 0；因为初始值已是 0，视为「无变化」。
        let low = tempURL("d.mp3")
        #expect(store.apply(low, progress: -1) == false)
        #expect(store.progress(for: low) { 0 } == 0)

        // NaN 不得污染已有进度。
        let nan = tempURL("e.mp3")
        store.apply(nan, progress: 0.3)
        #expect(store.apply(nan, progress: .nan) == false)
        #expect(store.progress(for: nan) { 0 } == 0.3)
    }

    /// 无事件记录时回落到快照，使订阅建立前就在下载的条目也能显示。
    @Test
    func progressFallsBackToSnapshotWhenNoEventRecorded() {
        let store = CloudDownloadProgressStore()
        let url = tempURL("f.mp3")

        #expect(store.progress(for: url) { 0.25 } == 0.25)
        // 快照只用于兜底：有事件记录后必须以事件为准。
        store.apply(url, progress: 0.8)
        #expect(store.progress(for: url) { 0.25 } == 0.8)
    }

    @Test
    func hasActiveDownloadsOnlyWhenProgressIncomplete() {
        let store = CloudDownloadProgressStore()
        let done = tempURL("done.mp3")
        let pending = tempURL("pending.mp3")

        #expect(store.hasActiveDownloads == false)
        store.apply(done, progress: 1)
        #expect(store.hasActiveDownloads == false)
        store.apply(pending, progress: 0.4)
        #expect(store.hasActiveDownloads == true)
    }

    @Test
    func removeClearsDeletedFiles() {
        let store = CloudDownloadProgressStore()
        let a = tempURL("keep.mp3")
        let b = tempURL("gone.mp3")
        store.apply(a, progress: 0.3)
        store.apply(b, progress: 0.3)

        store.remove([b])

        #expect(store.progress(for: a) { 0 } == 0.3)
        #expect(store.progress(for: b) { 0 } == 0)
    }

    @Test
    func retainOnlyDropsEntriesNoLongerDisplayed() {
        let store = CloudDownloadProgressStore()
        let visible = tempURL("visible.mp3")
        let scrolledAway = tempURL("scrolled.mp3")
        store.apply(visible, progress: 0.5)
        store.apply(scrolledAway, progress: 0.5)

        store.retainOnly([visible])

        #expect(store.progress(for: visible) { 0 } == 0.5)
        #expect(store.progress(for: scrolledAway) { 0 } == 0)
    }

    /// 列表 URL 与事件 URL 经由不同路径表示同一文件时必须命中同一条记录。
    @Test
    func identityMatchesThroughSymbolicLink() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("cisum-symlink-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let target = directory.appendingPathComponent("real.mp3")
        try Data("x".utf8).write(to: target)
        let link = directory.appendingPathComponent("link.mp3")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        let store = CloudDownloadProgressStore()
        store.apply(target, progress: 0.42)

        #expect(store.progress(for: link) { 0 } == 0.42)
    }
}
