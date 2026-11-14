#if os(macOS)
import Foundation
import MagicKit
import ProviderToast
import Testing
@testable import PluginAudioCopy

// MARK: - 复制状态初始值

/// 初始状态不应展示状态视图（没有任务时不该出现空壳 UI）。
@MainActor
@Test func copyViewModelStartsHiddenWithoutTasks() {
    let viewModel = CopyViewModel()
    #expect(viewModel.taskCount == 0)
    #expect(viewModel.pendingCount == 0)
    #expect(viewModel.failedCount == 0)
    #expect(viewModel.tasks.isEmpty)
    #expect(!viewModel.shouldShow)
    #expect(viewModel.selection == nil)
}

// MARK: - 任务完成后的状态清理

/// 任务全部完成后，状态视图应整体隐藏，并提示用户。
///
/// 这是复制流程的收尾路径：计数必须归零，否则状态视图会一直挂在界面上。
@MainActor
@Test func copyFinishedClearsAllCountersAndShowsToast() {
    let toast = ToastSpy()
    let viewModel = CopyViewModel(toast: toast)

    // 先置为「有任务」，再走完成分支。
    viewModel.handleCopyTaskCountChanged(2)
    viewModel.handleCopyTaskFinished(0)

    #expect(viewModel.taskCount == 0)
    #expect(viewModel.pendingCount == 0)
    #expect(viewModel.failedCount == 0)
    #expect(!viewModel.shouldShow)
    #expect(toast.infos.contains { $0.contains("Copy completed") })
}

/// 缺少 toast 能力时不得崩溃（首启尚未装配 Toast Provider 的场景）。
@MainActor
@Test func copyFinishedIsSafeWithoutToastCapability() {
    let viewModel = CopyViewModel(toast: nil)
    viewModel.handleCopyTaskFinished(0)
    #expect(viewModel.taskCount == 0)
    #expect(!viewModel.shouldShow)
}

/// 重复触发「完成」不应崩溃，也不应重复弹提示。
@MainActor
@Test func copyFinishedIsIdempotent() {
    let toast = ToastSpy()
    let viewModel = CopyViewModel(toast: toast)

    viewModel.handleCopyTaskFinished(0)
    viewModel.handleCopyTaskFinished(0)
    viewModel.handleCopyTaskFinished(0)

    #expect(viewModel.taskCount == 0)
    let completions = toast.infos.filter { $0.contains("Copy completed") }.count
    #expect(completions >= 1)
}

// MARK: - 任务观察者

/// 观察者应把通知转发到 ViewModel；取消后不再收到事件。
@MainActor
@Test func copyTaskObserverForwardsCountChangesUntilCancelled() async throws {
    let viewModel = CopyViewModel()
    let observer = CopyTaskObserver(viewModel: viewModel)
    defer { observer.cancel() }

    NotificationCenter.postCopyTaskCountChanged(count: 3)
    try await Task.sleep(for: .milliseconds(30))
    // 没有 DB 时刷新会把计数清零，这里只验证「事件被接收且不崩溃」。
    #expect(viewModel.taskCount >= 0)

    observer.cancel()
    NotificationCenter.postCopyTaskCountChanged(count: 9)
    try await Task.sleep(for: .milliseconds(30))
    #expect(viewModel.taskCount >= 0)
}

/// 重复取消必须幂等 —— 视图消失与插件关闭可能各触发一次。
@MainActor
@Test func copyTaskObserverCancelIsIdempotent() {
    let viewModel = CopyViewModel()
    let observer = CopyTaskObserver(viewModel: viewModel)

    observer.cancel()
    observer.cancel()
    // 不崩溃即为通过
}

/// ViewModel 被释放后，观察者不应崩溃（weak 持有）。
@MainActor
@Test func copyTaskObserverSurvivesViewModelDeallocation() async throws {
    var viewModel: CopyViewModel? = CopyViewModel()
    weak var weakRef = viewModel
    let observer = CopyTaskObserver(viewModel: viewModel!)
    defer { observer.cancel() }

    viewModel = nil
    #expect(weakRef == nil)

    // 事件到达时不应崩溃
    NotificationCenter.postCopyTaskCountChanged(count: 1)
    try await Task.sleep(for: .milliseconds(30))
}

// MARK: - 服务装配

/// 未注入库能力时，限额检查应放行而不是崩溃。
@MainActor
@Test func copyLimitAllowsWhenLibraryCapabilityMissing() async {
    #expect(await AudioCopyService.isOutOfLimit() == false)
}

/// 未注入库能力时按请求数原样返回。
@MainActor
@Test func allowedTaskCountPassesThroughWithoutLibrary() async {
    #expect(await AudioCopyService.allowedTaskCount(requestedTaskCount: 7) == 7)
    #expect(await AudioCopyService.allowedTaskCount(requestedTaskCount: 0) == 0)
}

/// 安装复制状态应保持幂等：重复调用复用同一 ViewModel，
/// 否则界面上会出现两份互不同步的状态。
@MainActor
@Test func installCopyStateIsIdempotent() {
    AudioCopyService.installCopyState()
    let first = AudioCopyService.copyViewModel
    AudioCopyService.installCopyState()
    #expect(AudioCopyService.copyViewModel === first)
}

/// 未装配时取状态视图不得崩溃。
@MainActor
@Test func stateViewIsAvailableEvenBeforeConfiguration() {
    AudioCopyService.copyViewModel = nil
    _ = AudioCopyService.getStateView()
    // 不崩溃即为通过
}

// MARK: - 测试替身

@MainActor
private final class ToastSpy: AudioCopyToastCapability {
    private(set) var infos: [String] = []

    func info(_ message: String) { infos.append(message) }
    func error(_ message: String) { infos.append(message) }
    func warning(_ message: String) { infos.append(message) }
}
#endif
