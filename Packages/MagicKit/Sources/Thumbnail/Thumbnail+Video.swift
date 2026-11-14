//
//  Thumbnail+Video.swift
//  MagicKit
//
//  视频文件缩略图生成
//

import AVFoundation
import Foundation
import OSLog
import SwiftUI

// MARK: - ThumbnailGenerator Extension

extension ThumbnailGenerator {
    /// 从视频文件生成缩略图
    /// - Parameters:
    ///   - size: 目标尺寸
    ///   - verbose: 是否输出详细日志
    /// - Returns: 缩略图结果
    func videoThumbnail(size: CGSize, verbose: Bool) async throws -> ThumbnailResult {
        if verbose {
            os_log("\(url.t)<\(url.title)>格式是视频，获取视频缩略图")
        }

        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = size

        do {
            let cgImage = try await imageGenerator.image(at: .zero).image
            let image = Image.PlatformImage.fromCGImage(cgImage, size: size)
            return ThumbnailResult(
                image: image,
                isSystemIcon: false,
                fileType: .video,
                source: .generated,
                isCached: false
            )
        } catch {
            throw error
        }
    }
}
