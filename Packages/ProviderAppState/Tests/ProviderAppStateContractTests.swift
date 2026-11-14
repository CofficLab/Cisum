import Combine
import Foundation
import Testing
@testable import ProviderAppState

/// `AppStateProviding` 的默认实现与 `BasicAppStateService` 的剩余契约面。
///
/// 重点验证两处此前没有测试兜底的行为：
/// 1. 协议扩展提供的 `setDBView(_:)` 默认实现——把显式目标态映射到 show / hide；
/// 2. `toggleDBView()` 与 `hasDragOperation` 的真实实现语义。
@Suite @MainActor struct ProviderAppStateContractTests {
    private static let showDBKey = "UI.ContentViewVisible"

    /// 记录 show / hide 调用次数的测试替身。
    ///
    /// 刻意**不实现** `setDBView(_:)`，从而走协议扩展的默认实现——
    /// 这正是需要被覆盖的那段代码。
    @MainActor
    private final class RecordingProvider: @preconcurrency AppStateProviding {
        let objectWillChange = ObservableObjectPublisher()

        var isDemoMode = false
        var isDBViewVisible = false
        var isImporting = false
        var isDropping = false
        var hasDragOperation: Bool { isDropping }
        var stateMessage = ""

        private(set) var showCallCount = 0
        private(set) var hideCallCount = 0

        func enterDemoMode() {}
        func exitDemoMode() {}
        func showDBView() {
            showCallCount += 1
            isDBViewVisible = true
        }
        func hideDBView() {
            hideCallCount += 1
            isDBViewVisible = false
        }
        func closeDBView() {}
        func toggleDBView() {}
        func setImporting(_ importing: Bool) {}
        func setDragOperation(_ active: Bool) {}
        func appendStateMessage(_ message: String) {}
        func clearStateMessages() {}
    }

    private func makeDefaults() -> (defaults: UserDefaults, suiteName: String) {
        let suiteName = "ProviderAppStateContractTests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suiteName)!, suiteName)
    }

    /// 协议扩展的默认实现必须把显式目标态映射到 show / hide 语义，
    /// 这样只实现 show/hide 的既有实现也能满足 `setDBView` 契约。
    @Test
    func defaultSetDBViewMapsExplicitTargetOntoShowAndHide() {
        let provider = RecordingProvider()

        provider.setDBView(true)
        #expect(provider.showCallCount == 1)
        #expect(provider.hideCallCount == 0)
        #expect(provider.isDBViewVisible)

        provider.setDBView(false)
        #expect(provider.showCallCount == 1)
        #expect(provider.hideCallCount == 1)
        #expect(!provider.isDBViewVisible)
    }

    /// `toggleDBView()` 取反的是当前内存态，并且同样要落盘。
    @Test
    func toggleDBViewFlipsVisibilityAndPersists() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        // 预置为隐藏，保证第一次取反是「隐藏 → 可见」的真实变化。
        defaults.set(false, forKey: Self.showDBKey)

        let service = BasicAppStateService(defaults: defaults)
        var events: [AppStateProvidingEvent] = []
        let handle = service.addObserver { events.append($0) }

        service.toggleDBView()
        #expect(service.isDBViewVisible)
        #expect(defaults.object(forKey: Self.showDBKey) as? Bool == true)

        service.toggleDBView()
        #expect(!service.isDBViewVisible)
        #expect(defaults.object(forKey: Self.showDBKey) as? Bool == false)

        #expect(events.count == 2)
        handle.cancel()
    }

    /// `hasDragOperation` 是 `isDropping` 的兼容别名，必须始终同步。
    @Test
    func hasDragOperationMirrorsDroppingState() {
        let service = BasicAppStateService()
        #expect(service.hasDragOperation == false)

        service.setDragOperation(true)
        #expect(service.hasDragOperation)
        #expect(service.isDropping)

        service.setDragOperation(false)
        #expect(!service.hasDragOperation)
        #expect(!service.isDropping)
    }

    /// 多观察者各自独立：取消其中一个不得影响另一个。
    @Test
    func cancellingOneObserverLeavesOthersSubscribed() {
        let service = BasicAppStateService()
        var first: [AppStateProvidingEvent] = []
        var second: [AppStateProvidingEvent] = []
        let firstHandle = service.addObserver { first.append($0) }
        let secondHandle = service.addObserver { second.append($0) }

        service.setImporting(true)
        firstHandle.cancel()
        service.setImporting(false)

        #expect(first.count == 1)
        #expect(second.count == 2)
        secondHandle.cancel()
    }
}
