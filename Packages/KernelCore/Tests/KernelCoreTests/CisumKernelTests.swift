import Testing
@testable import KernelCore
import ProviderAppState

@MainActor
struct ProviderObservationTests {
    @Test
    func appStatePublishesSemanticEventsAndSupportsCancellation() {
        let service = BasicAppStateService()
        var receivedEvents: [String] = []

        let handle = service.addObserver { event in
            switch event {
            case .demoModeChanged(let enabled):
                receivedEvents.append("demo:\(enabled)")
            case .importingChanged(let importing):
                receivedEvents.append("importing:\(importing)")
            case .droppingChanged(let dropping):
                receivedEvents.append("dropping:\(dropping)")
            case .stateMessageChanged(let message):
                receivedEvents.append("message:\(message)")
            case .dbViewVisibilityChanged:
                break
            }
        }

        service.enterDemoMode()
        service.setImporting(true)
        service.setDragOperation(true)
        service.appendStateMessage("ready")

        #expect(receivedEvents == [
            "demo:true",
            "importing:true",
            "dropping:true",
            "message:ready"
        ])

        handle.cancel()
        service.exitDemoMode()
        #expect(receivedEvents.count == 4)
    }
}

@MainActor
struct ProviderRegistrationTests {
    @Test
    func duplicateProviderRegistrationThrows() throws {
        let kernel = CisumKernelContainer()
        let first = BasicAppStateService()
        try kernel.registerProvider((any AppStateProviding).self, first)

        // 第二次注册同一 key 必须抛 providerAlreadyRegistered。
        #expect(throws: CisumKernelError.self) {
            try kernel.registerProvider((any AppStateProviding).self, BasicAppStateService())
        }

        // 第一次注册的实例仍可解析。
        #expect((kernel.resolveProvider((any AppStateProviding).self) as AnyObject?) === first)
    }

    @Test
    func explicitUnregisterAllowsReRegistration() throws {
        let kernel = CisumKernelContainer()
        let first = BasicAppStateService()
        try kernel.registerProvider((any AppStateProviding).self, first)

        kernel.unregisterProvider((any AppStateProviding).self)
        let second = BasicAppStateService()
        try kernel.registerProvider((any AppStateProviding).self, second)

        #expect((kernel.resolveProvider((any AppStateProviding).self) as AnyObject?) === second)
    }

    @Test
    func ownerTrackingRecordsActivePluginID() throws {
        let kernel = CisumKernelContainer()
        kernel.activePluginID = "test-plugin"
        try kernel.registerProvider((any AppStateProviding).self, BasicAppStateService())
        kernel.activePluginID = nil

        // 错误消息里应包含注册的插件 ID。
        do {
            try kernel.registerProvider((any AppStateProviding).self, BasicAppStateService())
            Issue.record("Expected providerAlreadyRegistered")
        } catch let error as CisumKernelError {
            if case .providerAlreadyRegistered(_, let owner) = error {
                #expect(owner == "test-plugin")
            } else {
                Issue.record("Unexpected error: \(error)")
            }
        }
    }

    @Test
    func hostRegistrationHasNoOwner() throws {
        let kernel = CisumKernelContainer()
        // 不设置 activePluginID（模拟宿主在插件启动前注册基础设施）。
        try kernel.registerProvider((any AppStateProviding).self, BasicAppStateService())

        do {
            try kernel.registerProvider((any AppStateProviding).self, BasicAppStateService())
            Issue.record("Expected providerAlreadyRegistered")
        } catch let error as CisumKernelError {
            if case .providerAlreadyRegistered(_, let owner) = error {
                #expect(owner == nil)
            } else {
                Issue.record("Unexpected error: \(error)")
            }
        }
    }
}
