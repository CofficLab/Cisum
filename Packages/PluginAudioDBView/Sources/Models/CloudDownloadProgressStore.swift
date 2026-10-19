import Foundation
import Combine

/// 下载进度状态容器（列表侧的单一状态源）。
///
/// 自身是 `ObservableObject`：进度环子视图直接观察**本容器**而非整个
/// `AudioListViewModel`。这样下载进度变化不会让列表本体（乃至整行）重算，
/// 也就不受 `AudioList` 上 `.equatable()` 的短路影响——这正是把进度环拆成
/// 独立子视图要解决的问题。
///
/// 只负责三件事：按身份键记录进度、提供查询、清理已删除文件的记录。
/// 不持有 Provider、不发起订阅——那是 `CloudDownloadCapability` 与 Observer 的职责。
///
/// ## 为什么用字符串键而不是 `URL`
///
/// 列表里的 URL 来自数据库索引，事件里的 URL 来自 `NSMetadataQuery`，两者可能经由
/// 符号链接等路径表示同一文件。直接以 `URL` 作字典键会导致「订阅上了却查不到」，
/// 进度环永不出现。统一走 `AudioListFileIdentity.canonicalIdentity` 归一。
///
/// ## 所有权：这是文件的状态，不是列表的状态
///
/// 记录一条进度的前提是「这个文件正在下载」，与它当前是否被列表显示**无关**。
/// 因此本容器的条目只随两件事消亡：
///
/// 1. 文件被删除——由 `AudioDatabaseObserver` 的删除事件驱动 `remove(_:)`。
/// 2. 本进程生命周期结束。
///
/// 列表刷新（翻页、数据库 `synced`/`updated`、排序）**无权**清空它。那类调用
/// 过去用的是 `removeAll()`，等价于宣称「刷新之后我对世界上所有文件一无所知」，
/// 于是下载域被迫重新播报已经报过的进度：进度环刚出现就被抹掉，等下一条事件
/// 再出现——表现为「闪一下进度又退回未下载图标」的循环。
///
/// 同理这里没有 `retainOnly(_:)` 一类的「按可见集合裁剪」原语：容器的键只来自
/// iCloud 主动推送的下载事件，规模是 O(本次会话内下载过的文件数)，与列表长度
/// 无关，不存在需要裁剪的无界增长。
@MainActor
final class CloudDownloadProgressStore: ObservableObject {
    /// 文件身份 → 下载进度（`0...1`）。
    @Published private(set) var progresses: [String: Double] = [:]

    /// 文件身份 → 下载完成次数。
    ///
    /// 每次进度抵达 `1.0` 递增一次，用于驱动缩略图重载：iCloud 文件下载完成后内容才
    /// 真正落到本地，此前读到的封面是占位或空。按**次数**而非布尔值计数，是因为文件
    /// 可能被「优化 Mac 存储」再次驱逐并重新下载。
    @Published private(set) var completionTokens: [String: Int] = [:]

    /// 某文件的缩略图重载标记；未下载完成过为 `0`。
    ///
    /// 视图把它拼进 `AvatarView` 的 `.id(...)`：完成一次即换新 id，强制重建并重新
    /// 加载缩略图，取代 kit 内部 `needsReload` 的作用。
    func reloadToken(for url: URL) -> Int {
        completionTokens[AudioListFileIdentity.canonicalIdentity(for: url)] ?? 0
    }

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
        // 首次抵达完成时递增重载标记；重复的 1.0（removed 事件可能补发）不重复计数。
        if merged >= 1 {
            completionTokens[key] = (completionTokens[key] ?? 0) + 1
        }
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

    /// 清理已删除文件的进度与重载标记。
    ///
    /// 这是**唯一**的单条清理入口：删除事件由 `AudioDatabaseObserver` 转发而来，
    /// 是外部世界明确告知「这个文件不复存在」的信号。
    func remove(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        for url in urls {
            let key = AudioListFileIdentity.canonicalIdentity(for: url)
            progresses.removeValue(forKey: key)
            completionTokens.removeValue(forKey: key)
        }
    }

    /// 全量清空。
    ///
    /// 仅供存储位置切换、插件重装这类**文件身份本身失效**的场景使用——
    /// 此时旧路径下的记录已指向不存在的对象。列表刷新绝不应走这里。
    func removeAll() {
        progresses.removeAll()
        completionTokens.removeAll()
    }

    private static func clamp(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }
}