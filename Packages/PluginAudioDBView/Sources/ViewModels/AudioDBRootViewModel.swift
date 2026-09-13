import Foundation
import ProviderAudioLibrary
import MagicKit

/// 音频数据库根视图的状态容器（迁移 Phase 2）。
///
/// 集中 `AudioDBRootView` 的仓库可用性检查逻辑；由插件入口持有并注入
/// `AudioDatabaseObserver`，View 只发起检查意图，不再直接读取 Repository。
@MainActor
final class AudioDBRootViewModel: ObservableObject, SuperLog {
    nonisolated static let verbose = false

    private let audioLibraryProvider: @MainActor () -> (any AudioLibraryProviding)?
    private let showDBViewAction: @MainActor () -> Void

    init(
        audioLibrary: @escaping @MainActor () -> (any AudioLibraryProviding)?,
        showDBView: @escaping @MainActor () -> Void
    ) {
        self.audioLibraryProvider = audioLibrary
        self.showDBViewAction = showDBView
    }

    /// 检查仓库是否为空；为空或无仓库时请求显示数据库视图。
    func checkAudioRepo() async {
        guard let library = audioLibraryProvider() else {
            showDBViewAction()
            return
        }

        let count = await library.totalCount()
        if count == 0 {
            showDBViewAction()
        }
    }
}
