//
//  ExtNSImage.swift
//  MagicKit
//
//  NSImage 扩展，提供图片生成和转换功能
//

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
import SwiftUI

public extension NSImage {
    /// 创建一个简单的测试图片，带有渐变背景和文字
    static func testImage(
        size: NSSize = NSSize(width: 800, height: 600),
        text: String = "MagicKit\nTest Image",
        colors: [NSColor] = [
            NSColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0),
            NSColor(red: 0.4, green: 0.2, blue: 0.8, alpha: 1.0)
        ]
    ) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()

        let gradient = NSGradient(colors: colors)
        gradient?.draw(in: NSRect(origin: .zero, size: size), angle: 45)

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 48, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        let textSize = text.size(withAttributes: attrs)
        let textRect = NSRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        text.draw(in: textRect, withAttributes: attrs)

        image.unlockFocus()
        return image
    }

    /// 将 NSImage 转换为 JPEG 数据
    func jpegData(compressionFactor: CGFloat = 0.8) -> Data? {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: compressionFactor])
    }

    /// 将 NSImage 转换为 PNG 数据
    func pngData() -> Data? {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }

    /// 将图片保存到文件
    @discardableResult
    func writeToURL(_ url: URL, compressionFactor: CGFloat = 0.8) -> Bool {
        guard let jpegData = jpegData(compressionFactor: compressionFactor) else {
            return false
        }
        do {
            try jpegData.write(to: url)
            return true
        } catch {
            return false
        }
    }
}
#endif
