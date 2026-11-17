import Combine
import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import ProviderControlView

/// 载入插槽的行为约束：
/// - 激活态由插件驱动，插槽自身只负责广播；
/// - 激活时替代状态行 + 进度行，并在同样高度内渲染横幅；
/// - 载入与引导同时成立时，引导优先。
@MainActor
struct ControlLoadingSlotTests {
    private let stateColor = Color.red
    private let progressColor = Color.blue
    private let bannerColor = Color.green

    private enum Marker {
        case state
        case progress
        case banner
    }

    // MARK: - Rendering helpers

    private func pixels<V: View>(_ view: V) throws -> Data {
        let renderer = ImageRenderer(content: view.frame(width: 200, height: 400).background(Color.white))
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

    private func containsColor(_ data: Data, _ marker: Marker) -> Bool {
        countColor(data, marker) > 0
    }

    private func countColor(_ data: Data, _ marker: Marker) -> Int {
        var count = 0
        for index in stride(from: 0, to: data.count - 3, by: 4) {
            let red = Int(data[index])
            let green = Int(data[index + 1])
            let blue = Int(data[index + 2])
            switch marker {
            case .state:
                if red > 180 && green < 80 && blue < 80 { count += 1 }
            case .progress:
                if red < 80 && green < 160 && blue > 180 { count += 1 }
            case .banner:
                if red < 100 && green > 150 && blue < 100 { count += 1 }
            }
        }
        return count
    }

    private func makeControl(loadingSlot: ControlLoadingSlot?) -> ControlView {
        ControlView(
            stateViews: { [] },
            stateMessage: { "" },
            isDemoMode: false,
            stateView: AnyView(stateColor),
            progressView: AnyView(progressColor),
            loadingSlot: loadingSlot
        )
    }

    private func withHeroVisibility(_ visible: Bool, _ body: () throws -> Void) rethrows {
        let previous = ControlHeroVisibility.shared.isVisible
        ControlHeroVisibility.shared.isVisible = visible
        defer { ControlHeroVisibility.shared.isVisible = previous }
        try body()
    }

    // MARK: - Tests

    @Test
    func slotPublishesActivationChanges() {
        let slot = ControlLoadingSlot(view: AnyView(Color.green))
        #expect(!slot.isActive)

        var values: [Bool] = []
        let subscription = slot.$isActive.sink { values.append($0) }
        slot.isActive = true
        slot.isActive = false
        #expect(values == [false, true, false])
        subscription.cancel()

        slot.isActive = true
        #expect(values == [false, true, false])
    }

    @Test
    func providerStoresAndClearsLoadingSlot() {
        let provider = DefaultControlViewProvider()
        #expect(provider.loadingSlot == nil)

        let slot = ControlLoadingSlot(view: AnyView(Color.green))
        provider.setLoadingSlot(slot)
        #expect(provider.loadingSlot === slot)

        _ = provider.makeControlView()

        provider.setLoadingSlot(nil)
        #expect(provider.loadingSlot == nil)
    }

    @Test
    func inactiveSlotKeepsStateAndProgressRows() throws {
        let rendered = try pixels(makeControl(loadingSlot: ControlLoadingSlot(view: AnyView(bannerColor))))

        #expect(containsColor(rendered, .state))
        #expect(containsColor(rendered, .progress))
        #expect(!containsColor(rendered, .banner))
    }

    @Test
    func activeSlotReplacesStateAndProgressRows() throws {
        let slot = ControlLoadingSlot(view: AnyView(bannerColor))
        let control = makeControl(loadingSlot: slot)

        slot.isActive = true
        let rendered = try pixels(control)

        #expect(containsColor(rendered, .banner))
        #expect(!containsColor(rendered, .state))
        #expect(!containsColor(rendered, .progress))
    }

    /// 横幅高度 = 状态行 + 进度行，因此封面区在载入前后不应改变高度。
    @Test
    func activeSlotKeepsHeroHeightStable() throws {
        try withHeroVisibility(true) {
            let slot = ControlLoadingSlot(view: AnyView(bannerColor))
            let control = ControlView(
                stateViews: { [] },
                stateMessage: { "" },
                isDemoMode: false,
                heroView: AnyView(Color.red),
                stateView: AnyView(Color.black),
                progressView: AnyView(progressColor),
                loadingSlot: slot
            )

            let before = try pixels(control)
            slot.isActive = true
            let after = try pixels(control)

            let heroBefore = countColor(before, .state)
            let heroAfter = countColor(after, .state)
            #expect(heroBefore > 0)
            #expect(abs(heroBefore - heroAfter) <= 400, "封面高度在载入前后发生了明显变化：\(heroBefore) vs \(heroAfter)")
        }
    }

    @Test
    func guideWinsWhenBothSlotsAreActive() throws {
        try withHeroVisibility(false) {
            let guide = ControlGuideSlot(guideView: AnyView(stateColor))
            guide.isActive = true
            let slot = ControlLoadingSlot(view: AnyView(bannerColor))
            slot.isActive = true

            let control = ControlView(
                stateViews: { [] },
                stateMessage: { "" },
                isDemoMode: false,
                guideSlot: guide,
                loadingSlot: slot
            )

            let rendered = try pixels(control)
            #expect(containsColor(rendered, .state))
            #expect(!containsColor(rendered, .banner))
        }
    }
}
