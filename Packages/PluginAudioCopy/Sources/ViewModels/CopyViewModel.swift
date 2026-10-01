#if os(macOS)
import Combine
import Foundation
import MagicKit
import OSLog
import ProviderToast
import SwiftData
import SwiftUI

/// 复制任务状态的集中容器（迁移 Phase 4）。
///
/// 统一持有 `CopyStateView`（任务计数/失败数/详情弹窗）与 `CopyList`
/// （任务列表/选中/删除）的状态，取代两个 View 各自的 `@State` 与
/// `.onCopyTask*` 直接订阅。由 `AudioCopyService` 静态持有并共享。
@MainActor
final class CopyViewModel: ObservableObject, SuperLog {
    // CopyStateView 状态
    @Published var showCopying = false
    @Published private(set) var taskCount: Int = 0
    @Published private(set) var pendingCount: Int = 0
    @Published private(set) var failedCount: Int = 0

    // CopyList 状态
    @Published var selection: PersistentIdentifier?
    @Published private(set) var tasks: [CopyTask] = []

    private static let verbose = false
    private let toastProvider: (any ToastProviding)?

    init(toastProvider: (any ToastProviding)? = nil) {
        self.toastProvider = toastProvider
    }

    /// 是否应该显示状态视图
    var shouldShow: Bool {
        taskCount > 0
    }

    // MARK: - CopyStateView handlers

    func handleAppear() {
        Task { @MainActor in
            let tasks = await refreshTaskCounts()

            guard tasks.contains(where: { $0.error.isEmpty }),
                  let worker = AudioCopyService.getWorker() else {
                return
            }

            await worker.run()
        }
    }

    func handleCopyTaskCountChanged(_ count: Int) {
        Task { @MainActor in
            let tasks = await refreshTaskCounts()
            if tasks.isEmpty, count > 0 {
                taskCount = count
                pendingCount = count
                failedCount = 0
            }
        }
    }

    func handleCopyTaskFinished(_ lastCount: Int) {
        taskCount = 0
        pendingCount = 0
        failedCount = 0
        toastProvider?.info(String(localized: "Copy completed", bundle: .module))
    }

    @discardableResult
    private func refreshTaskCounts() async -> [CopyTaskDTO] {
        guard let db = AudioCopyService.getDB() else {
            taskCount = 0
            pendingCount = 0
            failedCount = 0
            return []
        }

        let tasks = await db.allCopyTaskDTOs()
        taskCount = tasks.count
        pendingCount = tasks.filter { $0.error.isEmpty }.count
        failedCount = tasks.filter { !$0.error.isEmpty }.count
        return tasks
    }

    // MARK: - CopyList handlers

    func refreshTasks(postCountChanged: Bool = false) {
        guard let container = AudioCopyService.container else {
            tasks = []
            return
        }
        tasks = CopyDB.getAllTasks(from: container)

        if postCountChanged {
            NotificationCenter.postCopyTaskCountChanged(count: tasks.count)
        }
    }

    func deleteTasks(at offsets: IndexSet) {
        guard let container = AudioCopyService.container else {
            toastProvider?.error(String(localized: "Copy service is unavailable", bundle: .module))
            return
        }

        guard let tasksToDelete = CopyList.tasksToDelete(from: offsets, in: tasks) else {
            toastProvider?.error(String(localized: "Delete failed: copy task list changed. Please try again.", bundle: .module))
            return
        }

        do {
            try CopyDB.deleteTasks(tasksToDelete, from: container)
            refreshTasks(postCountChanged: true)
        } catch {
            os_log(.error, "Delete failed: \(error.localizedDescription)")
            toastProvider?.error(String(localized: "Delete failed: \(error.localizedDescription)", bundle: .module))
        }
    }
}
#endif
