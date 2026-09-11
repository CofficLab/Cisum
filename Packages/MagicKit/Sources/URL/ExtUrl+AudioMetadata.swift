//
//  ExtUrl+AudioMetadata.swift
//  MagicKit
//
//  URL 音频元数据扩展
//

import AVFoundation
import Foundation
import OSLog
import SwiftUI

extension URL {
    /// 从音频文件的元数据中获取封面图片（原生图片格式）
    /// - Parameter verbose: 是否输出详细日志
    /// - Returns: 如果找到封面则返回平台原生图片格式，否则返回 nil
    public func extractCoverFromMetadata(verbose: Bool = false) async throws -> Image.PlatformImage? {
        let printArtworkKeys = true

        if verbose {
            os_log("\(self.t)<\(self.title)>从音频文件的元数据中获取封面图片")
        }

        let asset = AVURLAsset(url: self)

        let artworkKeys = [
            AVMetadataKey.commonKeyArtwork,
            AVMetadataKey.id3MetadataKeyAttachedPicture,
            AVMetadataKey.iTunesMetadataKeyCoverArt,
        ]

        do {
            let commonMetadata = try await asset.load(.commonMetadata)

            if artworkKeys.isEmpty {
                if verbose { os_log("\(self.t)<\(self.title)>音频文件的元数据没有任何键值对") }
                return nil
            }

            for key in artworkKeys {
                if verbose && printArtworkKeys {
                    os_log("\(self.t)<\(self.title)>尝试从音频文件的元数据中获取封面图片: \(key.rawValue)")
                }

                let artworkItems = AVMetadataItem.metadataItems(
                    from: commonMetadata,
                    withKey: key,
                    keySpace: AVMetadataKeySpace.common
                )

                if let artworkItem = artworkItems.first {
                    do {
                        if let artworkData = try await artworkItem.load(.value) as? Data {
                            if let image = Image.PlatformImage.fromCacheData(artworkData) {
                                if verbose { os_log("\(self.t)<\(self.title)>从音频文件的元数据中获取封面图片: \(key.rawValue) 成功") }
                                return image
                            }
                        } else if let artworkImage = try await artworkItem.load(.value) as? Image.PlatformImage {
                            if verbose { os_log("\(self.t)<\(self.title)>从音频文件的元数据中获取封面图片: \(key.rawValue) 成功") }
                            return artworkImage
                        }
                    } catch {
                        if verbose { os_log(.error, "Failed to load artwork for key \(key.rawValue): \(error.localizedDescription)") }
                        continue
                    }
                }
            }

            if verbose { os_log("\(self.t)<\(self.title)>音频文件的元数据中没有封面图片") }

            return nil
        } catch {
            if verbose { os_log(.error, "\(self.t)<\(self.title)>无法从音频文件的元数据中获取封面图片: \(error.localizedDescription)") }

            throw error
        }
    }
}
