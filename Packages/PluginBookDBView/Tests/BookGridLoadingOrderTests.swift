import Foundation
import Testing
import ProviderBook
@testable import PluginBookDBView

/// `BookGridViewModel` 在「先 onAppear、后 onDisappear」时的加载状态回归。
///
/// ## 复现的缺陷
///
/// 有声书场景长期显示「正在读取有声书仓库」，对应的根因是
/// `BookGridViewModel.isLoading` 停在 `true` —— 加载请求从未真正发出，
/// 或者发出了却被作废。
///
/// 场景切换时 SwiftUI 会先让新场景内容 `onAppear`、再让旧场景内容
/// `onDisappear`（顺序不保证，「先 appear 后 disappear」是真实存在的
/// 顺序之一）。`BookGrid` 的两个回调各自独立操作同一份加载状态：
///
/// - `onAppear`：`Task { @MainActor in }` 里先 `bind(library:)` 再
///   `handleOnAppear()` —— 设置 `isLoading = true` 并调度一个防抖任务去拉数据；
/// - `onDisappear`：**同步**调用 `handleOnDisappear()`。
///
/// 注意 `onAppear` 的回调体是**异步**的（`Task { @MainActor in }`），
/// 而 `onDisappear` 是同步的。因此「先 appear 后 disappear」这一顺序下：
///
/// 1. `onAppear` 排了一个 `Task { @MainActor in ... }`；
/// 2. `onDisappear` **先**执行，把防抖任务取消掉、把 generation 递增；
/// 3. 那个 `Task` 才被调度执行 → `handleOnAppear()` 设置 `isLoading = true`
///    并排新的防抖任务 —— 但此时 `updateBooksDebounceTask` 已经被取消过，
///    新的任务能跑，generation 也是新的，看起来没问题；
///
/// 真正出问题的是另一条路径：`onAppear` 的 `Task` 先跑完
/// （`isLoading = true` + 防抖任务已排好），随后 `onDisappear` 执行，
/// 把这个**尚未到点执行**的防抖任务取消掉、并递增 generation。
/// 于是：
///
/// - 没有任何任务再去调用 `updateBooks()`，`setBooks()` 永远不执行；
/// - `isLoading` 停在 `true` —— UI 永远显示「正在读取有声书仓库」。
///
/// `handleOnDisappear()` 的本意是「场景离开时作废在途结果」，
/// 但它同时也作废了自己尚未执行完的**加载请求**。二者必须分开处理：
/// 离开场景只该作废「已发出的结果」，不该取消「还没发出的请求」。
@MainActor
struct BookGridLoadingOrderTests {

    /// 探针：`books()` 记录调用次数并立刻返回空列表。
    @MainActor
    private final class CountingBookProbe: BookLibraryCapability {
        var bookDisk: URL? = URL(fileURLWithPath: "/tmp/books")
        var databaseRoot = URL(fileURLWithPath: "/tmp/book-db")
        private(set) var callCount = 0

        func books(reason: String) async -> [BookDTO] {
            callCount += 1
            return []
        }

        func syncImportedItems(_ items: [URL]) async throws {}
        func coverData(for bookURL: URL) async -> Data? { nil }
        func playbackState(for bookURL: URL) async -> BookPlaybackStateDTO? { nil }
        func currentBookURL() -> URL? { nil }
        func currentBookTime() -> TimeInterval? { nil }

        @discardableResult
        func addObserver(_ callback: @escaping (BookLibraryEvent) -> Void) -> any BookLibraryObserverHandle {
            ProbeHandle {}
        }
    }

    @MainActor
    private final class ProbeHandle: BookLibraryObserverHandle {
        private let onCancel: () -> Void
        private var cancelled = false

        init(onCancel: @escaping () -> Void) {
            self.onCancel = onCancel
        }

        func cancel() {
            guard !cancelled else { return }
            cancelled = true
            onCancel()
        }
    }

    /// 回归：`handleOnAppear()` 之后紧跟 `handleOnDisappear()`（SwiftUI 在
    /// 场景切换时给出的顺序之一），加载状态必须仍然能够走到 `false`。
    @Test
    func loadingStillSettlesWhenDisappearFollowsAppear() async throws {
        let probe = CountingBookProbe()
        let viewModel = BookGridViewModel()
        viewModel.bind(library: probe)

        viewModel.handleOnAppear()
        viewModel.handleOnDisappear()

        // 等够长，覆盖防抖延迟（0.25s）与一次异步往返。
        for _ in 0..<60 where viewModel.isLoading {
            try await Task.sleep(for: .milliseconds(50))
        }

        #expect(
            !viewModel.isLoading,
            """
            onAppear 之后紧跟 onDisappear 时，加载状态永远停在 true：
            onDisappear 取消了尚未执行的加载请求，却没有重新触发。
            UI 会一直显示"正在读取有声书仓库"。
            """
        )
    }

    /// 对照组：只有 onAppear（没有 onDisappear）时同样必须能加载完成。
    @Test
    func loadingSettlesWithAppearOnly() async throws {
        let probe = CountingBookProbe()
        let viewModel = BookGridViewModel()
        viewModel.bind(library: probe)

        viewModel.handleOnAppear()

        for _ in 0..<60 where viewModel.isLoading {
            try await Task.sleep(for: .milliseconds(50))
        }

        #expect(!viewModel.isLoading, "只有 onAppear 时加载状态也应走到 false")
        #expect(probe.callCount > 0, "应当至少真正拉取过一次数据")
    }
}
