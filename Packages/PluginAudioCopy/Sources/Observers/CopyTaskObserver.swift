#if os(macOS)
import Foundation
import MagicKit

/// 复制任务事件的集中观察者（迁移 Phase 4）。
///
/// 订阅 `copyTaskCountChanged` / `copyTaskStarted` / `copyTaskFinished`
/// 通知，转发到 `CopyViewModel`；取代 `CopyStateView` 与 `CopyList`
/// 的 `.onCopyTask*` 直接订阅。
@MainActor
final class CopyTaskObserver: SuperLog {
    nonisolated static let emoji = "📋"
    nonisolated static let verbose = false

    private weak var viewModel: CopyViewModel?
    private var tokens: [NSObjectProtocol] = []

    init(viewModel: CopyViewModel) {
        self.viewModel = viewModel

        let center = NotificationCenter.default
        tokens.append(center.addObserver(forName: .copyTaskCountChanged, object: nil, queue: .main) { [weak self] notification in
            let count = notification.userInfo?["count"] as? Int ?? 0
            Task { @MainActor in self?.viewModel?.handleCopyTaskCountChanged(count) }
        })
        tokens.append(center.addObserver(forName: .copyTaskStarted, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.viewModel?.refreshTasks() }
        })
        tokens.append(center.addObserver(forName: .copyTaskFinished, object: nil, queue: .main) { [weak self] notification in
            let lastCount = notification.userInfo?["lastCount"] as? Int ?? 0
            Task { @MainActor in
                self?.viewModel?.handleCopyTaskFinished(lastCount)
                self?.viewModel?.refreshTasks()
            }
        })
    }

    func cancel() {
        tokens.forEach { NotificationCenter.default.removeObserver($0) }
        tokens.removeAll()
    }
}
#endif
