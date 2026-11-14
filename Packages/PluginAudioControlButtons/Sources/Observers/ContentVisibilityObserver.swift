import MagicKit
import os

/// 订阅内容区（音乐仓库）显隐变化，并回写给 ViewModel。
///
/// 仓库视图展开时用户已经能看到仓库的空态页面，引导这时应当收起。
@MainActor
final class ContentVisibilityObserver: SuperLog {
    nonisolated static let emoji = "👁️"
    nonisolated static let verbose = false
    private static let log = Logger(subsystem: "com.yueyi.cisum", category: "ControlButtons.Visibility")

    private weak var viewModel: ControlButtonsViewModel?
    private var handle: (any ContentVisibilityObserverHandle)?

    init(
        visibility: any ContentVisibilityCapability,
        viewModel: ControlButtonsViewModel
    ) {
        self.viewModel = viewModel
        viewModel.applyContentVisibility(visibility.isContentViewVisible)

        handle = visibility.addObserver { [weak self] visible in
            guard let self else {
                Self.log.error("\(Self.t)❌ Visibility event dropped: observer was released")
                return
            }
            if Self.verbose {
                Self.log.info("\(Self.t)📥 Content view visible: \(visible)")
            }
            self.viewModel?.applyContentVisibility(visible)
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
