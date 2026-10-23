import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import PluginRepositoryGuide

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// 引导面板的呈现约束：
/// - 品牌块（封面图标 + 「开始使用 Cisum」）垂直居中，落在播放器封面区；
/// - 面板**不再**自带「点⋯打开仓库」的指向区——那是「⋯」按钮自己的提示，
///   所以底部必须是空的。
///
/// 断言刻意不依赖「图标画在哪一行」：ImageRenderer 渲染注入图片时位置并不
/// 稳定，断言应该钉住的是布局性质（居中、底部留空、标题在图标下方）。
@MainActor
struct RepositoryGuideViewTests {
    private let viewWidth: CGFloat = 400
    private let viewHeight: CGFloat = 858

    /// 渲染引导面板（用内置回退图标，不注入图片）。
    private func render() throws -> CGImage {
        let renderer = ImageRenderer(
            content: RepositoryGuideView().frame(width: viewWidth, height: viewHeight)
        )
        renderer.scale = 1
        return try #require(renderer.cgImage)
    }

    /// 某像素的 RGBA。
    private func pixel(in image: CGImage, x: Int, y: Int) throws -> (red: Int, green: Int, blue: Int, alpha: Int) {
        let buffer = try PixelBuffer(image: image)
        return buffer.pixel(x: x, y: y)
    }

    /// 有内容的像素包围盒（alpha > 0）。
    private func contentBounds(in image: CGImage) async throws -> CGRect {
        let buffer = try PixelBuffer(image: image)
        var minX = Int.max, maxX = Int.min
        var minY = Int.max, maxY = Int.min
        for y in 0 ..< image.height {
            for x in 0 ..< image.width {
                if buffer.pixel(x: x, y: y).alpha > 0 {
                    minX = min(minX, x)
                    maxX = max(maxX, x)
                    minY = min(minY, y)
                    maxY = max(maxY, y)
                }
            }
            // 每行让出一次主 actor：这段同步循环若独占主 actor 几十秒，
            // 会把同包其它 @MainActor 用例（以及它们排队的异步重试）饿死。
            await Task.yield()
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// 亮色像素（标题文字）的行号集合。
    private func brightRows(in image: CGImage) async throws -> Set<Int> {
        let buffer = try PixelBuffer(image: image)
        var rows: Set<Int> = []
        for y in 0 ..< image.height {
            for x in 0 ..< image.width {
                let p = buffer.pixel(x: x, y: y)
                if p.alpha > 0 && p.red > 180 && p.green > 180 && p.blue > 180 {
                    rows.insert(y)
                    break
                }
            }
            await Task.yield()
        }
        return rows
    }

    @Test
    func brandBlockIsVerticallyCentered() async throws {
        let image = try render()
        let bounds = try await contentBounds(in: image)

        let topGap = Int(bounds.minY)
        let bottomGap = image.height - Int(bounds.maxY)

        // 品牌块居中：上下留白大致对称。
        // 旧版把「⋯」指向区钉在底部，底边留白几乎为 0——这条断言就是防它回来的。
        #expect(abs(topGap - bottomGap) < 80, "上下留白应大致对称，实际 top=\(topGap) bottom=\(bottomGap)")
    }

    @Test
    func bottomAreaIsEmpty() async throws {
        let image = try render()
        let bounds = try await contentBounds(in: image)

        // 面板底部必须留空：那里曾经钉着「⋯」指向区。
        #expect(Int(bounds.maxY) < image.height - 80)
    }

    @Test
    func titleRendersBelowTheCover() async throws {
        let image = try render()
        let bounds = try await contentBounds(in: image)
        let bright = try await brightRows(in: image)

        #expect(!bright.isEmpty, "标题「开始使用 Cisum」应渲染出文字")

        // 封面是正方形：从内容顶边往下取一个正方形的边长，标题必须落在它下面。
        let coverSide = min(image.width - 64, image.height - 60)
        let coverBottom = Int(bounds.minY) + Int(coverSide)

        #expect(bright.min()! > coverBottom, "标题应在封面图标下方")
    }

    @Test
    func injectedCoverIconIsRendered() async throws {
        #if os(macOS) || os(iOS)
        let icon = try redImage()
        let renderer = ImageRenderer(
            content: RepositoryGuideView(iconOverride: icon)
                .frame(width: viewWidth, height: viewHeight)
        )
        renderer.scale = 1
        let image = try #require(renderer.cgImage)
        let buffer = try PixelBuffer(image: image)

        var foundRed = false
        for y in 0 ..< image.height where !foundRed {
            for x in stride(from: 0, to: image.width, by: 2) {
                let p = buffer.pixel(x: x, y: y)
                if p.red > 150 && p.green < 100 {
                    foundRed = true
                    break
                }
            }
            await Task.yield()
        }
        #expect(foundRed, "封面位应渲染出注入的图标")
        #endif
    }

    /// 造一张纯红图片，用来断言「封面位确实画了注入的图标」。
    private func redImage() throws -> Image {
        #if os(macOS)
        let image = NSImage(size: CGSize(width: 8, height: 8), flipped: false) { rect in
            NSColor.red.setFill()
            rect.fill()
            return true
        }
        return Image(nsImage: image)
        #elseif os(iOS)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8))
        let image = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        return Image(uiImage: image)
        #else
        throw UnsupportedPlatformError()
        #endif
    }
}

/// 非 macOS / iOS 平台兜底。
struct UnsupportedPlatformError: Error {}

/// 像素缓冲：图像数据**只解析一次**，之后逐像素直接读字节。
///
/// 原实现每个像素都重新取一次 `image.dataProvider?.data`（一次 1.3MB 的拷贝）
/// 并 `#require` 一次——一张 400×858 的图要重复 34 万次，整包视图测试因此跑了
/// 40 多分钟，还会长时间独占主 actor，把同包其它 @MainActor 用例饿死。
private struct PixelBuffer {
    /// 持有 CFData，保证字节指针在其生命周期内有效。
    private let data: CFData
    private let bytes: UnsafePointer<UInt8>
    let width: Int

    init(image: CGImage) throws {
        let data = try #require(image.dataProvider?.data)
        let bytes = try #require(CFDataGetBytePtr(data))
        self.data = data
        self.bytes = bytes
        self.width = image.width
    }

    func pixel(x: Int, y: Int) -> (red: Int, green: Int, blue: Int, alpha: Int) {
        let offset = (y * width + x) * 4
        return (
            Int(bytes[offset]),
            Int(bytes[offset + 1]),
            Int(bytes[offset + 2]),
            Int(bytes[offset + 3])
        )
    }
}
