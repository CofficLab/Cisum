import Foundation

/// 音乐库骨架屏对应的**真实加载阶段**。
///
/// 骨架屏只在「正在加载且列表还没有内容」时出现，但这段时间里后台做的事
/// 并不相同：首次打开曲库是在建数据库连接、读第一页；同步阶段是在把目录
/// 扫描结果写进索引；曲库变化后则只是重新读取列表。提示文案必须按阶段
/// 区分，否则用户无法判断「正在正常干活」还是「卡住了」。
enum AudioLibraryLoadingPhase: Equatable, Sendable {
    /// 首次进入、或存储位置切换后重新打开曲库：打开本地数据库并读取第一页。
    case openingLibrary
    /// 数据层正在把目录扫描结果写入曲库索引（`syncing` → `synced`）。
    case syncingRepository
    /// 曲库刚发生变化（新增 / 删除 / 排序完成），正在重新读取列表。
    case reloadingLibrary
}

/// 骨架屏提示的等待等级：等待越久，提示越具体、越可操作。
enum AudioLibraryLoadingHintLevel: Equatable, Sendable {
    /// 正常等待，只说明正在做什么。
    case normal
    /// 已超过常见耗时，补充「为什么可能更久」。
    case slow
    /// 长时间没有进展，给出可操作的排查与重试入口。
    case stalled

    /// 超过 15 秒视为「比常见情况慢」，超过 60 秒视为「可能卡住」。
    ///
    /// 60 秒来自历史观测：库同步偶发超过 60 秒仍未完成，此时只报「加载中」
    /// 会让用户以为应用已经失去响应。
    static func level(forElapsedSeconds seconds: Int) -> AudioLibraryLoadingHintLevel {
        if seconds >= 60 { return .stalled }
        if seconds >= 15 { return .slow }
        return .normal
    }
}
