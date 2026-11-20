import AVFoundation
import Foundation
import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// 视频缩略图生成与缓存。
///
/// 缩略图按需生成：网格滚动到哪里才生成哪里，生成结果按「路径 + 尺寸」
/// 缓存在内存里，避免重复解码同一帧。
@MainActor
final class VideoThumbnailService {
    static let shared = VideoThumbnailService()

    private let cache = NSCache<NSString, NSImageOrUIImage>()

    init() {
        cache.countLimit = 120
    }

    /// 生成缩略图。
    ///
    /// - Parameters:
    ///   - url: 视频文件地址。
    ///   - size: 目标像素尺寸。
    /// - Returns: 缩略图；生成失败时返回 `nil`。
    func thumbnail(for url: URL, size: CGSize) async -> NSImageOrUIImage? {
        let key = "\(url.path)#\(Int(size.width))x\(Int(size.height))" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = size
        generator.requestedTimeToleranceBefore = CMTime(seconds: 1, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 1, preferredTimescale: 600)

        let time = CMTime(seconds: 1, preferredTimescale: 600)
        guard let image = try? await generator.image(at: time).image else {
            return nil
        }

        #if os(macOS)
        let platformImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        #else
        let platformImage = UIImage(cgImage: image)
        #endif

        cache.setObject(platformImage, forKey: key)
        return platformImage
    }
}

#if os(macOS)
typealias NSImageOrUIImage = NSImage
#else
typealias NSImageOrUIImage = UIImage
#endif
