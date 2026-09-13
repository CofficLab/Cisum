import KernelCore
import SwiftUI
import Testing
@testable import ProviderRootView

@MainActor
struct DefaultRootViewProviderTests {
    @Test
    func contentPlaceholderBodyCanBeConstructedWithoutInjectedContent() {
        _ = ContentPlaceholderView().body
    }

    @Test
    func injectedViewsAndVisibilityArePublishedThroughEvents() {
        let provider = DefaultRootViewProvider(kernel: CisumKernelContainer())
        var events: [RootViewProvidingEvent] = []
        let handle = provider.addObserver { events.append($0) }

        provider.setControlView(AnyView(Text("Control")))
        provider.setContentView(AnyView(Text("Content")))
        provider.setStatusView(AnyView(Text("Status")))
        provider.setToolbarContent(AnyView(Text("Toolbar")))
        provider.setContentViewVisible(false)
        provider.showContentView()
        provider.toggleContentView()
        provider.hideContentView()

        #expect(provider.controlView != nil)
        #expect(provider.contentView != nil)
        #expect(provider.statusView != nil)
        #expect(provider.toolbarContent != nil)
        #expect(!provider.isContentViewVisible)
        #expect(eventNames(events) == [
            "control", "content", "status", "toolbar", "visibility", "visibility",
        ])

        handle.cancel()
        provider.setControlView(nil)
        #expect(eventNames(events).count == 6)
        #expect(provider.controlView == nil)
    }

    @Test
    func layoutViewModelMirrorsProviderStateAndIgnoresOverlayOnlyEvents() {
        let provider = DefaultRootViewProvider(kernel: CisumKernelContainer())
        let viewModel = RootLayoutViewModel(provider: provider)

        #expect(viewModel.controlView == nil)
        #expect(viewModel.contentView == nil)
        #expect(viewModel.statusView == nil)
        #expect(viewModel.toolbarContent == nil)
        #expect(!viewModel.isContentViewVisible)

        provider.setControlView(AnyView(Text("Control")))
        provider.setContentView(AnyView(Text("Content")))
        provider.setStatusView(AnyView(Text("Status")))
        provider.setToolbarContent(AnyView(Text("Toolbar")))
        provider.setContentViewVisible(true)
        provider.addOverlays([overlay(id: "root", order: 0, recorder: OverlayRecorder())])

        #expect(viewModel.controlView != nil)
        #expect(viewModel.contentView != nil)
        #expect(viewModel.statusView != nil)
        #expect(viewModel.toolbarContent != nil)
        #expect(viewModel.isContentViewVisible)
    }

    @Test
    func overlaysAreDeduplicatedOrderedAndOnlyNotifyOnChanges() {
        let provider = DefaultRootViewProvider(kernel: CisumKernelContainer())
        var events: [String] = []
        let recorder = OverlayRecorder()
        let handle = provider.addObserver { event in
            if case .overlaysChanged = event { events.append("changed") }
        }
        let lateOverlay = overlay(id: "late", order: 20, recorder: recorder)
        let earlyOverlay = overlay(id: "early", order: 10, recorder: recorder)
        let duplicateOverlay = overlay(id: "early", order: 0, recorder: recorder)

        provider.addOverlays([lateOverlay, earlyOverlay, duplicateOverlay])
        provider.addOverlays([earlyOverlay])
        provider.addOverlays([])

        #expect(provider.overlays.map(\.id) == ["early", "late"])
        #expect(events == ["changed"])
        _ = provider.makeRootView()
        #expect(recorder.wrapped == ["early", "late"])

        provider.removeOverlays(ids: ["missing"])
        #expect(events == ["changed"])
        provider.removeOverlays(ids: ["early"])
        #expect(provider.overlays.map(\.id) == ["late"])
        #expect(events == ["changed", "changed"])

        handle.cancel()
    }
}

@MainActor
private func eventNames(_ events: [RootViewProvidingEvent]) -> [String] {
    events.map { event in
        switch event {
        case .controlViewChanged: "control"
        case .contentViewChanged: "content"
        case .statusViewChanged: "status"
        case .toolbarContentChanged: "toolbar"
        case .contentViewVisibilityChanged: "visibility"
        case .overlaysChanged: "overlays"
        }
    }
}

@MainActor
private final class OverlayRecorder {
    var wrapped: [String] = []
}

@MainActor
private func overlay(id: String, order: Int, recorder: OverlayRecorder) -> RootOverlayItem {
    RootOverlayItem(id: id, order: order) { _ in
        recorder.wrapped.append(id)
        return Text(id)
    }
}
