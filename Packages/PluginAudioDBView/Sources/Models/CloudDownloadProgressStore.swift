import Foundation
import Combine

/// 下载进度状态容器（列表侧的单一状态源）。
///
/// 自身是 `ObservableObject`：进度环子视图直接观察**本容器**而非整个
/// `AudioListViewModel`。这样下载进度变化不会让列表本体（乃至整行）重算，
/// 也就不受 `AudioList` 上 `.equatable()` 的短路影响——这正是把进度环拆成
/// 独立子视图要解决的问题。
///
/// 只负责三件事：按身份键记录进度、提供查询、按已删除 / 已离开列表的文件清理。
/// 不持有 Provider、不发起订阅——那是 `CloudDownloadCapability` 与 Observer 的职责。
///
/// ## 为什么用字符串键而不是 `URL`
///
/// 列表里的 URL 来自数据库索引，事件里的 URL 来自 `NSMetadataQuery`，两者可能经由
/// 符号链接等路径表示同一文件。直接以 `URL` 作字典键会导致「订阅上了却查不到」，
/// 进度环永不出现。统一走 `AudioListFileIdentity.canonicalIdentity` 归一。
@MainActor
final class CloudDownloadProgressStore: ObservableObject {
    /// 文件身份 → 下载进度（`0...1`）。
    @Published private(set) var progresses: [String: Double] = [:]

    /// 是否存在正在下载（进度未完成）的条目。
    var hasActiveDownloads: Bool {
        progresses.values.contains { $0 < 1 }
    }

    /// 写入一条进度；进度单调不回退。
    ///
    /// - Returns: 值发生变化时返回 `true`，供调用方决定后续动作。
    @discardableResult
    func apply(_ url: URL, progress: Double) -> Bool {
        let key = AudioListFileIdentity.canonicalIdentity(for: url)
        let incoming = Self.clamp(progress)
        let current = progresses[key] ?? 0

        // 单调合并：快照源读到 0 时不得打回已发布的进度。
        let merged = max(current, incoming)
        guard merged > current else { return false }

        progresses[key] = merged
        return true
    }

    /// 读取某文件的进度；无记录时按 Provider 快照求值。
    ///
    /// 快照用于「事件建立订阅之前就已在下载」的条目；它不是可靠真值，
    /// 但足以避免这类条目完全不显示下载态。
    func progress(for url: URL, snapshot: () -> Double) -> Double {
        let key = AudioListFileIdentity.canonicalIdentity(for: url)
        if let stored = progresses[key] {
            return stored
        }
        return Self.clamp(snapshot())
    }

    /// 清理不再显示的文件，避免状态容器随翻页 / 删除无界增长。
    ///
    /// 只保留仍在 `activeURLs` 中的条目；调用方在列表重载或删除后传入当前可见集合。
    func retainOnly(_ activeURLs: [URL]) {
        let activeKeys = Set(activeURLs.map(AudioListFileIdentity.canonicalIdentity(for:)))
        guard progresses.keys.contains(where: { !activeKeys.contains($0) }) else { return }

        progresses = progresses.filter { activeKeys.contains($0.key) }
    }

    /// 清理已删除文件的进度。
    func remove(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        for url in urls {
            progresses.removeValue(forKey: AudioListFileIdentity.canonicalIdentity(for: url))
        }
    }

    func removeAll() {
        progresses.removeAll()
    }

    private static func clamp(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }
}