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
        let data = try #require(image.dataProvider?.data)
        let bytes = try #require(CFDataGetBytePtr(data))
        let offset = (y * image.width + x) * 4
        return (
            Int(bytes[offset]),
            Int(bytes[offset + 1]),
            Int(bytes[offset + 2]),
            Int(bytes[offset + 3])
        )
    }

    /// 有内容的像素包围盒（alpha > 0）。
    private func contentBounds(in image: CGImage) throws -> CGRect {
        var minX = Int.max, maxX = Int.min
        var minY = Int.max, maxY = Int.min
        for y in 0 ..< image.height {
            for x in 0 ..< image.width {
                if try pixel(in: image, x: x, y: y).alpha > 0 {
                    minX = min(minX, x)
                    maxX = max(maxX, x)
                    minY = min(minY, y)
                    maxY = max(maxY, y)
                }
            }
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// 亮色像素（标题文字）的行号集合。
    private func brightRows(in image: CGImage) throws -> Set<Int> {
        var rows: Set<Int> = []
        for y in 0 ..< image.height {
            for x in 0 ..< image.width {
                let p = try pixel(in: image, x: x, y: y)
                if p.alpha > 0 && p.red > 180 && p.green > 180 && p.blue > 180 {
                    rows.insert(y)
                    break
                }
            }
        }
        return rows
    }

    @Test
    func brandBlockIsVerticallyCentered() throws {
        let image = try render()
        let bounds = try contentBounds(in: image)

        let topGap = Int(bounds.minY)
        let bottomGap = image.height - Int(bounds.maxY)

        // 品牌块居中：上下留白大致对称。
        // 旧版把「⋯」指向区钉在底部，底边留白几乎为 0——这条断言就是防它回来的。
        #expect(abs(topGap - bottomGap) < 80, "上下留白应大致对称，实际 top=\(topGap) bottom=\(bottomGap)")
    }

    @Test
    func bottomAreaIsEmpty() throws {
        let image = try render()
        let bounds = try contentBounds(in: image)

        // 面板底部必须留空：那里曾经钉着「⋯」指向区。
        #expect(Int(bounds.maxY) < image.height - 80)
    }

    @Test
    func titleRendersBelowTheCover() throws {
        let image = try render()
        let bounds = try contentBounds(in: image)
        let bright = try brightRows(in: image)

        #expect(!bright.isEmpty, "标题「开始使用 Cisum」应渲染出文字")

        // 封面是正方形：从内容顶边往下取一个正方形的边长，标题必须落在它下面。
        let coverSide = min(image.width - 64, image.height - 60)
        let coverBottom = Int(bounds.minY) + Int(coverSide)

        #expect(bright.min()! > coverBottom, "标题应在封面图标下方")
    }

    @Test
    func injectedCoverIconIsRendered() throws {
        #if os(macOS) || os(iOS)
        let icon = try redImage()
        let renderer = ImageRenderer(
            content: RepositoryGuideView(iconOverride: icon)
                .frame(width: viewWidth, height: viewHeight)
        )
        renderer.scale = 1
        let image = try #require(renderer.cgImage)

        var foundRed = false
        for y in 0 ..< image.height where !foundRed {
            for x in stride(from: 0, to: image.width, by: 2) {
                let p = try pixel(in: image, x: x, y: y)
                if p.red > 150 && p.green < 100 {
                    foundRed = true
                    break
                }
            }
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
