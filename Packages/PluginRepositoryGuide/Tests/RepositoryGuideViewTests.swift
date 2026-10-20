import CoreGraphics
import SwiftUI
import Testing
@testable import PluginRepositoryGuide

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// 引导面板的呈现约束：
/// - 封面位用注入的图标（宿主 app 图标）；
/// - 底部指向区保留「⋯」提示。
@MainActor
struct RepositoryGuideViewTests {
    /// 渲染视图并取像素。
    private func render<V: View>(_ view: V, width: CGFloat = 400, height: CGFloat = 858) throws -> CGImage {
        let renderer = ImageRenderer(content: view.frame(width: width, height: height))
        renderer.scale = 1
        return try #require(renderer.cgImage)
    }

    private func pixel(in image: CGImage, x: Int, y: Int) throws -> (red: Int, green: Int, blue: Int) {
        let data = try #require(image.dataProvider?.data)
        let bytes = try #require(CFDataGetBytePtr(data))
        let offset = (y * image.width + x) * 4
        return (Int(bytes[offset]), Int(bytes[offset + 1]), Int(bytes[offset + 2]))
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

    @Test
    func guideRendersCoverIconAtCenter() throws {
        let guide = RepositoryGuideView(iconOverride: try redImage())
        let image = try render(guide)

        // 封面图标大致落在控制区上半部：沿中轴扫一段，找有没有注入的红色。
        var foundRed = false
        for y in stride(from: 40, to: image.height / 2, by: 4) {
            let probe = try pixel(in: image, x: image.width / 2, y: y)
            if probe.red > 150 && probe.green < 100 {
                foundRed = true
                break
            }
        }
        #expect(foundRed, "封面位应渲染出注入的图标")
    }

    @Test
    func guideKeepsTheMoreButtonHintAtBottom() throws {
        let guide = RepositoryGuideView(iconOverride: try redImage())
        let image = try render(guide)

        // 指向区在底部：那里必须有内容（文字 + 「⋯」示意），不能是空白。
        var hasContent = false
        for y in stride(from: image.height - 120, to: image.height - 10, by: 4) {
            for x in stride(from: 20, to: image.width - 20, by: 8) {
                let p = try pixel(in: image, x: x, y: y)
                if p.red != p.green || p.green != p.blue {
                    hasContent = true
                    break
                }
            }
            if hasContent { break }
        }
        #expect(hasContent, "底部指向区应渲染出「⋯」提示")
    }
}

/// 非 macOS / iOS 平台兜底。
struct UnsupportedPlatformError: Error {}
