//
//  Thumbnail+Folder.swift
//  MagicKit
//
//  文件夹缩略图生成
//

import Foundation
import OSLog
import SwiftUI

// MARK: - ThumbnailGenerator Extension

extension ThumbnailGenerator {
    /// 生成文件夹图标
    /// - Parameters:
    ///   - size: 目标尺寸
    ///   - verbose: 是否输出详细日志
    /// - Returns: 缩略图结果
    func folderThumbnail(size: CGSize, verbose: Bool) async throws -> ThumbnailResult {
        if verbose {
            os_log("\(url.t)<\(url.title)>格式是目录，获取目录缩略图")
        }

        let image = Image.PlatformImage.folderIcon(size: size)
        return ThumbnailResult(
            image: image,
            isSystemIcon: true,
            fileType: .folder,
            source: .systemIcon,
            isCached: false
        )
    }
}
