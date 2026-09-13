//
//  Thumbnail+Audio.swift
//  MagicKit
//
//  音频文件缩略图生成
//

import AVFoundation
import Foundation
import OSLog
import SwiftUI

// MARK: - ThumbnailGenerator Extension

extension ThumbnailGenerator {
    /// 从音频文件的元数据中提取封面图片
    /// - Parameters:
    ///   - size: 目标尺寸
    ///   - verbose: 是否输出详细日志
    /// - Returns: 缩略图结果
    func audioThumbnail(size: CGSize, verbose: Bool) async throws -> ThumbnailResult? {
        if verbose {
            os_log("\(url.t)<\(url.title)>尝试从音频元数据中获取封面")
        }

        do {
            if let coverImage = try await url.extractCoverFromMetadata(verbose: verbose) {
                if verbose { os_log("\(url.t)<\(url.title)>从音频元数据中获取封面成功") }
                let resizedImage = coverImage.resize(to: size)
                return ThumbnailResult(
                    image: resizedImage,
                    isSystemIcon: false,
                    fileType: .audio,
                    source: .metadata,
                    isCached: false
                )
            }

            if verbose { os_log("\(url.t)<\(url.title)>音频元数据中没有封面图片") }
            return nil
        } catch {
            if verbose { os_log(.error, "\(url.t)<\(url.title)>从音频元数据中获取封面失败: \(error.localizedDescription)") }
            throw error
        }
    }
}
