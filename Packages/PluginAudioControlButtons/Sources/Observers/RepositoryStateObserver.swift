import MagicKit
import os

/// 订阅仓库空/非空状态，并把结论回写给 ViewModel。
///
/// 引导挂在「⋯」按钮上，所以结论只有一位：仓库是否为空。
@MainActor
final class RepositoryStateObserver: SuperLog {
    nonisolated static let emoji = "📦"
    nonisolated static let verbose = false
    private static let log = Logger(subsystem: "com.yueyi.cisum", category: "ControlButtons.Repository")

    private weak var viewModel: ControlButtonsViewModel?
    private var handle: (any RepositoryStateObserverHandle)?

    init(
        repository: any RepositoryStateCapability,
        viewModel: ControlButtonsViewModel
    ) {
        self.viewModel = viewModel
        // 先同步一次当前结论：Provider 若已确认仓库为空，订阅时会立即补发事件，
        // 这里仍以能力自身的状态为准，避免出现「先亮后灭」的一次闪烁。
        viewModel.applyRepositoryState(repository.isEmpty ? .empty : .filled)

        handle = repository.addObserver { [weak self] event in
            guard let self else {
                Self.log.error("\(Self.t)❌ Repository event dropped: observer was released")
                return
            }
            if Self.verbose {
                Self.log.info("\(Self.t)📥 Repository state changed: \(String(describing: event))")
            }
            self.viewModel?.applyRepositoryState(event)
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
