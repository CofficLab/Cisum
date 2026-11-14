//
//  Thumbnail+Image.swift
//  MagicKit
//
//  图片文件缩略图生成
//

import Foundation
import OSLog
import SwiftUI

// MARK: - ThumbnailGenerator Extension

extension ThumbnailGenerator {
    /// 从图片文件生成缩略图
    /// - Parameters:
    ///   - size: 目标尺寸
    ///   - verbose: 是否输出详细日志
    /// - Returns: 缩略图结果
    func imageThumbnail(size: CGSize, verbose: Bool) async throws -> ThumbnailResult {
        if verbose {
            os_log("\(url.t)<\(url.title)>格式是图片，获取图片缩略图")
        }

        guard let image = Image.PlatformImage.fromFile(url) else {
            throw URLError(.cannotDecodeContentData)
        }

        let resizedImage = image.resize(to: size, quality: .high)
        return ThumbnailResult(
            image: resizedImage,
            isSystemIcon: false,
            fileType: .image,
            source: .generated,
            isCached: false
        )
    }
}
