import Foundation
import ProviderAppState
import Testing
@testable import CisumKernelSupport

/// `BasicAppStateService` 的确定性回归：状态切换必须幂等、持久化 DB 视图
/// 可见性，并向观察者广播精确的事件。
@Suite @MainActor final class BasicAppStateServiceTests {
    private static let showDBKey = "UI.ShowDB"
    private let savedShowDB: Bool

    init() {
        savedShowDB = UserDefaults.standard.bool(forKey: Self.showDBKey)
    }

    deinit {
        UserDefaults.standard.set(savedShowDB, forKey: Self.showDBKey)
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
        let service = BasicAppStateService()
        var events: [AppStateProvidingEvent] = []
        let handle = service.addObserver { events.append($0) }

        service.showDBView()
        #expect(service.isDBViewVisible == true)
        #expect(UserDefaults.standard.bool(forKey: Self.showDBKey) == true)

        service.hideDBView()
        #expect(service.isDBViewVisible == false)
        #expect(UserDefaults.standard.bool(forKey: Self.showDBKey) == false)

        assertEvents(events, equals: [.dbViewVisibilityChanged(true), .dbViewVisibilityChanged(false)])
        handle.cancel()
    }

    @Test func dbViewToggleIgnoresNoopCalls() {
        let service = BasicAppStateService()
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
