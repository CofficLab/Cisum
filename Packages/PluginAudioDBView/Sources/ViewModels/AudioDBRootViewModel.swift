import Foundation
import MagicKit

/// 音频数据库根视图的状态容器（迁移 Phase 2）。
///
/// 集中 `AudioDBRootView` 的仓库可用性检查逻辑；由插件入口持有并注入
/// `AudioDatabaseObserver`，View 只发起检查意图，不再直接读取 Repository。
@MainActor
final class AudioDBRootViewModel: ObservableObject, SuperLog {
    nonisolated static let verbose = false

    /// 音频库能力（Capabilities 目录收窄），内部惰性解析 Provider。
    private let library: any AudioLibraryCapability
    private let showDBViewAction: @MainActor () -> Void

    init(
        library: any AudioLibraryCapability,
        showDBView: @escaping @MainActor () -> Void
    ) {
        self.library = library
        self.showDBViewAction = showDBView
    }

    /// 检查仓库是否可用；**不可用**时请求显示数据库视图。
    ///
    /// ## 为什么「仓库为空」不再强制展开内容区
    ///
    /// 早期实现把「仓库为空」也当作需要展开的理由，于是每次启动都会把
    /// 内容区弹开——用户明明主动收起过内容区（那是他显式做出的选择，
    /// 并且会落盘），重启后却被悄悄改写回展开，「更多」按钮看起来像坏了。
    ///
    /// 「仓库为空」本身并不需要展开内容区：音乐库页面在空仓库时已经会
    /// 渲染空态提示。只有**仓库根本不可用**（存储位置没配好、能力缺失）
    /// 时才需要把用户带到能处理这件事的地方。
    func checkAudioRepo() async {
        guard library.isAvailable else {
            showDBViewAction()
            return
        }
    }
}
