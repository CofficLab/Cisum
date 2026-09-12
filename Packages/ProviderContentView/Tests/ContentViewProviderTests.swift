import Combine
import SwiftUI
import Testing
@testable import ProviderContentView

@MainActor
private final class ContentViewProviderStub: @preconcurrency ContentViewProviding {
    let objectWillChange = ObservableObjectPublisher()
    var tabs: [ContentTabItem] = []

    func setTabs(_ tabs: [ContentTabItem]) { self.tabs = tabs }
    func makeContentView() -> AnyView { AnyView(EmptyView()) }
}

@MainActor
struct ContentViewProviderTests {
    @Test
    func defaultProviderSortsTabsAndPublishesSortedIdentifiers() {
        let provider = DefaultContentViewProvider()
        var receivedIDs: [[String]] = []
        let handle = provider.addObserver { event in
            if case .tabsChanged(let ids) = event {
                receivedIDs.append(ids)
            }
        }
        let tabs = [
            tab("late", order: 20),
            tab("early", order: 1),
            tab("middle", order: 10),
        ]

        provider.setTabs(tabs)

        #expect(provider.tabs.map(\.id) == ["early", "middle", "late"])
        #expect(receivedIDs == [["early", "middle", "late"]])

        provider.setTabs([])
        #expect(provider.tabs.isEmpty)
        #expect(receivedIDs.last == [])
        handle.cancel()
    }

    @Test
    func observersMayCancelDuringDeliveryWithoutSkippingOtherObservers() {
        let provider = DefaultContentViewProvider()
        var selfHandle: (any ContentViewProvidingObserverHandle)?
        var selfCallCount = 0
        var otherCallCount = 0

        selfHandle = provider.addObserver { _ in
            selfCallCount += 1
            selfHandle?.cancel()
        }
        let otherHandle = provider.addObserver { _ in otherCallCount += 1 }

        provider.setTabs([tab("first", order: 0)])
        provider.setTabs([tab("second", order: 0)])
        selfHandle?.cancel()
        otherHandle.cancel()
        otherHandle.cancel()

        #expect(selfCallCount == 1)
        #expect(otherCallCount == 2)
    }

    @Test
    func demoModeAndContentViewFollowProviderState() {
        let provider = DefaultContentViewProvider()
        #expect(!provider.isDemoMode)

        provider.setDemoMode(true)
        #expect(provider.isDemoMode)
        provider.setDemoMode(false)
        #expect(!provider.isDemoMode)

        _ = provider.makeContentView()
        _ = ContentAreaView(provider: provider, isDemoMode: false).body
        _ = EmptyTabView().body

        provider.setTabs([tab("one", order: 0)])
        _ = ContentAreaView(provider: provider, isDemoMode: false).body

        provider.setTabs([
            tab("two", order: 1),
            tab("one", order: 0),
        ])
        _ = ContentAreaView(provider: provider, isDemoMode: false).body
    }

    @Test
    func protocolDefaultsRemainSafeForLightweightProviders() {
        let provider = ContentViewProviderStub()
        provider.setDemoMode(true)
        let handle = provider.addObserver { _ in
            Issue.record("The default content observer must not receive events")
        }

        #expect(handle is NoopContentViewProvidingObserverHandle)
        handle.cancel()
        handle.cancel()
        #expect(provider.tabs.isEmpty)
    }
}

private func tab(_ id: String, order: Int) -> ContentTabItem {
    ContentTabItem(id: id, title: id, order: order, content: AnyView(EmptyView()))
}
