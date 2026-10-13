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

    /// 检查仓库是否为空；为空或无仓库时请求显示数据库视图。
    func checkAudioRepo() async {
        guard library.isAvailable else {
            showDBViewAction()
            return
        }

        let count = await library.totalCount()
        if count == 0 {
            showDBViewAction()
        }
    }
}