import SwiftUI
import Testing
@testable import ProviderControlView

@MainActor
private final class ControlViewProviderStub: ControlViewProviding {
    func makeControlView() -> AnyView { AnyView(EmptyView()) }
}

@MainActor
struct ControlViewProviderTests {
    @Test
    func defaultProviderStoresAndClearsInjectedAreas() {
        let provider = DefaultControlViewProvider()
        let customView = AnyView(Text("Injected"))

        #expect(provider.heroView == nil)
        #expect(provider.stateView == nil)
        #expect(provider.progressView == nil)
        #expect(provider.controlButtonsView == nil)
        #expect(provider.rightAlbumView == nil)
        #expect(!provider.isDemoMode)

        provider.setHeroView(customView)
        provider.setStateView(customView)
        provider.setProgressView(customView)
        provider.setControlButtonsView(customView)
        provider.setRightAlbumView(customView)
        provider.setDemoMode(true)

        #expect(provider.heroView != nil)
        #expect(provider.stateView != nil)
        #expect(provider.progressView != nil)
        #expect(provider.controlButtonsView != nil)
        #expect(provider.rightAlbumView != nil)
        #expect(provider.isDemoMode)
        _ = provider.makeControlView()

        provider.setHeroView(nil)
        provider.setStateView(nil)
        provider.setProgressView(nil)
        provider.setControlButtonsView(nil)
        provider.setRightAlbumView(nil)
        provider.setDemoMode(false)

        #expect(provider.heroView == nil)
        #expect(provider.stateView == nil)
        #expect(provider.progressView == nil)
        #expect(provider.controlButtonsView == nil)
        #expect(provider.rightAlbumView == nil)
        #expect(!provider.isDemoMode)
    }

    @Test
    func stateViewSuppressesMessagesAndContributionsInDemoMode() {
        var messageCalls = 0
        var stateViewCalls = 0
        let stateMessage = {
            messageCalls += 1
            return "Playback information"
        }
        let stateViews = {
            stateViewCalls += 1
            return [AnyView(Text("Additional state"))]
        }

        _ = StateView(
            isDemoMode: true,
            stateViews: stateViews,
            stateMessage: stateMessage
        ).body
        _ = StateView(
            isDemoMode: false,
            stateViews: { [] },
            stateMessage: { "" }
        ).body
        _ = StateView(
            isDemoMode: false,
            stateViews: { [] },
            stateMessage: { "Playback information" }
        ).body
        _ = StateView(
            isDemoMode: false,
            stateViews: { [AnyView(Text("Additional state"))] },
            stateMessage: { "" }
        ).body

        #expect(messageCalls == 1)
        #expect(stateViewCalls == 1)
    }

    @Test
    func lightweightProviderDefaultsRemainNoopAndSafe() {
        let provider = ControlViewProviderStub()
        let handle = provider.addObserver { _ in
            Issue.record("The default control-view observer must not receive events")
        }
        let customView = AnyView(Text("Ignored by the stub"))

        provider.setHeroView(customView)
        provider.setStateView(customView)
        provider.setProgressView(customView)
        provider.setControlButtonsView(customView)
        provider.setRightAlbumView(customView)
        provider.setDemoMode(true)

        #expect(handle is NoopControlViewProvidingObserverHandle)
        handle.cancel()
        handle.cancel()
        _ = provider.makeControlView()
    }
}
