import Foundation
import ProviderAppState
import Testing
@testable import ProviderAppState

/// `BasicAppStateService` 的确定性回归：状态切换必须幂等、持久化 DB 视图
/// 可见性，并向观察者广播精确的事件。
///
/// 所有涉及内容区显隐的用例都使用**独立的 `UserDefaults` suite**：
/// 显隐是有状态的持久化偏好，共享 `.standard` 会让用例的执行顺序决定结果
/// （早期版本用 `.standard` + 全局还原来绕过，顺序一变就会假失败）。
@Suite @MainActor final class BasicAppStateServiceTests {
    private static let showDBKey = "UI.ContentViewVisible"
    /// 已弃用的历史键：只读不写，且**不得**被继承为当前显隐状态。
    private static let legacyShowDBKey = "UI.ShowDB"

    /// 独立的偏好存储；调用方负责在用例结束时移除持久化域。
    private func makeDefaults() -> (defaults: UserDefaults, suiteName: String) {
        let suiteName = "BasicAppStateServiceTests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suiteName)!, suiteName)
    }

    /// 按 case 模式匹配断言事件序列（`AppStateProvidingEvent` 无 Equatable）。
    private func assertEvents(
        _ actual: [AppStateProvidingEvent],
        equals expected: [AppStateProvidingEvent],
        fileID: String = #fileID, filePath: String = #filePath,
        line: Int = #line, column: Int = #column
    ) {
        #expect(actual.count == expected.count)
        for (received, wanted) in zip(actual, expected) {
            switch (received, wanted) {
            case (.demoModeChanged(let a), .demoModeChanged(let b)):
                #expect(a == b)
            case (.dbViewVisibilityChanged(let a), .dbViewVisibilityChanged(let b)):
                #expect(a == b)
            case (.importingChanged(let a), .importingChanged(let b)):
                #expect(a == b)
            case (.droppingChanged(let a), .droppingChanged(let b)):
                #expect(a == b)
            case (.stateMessageChanged(let a), .stateMessageChanged(let b)):
                #expect(a == b)
            default:
                Issue.record("unexpected event \(received)")
            }
        }
    }

    @Test func dbViewDefaultsVisibleWhenPreferenceIsUnset() {
        let suiteName = "BasicAppStateServiceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let service = BasicAppStateService(defaults: defaults)

        #expect(service.isDBViewVisible)
        #expect(defaults.object(forKey: Self.showDBKey) == nil)
    }

    @Test func dbViewRestoresExplicitlyHiddenPreference() {
        let suiteName = "BasicAppStateServiceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(false, forKey: Self.showDBKey)

        let service = BasicAppStateService(defaults: defaults)

        #expect(!service.isDBViewVisible)
    }

    /// 旧键 `"UI.ShowDB"` 的值可能来自已知缺陷（iOS 几何规则误收起、重构前桌面
    /// `UIRepo`）而不是用户意图，无法与「用户主动收起」区分。
    /// 若继承它，升级后每次冷启动都只剩空播放器且用户无从恢复。
    @Test func legacyShowDBPreferenceIsNotInherited() {
        let suiteName = "BasicAppStateServiceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(false, forKey: Self.legacyShowDBKey)

        let service = BasicAppStateService(defaults: defaults)

        #expect(service.isDBViewVisible)
        #expect(defaults.object(forKey: Self.showDBKey) == nil)
    }

    @Test func setDBViewPersistsExplicitTargetState() {
        let suiteName = "BasicAppStateServiceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let service = BasicAppStateService(defaults: defaults)
        var events: [AppStateProvidingEvent] = []
        let handle = service.addObserver { events.append($0) }

        service.setDBView(false)
        #expect(service.isDBViewVisible == false)
        #expect(defaults.object(forKey: Self.showDBKey) as? Bool == false)

        service.setDBView(true)
        #expect(service.isDBViewVisible == true)
        #expect(defaults.object(forKey: Self.showDBKey) as? Bool == true)

        // 幂等：重复写入同一目标不产生额外事件。
        service.setDBView(true)
        assertEvents(events, equals: [.dbViewVisibilityChanged(false), .dbViewVisibilityChanged(true)])
        handle.cancel()
    }

    @Test func demoModeToggleIsIdempotentAndBroadcasts() {
        let service = BasicAppStateService()
        var events: [AppStateProvidingEvent] = []
        let handle = service.addObserver { events.append($0) }

        service.enterDemoMode()
        service.enterDemoMode()
        service.exitDemoMode()
        service.exitDemoMode()

        #expect(service.isDemoMode == false)
        assertEvents(events, equals: [.demoModeChanged(true), .demoModeChanged(false)])
        handle.cancel()
    }

    @Test func dbViewTogglePersistsAndBroadcasts() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        // 显式预置为隐藏，让「显式 → 隐藏 → 显式」的每一次变化都真实发生，
        // 避免默认值让首次调用成为空操作。
        defaults.set(false, forKey: Self.showDBKey)

        let service = BasicAppStateService(defaults: defaults)
        var events: [AppStateProvidingEvent] = []
        let handle = service.addObserver { events.append($0) }

        service.showDBView()
        #expect(service.isDBViewVisible == true)
        #expect(defaults.object(forKey: Self.showDBKey) as? Bool == true)

        service.hideDBView()
        #expect(service.isDBViewVisible == false)
        #expect(defaults.object(forKey: Self.showDBKey) as? Bool == false)

        assertEvents(events, equals: [.dbViewVisibilityChanged(true), .dbViewVisibilityChanged(false)])
        handle.cancel()
    }

    @Test func dbViewToggleIgnoresNoopCalls() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(false, forKey: Self.showDBKey)

        let service = BasicAppStateService(defaults: defaults)
        var events: [AppStateProvidingEvent] = []
        let handle = service.addObserver { events.append($0) }

        service.showDBView()
        service.showDBView()
        service.closeDBView()
        service.closeDBView()

        assertEvents(events, equals: [.dbViewVisibilityChanged(true), .dbViewVisibilityChanged(false)])
        handle.cancel()
    }

    @Test func importingAndDroppingBroadcastOnlyOnChange() {
        let service = BasicAppStateService()
        var events: [AppStateProvidingEvent] = []
        let handle = service.addObserver { events.append($0) }

        service.setImporting(true)
        service.setImporting(true)
        service.setDragOperation(true)
        service.setImporting(false)
        service.setDragOperation(false)

        #expect(service.isImporting == false)
        #expect(service.isDropping == false)
        assertEvents(events, equals: [
            .importingChanged(true),
            .droppingChanged(true),
            .importingChanged(false),
            .droppingChanged(false),
        ])
        handle.cancel()
    }

    @Test func stateMessagesAppendClearAndBroadcast() {
        let service = BasicAppStateService()
        var events: [AppStateProvidingEvent] = []
        let handle = service.addObserver { events.append($0) }

        service.appendStateMessage("first")
        service.appendStateMessage("second")
        service.clearStateMessages()
        service.clearStateMessages()

        #expect(service.stateMessage == "")
        assertEvents(events, equals: [
            .stateMessageChanged("first"),
            .stateMessageChanged("first\nsecond"),
            .stateMessageChanged(""),
        ])
        handle.cancel()
    }
}
