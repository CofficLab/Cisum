import Combine
import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import ProviderControlView

@MainActor
private final class ControlViewProviderStub: ControlViewProviding {
    func makeControlView() -> AnyView { AnyView(EmptyView()) }
}

@MainActor
struct ControlViewProviderTests {
    private func pixels<V: View>(_ view: V) throws -> Data {
        let renderer = ImageRenderer(content: view.frame(width: 80, height: 80).background(Color.white))
        renderer.scale = 1
        let image = try #require(renderer.cgImage)
        let context = try #require(CGContext(
            data: nil, width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let bytes = try #require(context.data)
        return Data(bytes: bytes, count: image.width * image.height * 4)
    }

    @Test
    func heroVisibilityPublishesChangesWithoutSharingInstanceState() {
        let visibility = ControlHeroVisibility()
        let other = ControlHeroVisibility(isVisible: false)
        #expect(visibility.isVisible)
        #expect(!other.isVisible)
        #expect(ControlHeroVisibility.shared === ControlHeroVisibility.shared)
        var values: [Bool] = []
        let subscription = visibility.$isVisible.sink { values.append($0) }
        visibility.isVisible = false
        visibility.isVisible = true
        #expect(values == [true, false, true])
        #expect(!other.isVisible)
        subscription.cancel()
        visibility.isVisible = false
        #expect(values == [true, false, true])
    }

    @Test
    func injectedSlotsReplaceAndClearIndependently() throws {
        let provider = DefaultControlViewProvider()
        let red = AnyView(Color.red.frame(width: 8, height: 8))
        let blue = AnyView(Color.blue.frame(width: 8, height: 8))
        let setters: [(AnyView?) -> Void] = [provider.setHeroView, provider.setStateView,
            provider.setProgressView, provider.setControlButtonsView, provider.setRightAlbumView]
        func slots() -> [AnyView?] {
            [provider.heroView, provider.stateView, provider.progressView,
             provider.controlButtonsView, provider.rightAlbumView]
        }
        #expect(try pixels(red) != pixels(blue))
        for index in setters.indices {
            setters.forEach { $0(red) }
            setters[index](blue)
            for (slotIndex, slot) in slots().enumerated() {
                let view = try #require(slot)
                #expect(try pixels(view) == pixels(slotIndex == index ? blue : red))
            }
            setters[index](nil)
            #expect(slots()[index] == nil)
            #expect(slots().compactMap { $0 }.count == 4)
        }
    }

    @Test
    func demoStateViewRendersNeitherMessageNorContributions() throws {
        let demo = StateView(isDemoMode: true,
            stateViews: { [AnyView(Color.red.frame(width: 8, height: 8))] },
            stateMessage: { "播放状态" })
        #expect(try pixels(demo) == pixels(EmptyView()))
    }

    @Test
    func normalStateViewRendersContributionsAndEmptyStateStaysEmpty() throws {
        let marker = AnyView(Color.red.frame(width: 8, height: 8))
        let populated = StateView(isDemoMode: false, stateViews: { [marker] }, stateMessage: { "" })
        let empty = StateView(isDemoMode: false, stateViews: { [] }, stateMessage: { "" })
        #expect(try pixels(populated) == pixels(marker))
        #expect(try pixels(populated) != pixels(empty))
        #expect(try pixels(empty) == pixels(EmptyView()))
    }

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
    func defaultProviderRendersEmptyStateUntilStateMessageProvided() throws {
        let defaultProvider = DefaultControlViewProvider()
        let messageProvider = DefaultControlViewProvider(
            stateViews: { [] },
            stateMessage: { "播放状态" }
        )

        let defaultPixels = try pixels(defaultProvider.makeControlView())
        let messagePixels = try pixels(messageProvider.makeControlView())
        let emptyPixels = try pixels(EmptyView())

        // 默认的状态提示与贡献视图都是空的 → 状态区不渲染任何内容。
        #expect(defaultPixels == emptyPixels)
        #expect(defaultPixels != messagePixels)
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
        provider.setGuideSlot(nil)

        #expect(handle is NoopControlViewProvidingObserverHandle)
        handle.cancel()
        handle.cancel()
        _ = provider.makeControlView()
    }
}
