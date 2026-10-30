import Combine
import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import ProviderControlView

/// 空仓库引导插槽的行为约束：
/// - 激活态由插件驱动，插槽自身只负责广播；
/// - 控制区在「激活 + 封面未呈现 + 高度足够」时才渲染引导；
/// - 引导占据顶部主要区域，播放控件与进度顺势沉到下方。
@MainActor
struct ControlGuideSlotTests {
    /// 渲染视图并取像素，用于断言「某个标记视图是否出现在画面里」。
    private func pixels<V: View>(_ view: V, width: CGFloat = 200, height: CGFloat = 400) throws -> Data {
        let renderer = ImageRenderer(content: view.frame(width: width, height: height).background(Color.white))
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

    /// 取渲染结果中某个点的颜色。
    private func pixel<V: View>(_ view: V, x: Int, y: Int) throws -> (red: Int, green: Int, blue: Int)? {
        let renderer = ImageRenderer(content: view.frame(width: 200, height: 400).background(Color.white))
        renderer.scale = 1
        let image = try #require(renderer.cgImage)
        return rawPixel(in: image, x: x, y: y)
    }

    /// 取位图中某个点的颜色。
    private func rawPixel(in image: CGImage, x: Int, y: Int) -> (red: Int, green: Int, blue: Int)? {
        guard let data = image.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else { return nil }
        let offset = (y * image.width + x) * 4
        guard offset + 3 < CFDataGetLength(data) else { return nil }
        return (Int(bytes[offset]), Int(bytes[offset + 1]), Int(bytes[offset + 2]))
    }

    /// 位图方向判定：ImageRenderer 输出的位图行序不固定（可能自上而下，
    /// 也可能自下而上）。先用一个已知方向的标记视图判定，再解读控制区像素。
    private func isBitmapTopDown() throws -> Bool {
        let renderer = ImageRenderer(content:
            VStack(spacing: 0) {
                Color.red.frame(height: 100)
                Color.blue.frame(height: 100)
            }
            .frame(width: 20, height: 200)
        )
        renderer.scale = 1
        let image = try #require(renderer.cgImage)
        let edge = try #require(rawPixel(in: image, x: 10, y: 5))
        return edge.red > edge.blue
    }

    /// 控制区渲染需要封面区处于「未呈现」态，否则引导与封面互斥规则会让引导不出现。
    private func withHeroHidden(_ body: () throws -> Void) rethrows {
        let previous = ControlHeroVisibility.shared.isVisible
        ControlHeroVisibility.shared.isVisible = false
        defer { ControlHeroVisibility.shared.isVisible = previous }
        try body()
    }

    @Test
    func slotPublishesActivationChanges() {
        let slot = ControlGuideSlot(
            guideView: AnyView(Color.red)
        )
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
    func providerStoresAndClearsGuideSlot() {
        let provider = DefaultControlViewProvider()
        #expect(provider.guideSlot == nil)

        let slot = ControlGuideSlot(
            guideView: AnyView(Color.red)
        )
        provider.setGuideSlot(slot)
        #expect(provider.guideSlot === slot)

        _ = provider.makeControlView()

        provider.setGuideSlot(nil)
        #expect(provider.guideSlot == nil)
    }

    @Test
    func inactiveSlotRendersNoGuide() throws {
        try withHeroHidden {
            let slot = ControlGuideSlot(
                guideView: AnyView(Color.red)
            )
            let control = ControlView(
                stateViews: { [] },
                stateMessage: { "" },
                isDemoMode: false,
                guideSlot: slot
            )
            let rendered = try pixels(control)
            let empty = try pixels(EmptyView())
            #expect(rendered == empty)
        }
    }

    /// 位图里是否出现指定颜色（按分量区间匹配，避开抗锯齿与色彩管理带来的偏差）。
    private func containsColor(
        _ data: Data,
        red: ClosedRange<Int>,
        green: ClosedRange<Int>,
        blue: ClosedRange<Int>
    ) -> Bool {
        for index in stride(from: 0, to: data.count - 3, by: 4) {
            if red.contains(Int(data[index])),
               green.contains(Int(data[index + 1])),
               blue.contains(Int(data[index + 2])) {
                return true
            }
        }
        return false
    }

    @Test
    func activeSlotRendersGuideAtTop() throws {
        try withHeroHidden {
            let slot = ControlGuideSlot(
                guideView: AnyView(Color.red)
            )
            slot.isActive = true

            let control = ControlView(
                stateViews: { [] },
                stateMessage: { "" },
                isDemoMode: false,
                guideSlot: slot
            )

            // 引导（红）占据顶部主要区域，并一路铺到控制区底部。
            let topDown = try isBitmapTopDown()
            let guideY = topDown ? 20 : 380

            let guidePixel = try pixel(control, x: 100, y: guideY)
            let guide = try #require(guidePixel)
            #expect(guide.red > 200 && guide.green < 60)
        }
    }

    @Test
    func activeSlotHidesTheProgressSection() throws {
        try withHeroHidden {
            let slot = ControlGuideSlot(
                guideView: AnyView(Color.red)
            )
            let control = ControlView(
                stateViews: { [] },
                stateMessage: { "" },
                isDemoMode: false,
                progressView: AnyView(Color.blue),
                guideSlot: slot
            )

            // 引导未激活：进度区照常呈现。
            let withProgress = try pixels(control)
            #expect(containsColor(withProgress, red: 0...80, green: 0...200, blue: 180...255))

            // 引导激活 = 仓库为空：没有可播的曲目，进度区连同它的高度一起收掉。
            slot.isActive = true
            let withoutProgress = try pixels(control)
            #expect(!containsColor(withoutProgress, red: 0...80, green: 0...200, blue: 180...255))
        }
    }

    @Test
    func shortControlAreaKeepsGuideHidden() throws {
        try withHeroHidden {
            let slot = ControlGuideSlot(
                guideView: AnyView(Color.red)
            )
            slot.isActive = true

            let control = ControlView(
                stateViews: { [] },
                stateMessage: { "" },
                isDemoMode: false,
                guideSlot: slot
            )
            // 低于引导最小高度时不呈现引导（内容区展开态的控制区只有 150pt）。
            #expect(ControlView.guideMinimumHeight > 150)
            let rendered = try pixels(control, height: 150)
            let empty = try pixels(EmptyView(), height: 150)
            #expect(rendered == empty)
        }
    }
}
