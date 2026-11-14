//
//  Thumbnail+Result.swift
//  MagicKit
//
//  缩略图结果类型定义
//

import Foundation
import SwiftUI

/// 缩略图生成结果
/// 包含生成的缩略图图片以及相关元数据
public struct ThumbnailResult {
    /// 缩略图图片（可能是系统图标或实际缩略图）
    public let image: Image.PlatformImage?

    /// 是否为系统图标
    /// - `true`: 返回的是系统图标（如文件夹图标、文件类型图标等）
    /// - `false`: 返回的是从文件内容生成的实际缩略图
    public let isSystemIcon: Bool

    /// 文件类型（如果能确定）
    public let fileType: FileType

    /// 图片来源
    public let source: ThumbnailSource

    /// 是否被缓存
    public let isCached: Bool

    /// 创建一个新的缩略图结果
    /// - Parameters:
    ///   - image: 缩略图图片
    ///   - isSystemIcon: 是否为系统图标
    ///   - fileType: 文件类型
    ///   - source: 图片来源
    ///   - isCached: 是否被缓存
    public init(
        image: Image.PlatformImage?,
        isSystemIcon: Bool,
        fileType: FileType = .unknown,
        source: ThumbnailSource = .generated,
        isCached: Bool = false
    ) {
        self.image = image
        self.isSystemIcon = isSystemIcon
        self.fileType = fileType
        self.source = source
        self.isCached = isCached
    }

    /// 便捷初始化方法：仅提供图片和是否为系统图标
    /// - Parameters:
    ///   - image: 缩略图图片
    ///   - isSystemIcon: 是否为系统图标
    /// - Returns: 缩略图结果
    public static func from(
        image: Image.PlatformImage?,
        isSystemIcon: Bool
    ) -> ThumbnailResult {
        ThumbnailResult(
            image: image,
            isSystemIcon: isSystemIcon,
            fileType: .unknown,
            source: isSystemIcon ? .systemIcon : .generated,
            isCached: false
        )
    }
}

// MARK: - ThumbnailResult Extension

extension ThumbnailResult {
    /// 转换为 SwiftUI Image
    /// - Returns: SwiftUI Image，如果图片为 nil 则返回 nil
    public func toSwiftUIImage() -> SwiftUI.Image? {
        guard let image = image else { return nil }
        return image.toSwiftUIImage()
    }

    /// 是否有可用的缩略图
    /// - Returns: 如果有图片且不为空则返回 true
    public var hasImage: Bool {
        image != nil
    }

    /// 是否应该被缓存
    /// - Returns: 如果不是系统图标则应该缓存
    public var shouldCache: Bool {
        !isSystemIcon && hasImage
    }
}

/// 缩略图来源
public enum ThumbnailSource: Sendable {
    /// 从文件内容生成的缩略图
    case generated

    /// 系统提供的图标
    case systemIcon

    /// 从缓存获取
    case cached

    /// 从网络下载
    case downloaded

    /// 从元数据提取（如音频封面）
    case metadata
}

/// 文件类型分类
public enum FileType: Sendable, CustomStringConvertible {
    /// 图片文件
    case image

    /// 视频文件
    case video

    /// 音频文件
    case audio

    /// 目录/文件夹
    case folder

    /// 文档文件
    case document

    /// 未知类型
    case unknown

    public var description: String {
        switch self {
        case .image: return "image"
        case .video: return "video"
        case .audio: return "audio"
        case .folder: return "folder"
        case .document: return "document"
        case .unknown: return "unknown"
        }
    }
}
